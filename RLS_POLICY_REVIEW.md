# RLS POLICY & SECURITY DESIGN REVIEW — MYFINANCE
**Aplikasi:** MyFinance (Personal Finance Management)  
**Tujuan Dokumen:** Tinjauan keamanan arsitektur Row Level Security (RLS), mitigasi kebocoran data antar-pengguna (*cross-tenant isolation*), dan audit kepatuhan terhadap prinsip *Defense-in-Depth*.

---

## 1. Prinsip Utama Keamanan & Akses Data (Core Security Principles)

1. **Enforcement di Level Engine Basis Data:**
   - Keamanan data finansial tidak boleh bergantung pada filtering query di sisi aplikasi Flutter (`WHERE user_id = ...`).
   - Setiap tabel yang menyimpan data pengguna **wajib mengaktifkan RLS (`ENABLE ROW LEVEL SECURITY`)**.
   - PostgreSQL secara otomatis menolak (*default-deny*) setiap query yang tidak memenuhi kebijakan RLS yang terdefinisi.
2. **Larangan Keras `service_role` Key:**
   - Aplikasi client Flutter hanya diperbolehkan menggunakan **Supabase `anon` key** berpasangan dengan token JWT pengguna aktif.
   - Kunci `service_role` yang dapat membypass seluruh RLS **tidak boleh disematkan ke dalam kode aplikasi, berkas APK, IPA, maupun web asset**.
3. **Zero Public Access pada Data Finansial:**
   - Tidak ada tabel finansial (dompet, mutasi transaksi, struk, anggaran) yang dapat diakses oleh publik (*unauthenticated users*).
   - Seluruh role kebijakan didefinisikan secara eksplisit untuk `TO authenticated`.

---

## 2. Matriks Kontrol Akses Berbasis RLS (Access Control Matrix)

| Tabel | Role | SELECT | INSERT | UPDATE | DELETE | Kondisi Keamanan & Catatan |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **`profiles`** | `authenticated` | `auth.uid() = id` | `auth.uid() = id` | `auth.uid() = id` | `auth.uid() = id` | Profil terisolasi mutlak per pengguna |
| **`wallets`** | `authenticated` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | Saldo & akun dompet terisolasi 100% |
| **`categories`** | `authenticated` | `user_id IS NULL OR user_id = auth.uid()` | `auth.uid() = user_id AND is_system = FALSE` | `auth.uid() = user_id AND is_system = FALSE` | `auth.uid() = user_id AND is_system = FALSE` | User dapat membaca kategori sistem bawaan, tetapi hanya dapat memodifikasi kategori kustom miliknya sendiri |
| **`transactions`** | `authenticated` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | Buku besar mutasi terisolasi mutlak |
| **`transaction_attachments`**| `authenticated` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | Metadata struk belanja terikat user_id |
| **`budgets`** | `authenticated` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | Plafon anggaran terisolasi mutlak |
| **`budget_category_limits`** | `authenticated` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | Sub-alokasi anggaran terikat user_id |
| **`app_settings`** | `authenticated` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | Preferensi & PIN hash terisolasi |
| **`storage.objects` (`receipts`)** | `authenticated` | `(storage.foldername(name))[1] = auth.uid()::text` | `(storage.foldername(name))[1] = auth.uid()::text` | `(storage.foldername(name))[1] = auth.uid()::text` | `(storage.foldername(name))[1] = auth.uid()::text` | Berkas gambar struk terisolasi per folder `receipts/<user_id>/` |

---

## 3. Tinjauan Detail Kebijakan Per Tabel (Policy Review)

### 3.1 Kebijakan Tabel `wallets`
- **SELECT Policy:** `USING (auth.uid() = user_id)`
  - Memastikan user tidak dapat melihat nama, jenis, saldo awal, maupun akun bank milik pengguna lain.
- **INSERT Policy:** `WITH CHECK (auth.uid() = user_id)`
  - Mencegah user menyisipkan dompet atas nama `user_id` milik orang lain.
- **UPDATE Policy:** `USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)`
  - Mencegah manipulasi dompet orang lain, sekaligus mencegah pemindahan kepemilikan dompet (*privilege transfer*) ke user lain.
- **DELETE Policy:** `USING (auth.uid() = user_id)`
  - Hanya pemilik dompet yang dapat menghapus akunnya.

### 3.2 Kebijakan Tabel Khusus: `categories`
- **Karakteristik Unik:** Aplikasi memiliki 11 kategori sistem bawaan yang harus dapat dibaca oleh seluruh pengguna, namun pengguna tidak boleh mengubah kategori sistem tersebut.
- **SELECT:**
  ```sql
  USING (user_id IS NULL OR user_id = auth.uid())
  ```
  Menampilkan kategori global (`user_id IS NULL`) dan kategori kustom milik user yang sedang aktif.
- **INSERT / UPDATE / DELETE:**
  ```sql
  WITH CHECK (auth.uid() = user_id AND is_system = FALSE)
  ```
  User ditolak keras jika mencoba mengubah, menghapus, atau membuat kategori dengan flag `is_system = TRUE`.

### 3.3 Kebijakan Tabel `transactions`
- **SELECT:** `USING (auth.uid() = user_id)`
- **INSERT:** `WITH CHECK (auth.uid() = user_id)`
  - Didukung oleh foreign key constraint: `wallet_id` dan `destination_wallet_id` harus valid.
- **UPDATE:** `USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)`
- **DELETE:** `USING (auth.uid() = user_id)`
- **Integritas Tambahan:** Operasi pembatalan mutasi (void) direkomendasikan menggunakan RPC `void_transaction` yang secara otomatis memvalidasi `WHERE id = p_transaction_id AND user_id = auth.uid()`.

### 3.4 Kebijakan Storage Berkas Struk (`receipts`)
- **Struktur Folder Terisolasi:** `receipts/<user_id>/<attachment_id>.jpg`.
- **Ekspresi RLS:**
  ```sql
  (storage.foldername(name))[1] = auth.uid()::text
  ```
  Fungsi bawaan Supabase `storage.foldername(name)` mengambil segmen folder pertama dari path berkas. Jika segmen folder tersebut tidak sama persis dengan `auth.uid()`, permintaan upload, baca, atau hapus berkas langsung ditolak (HTTP 403 Forbidden).

---

## 4. Analisis Vektor Serangan & Risiko Isolasi Data (Threat Modeling)

### 4.1 Insecure Direct Object Reference (IDOR)
- **Skenario Serangan:** Penyerang mencoba mengambil transaksi milik user lain dengan menebak atau mengetahui `UUID` transaksi target via PostgREST:
  `GET /rest/v1/transactions?id=eq.<target-uuid>`
- **Mitigasi RLS:** Kebijakan `transactions_select_own` mengevaluasi kondisi `auth.uid() = user_id`. Meskipun ID transaksi target valid, PostgreSQL mengembalikan `[]` (empty array / 0 baris) seolah data tersebut tidak ada di basis data.

### 4.2 Cross-User Wallet Injection (Manipulasi Foreign Key)
- **Skenario Serangan:** Penyerang memasukkan transaksi miliknya sendiri, tetapi mengarahkan `wallet_id` ke rekening dompet milik korban agar saldo dompet korban terganggu.
- **Mitigasi RLS & Constraint:**
  - Meskipun transaksi tersimpan dengan `user_id` penyerang, repositori MyFinance menghitung saldo dompet menggunakan query:
    `WHERE wallet_id = :targetWallet AND user_id = :targetUser`.
  - Transaksi penyerang tidak pernah terbaca saat sistem menghitung saldo buku besar milik korban karena RLS menyembunyikan transaksi tersebut dari sesi korban.
  - Untuk perlindungan ekstra di masa mendatang, trigger database dapat ditambahkan untuk memvalidasi bahwa `wallets.user_id = transactions.user_id`.

### 4.3 Path Traversal / Folder Tampering pada Storage
- **Skenario Serangan:** Penyerang mencoba mengunggah foto struk ke folder user lain dengan memalsukan nama berkas, misalnya:
  `name = "../<victim-uuid>/receipt.jpg"`
- **Mitigasi Supabase Storage:** Supabase Storage menolak path traversal `..` dan RLS `storage.foldername(name)[1] = auth.uid()::text` memastikan berkas hanya dapat ditempatkan di root direktori berlabel UID pengguna sendiri.

### 4.4 Privilege Escalation via API Key Tampering
- **Skenario Serangan:** Penyerang memeriksa bundle Flutter web atau file biner aplikasi untuk mencari API key dengan hak akses tinggi.
- **Mitigasi:**
  - Kode aplikasi Flutter MyFinance **hanya menyertakan `anon_key` (public key)**.
  - `service_role` key hanya disimpan pada environment server aman (jika ada backend/edge function) dan tidak pernah dibagikan ke client.

---

## 5. Ringkasan Kepatuhan Keamanan (Compliance Checklist)

- [x] RLS diaktifkan pada 100% tabel data finansial.
- [x] Seluruh operasi mutasi data dibatasi ke `auth.uid() = user_id`.
- [x] Kebijakan `WITH CHECK` diterapkan pada seluruh operasi `INSERT` dan `UPDATE` untuk mencegah perpindahan kepemilikan data.
- [x] Kategori sistem diproteksi dari pengubahan oleh pengguna non-admin.
- [x] Berkas lampiran struk di Supabase Storage diproteksi dengan RLS folder-based per pengguna.
- [x] Transaksi multi-tabel krusial (seperti budgeting) dilindungi dengan PostgreSQL Stored Procedures (RPC).
- [x] Tidak ada filtering otentikasi yang diserahkan ke sisi client Flutter saja.
