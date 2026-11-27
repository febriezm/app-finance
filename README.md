# MyFinance — Personal Finance App (Full Cloud Supabase PostgreSQL)

**MyFinance** adalah aplikasi manajemen keuangan pribadi modern, minimalis, dan privat yang mematuhi standar **Apple Human Interface Guidelines (HIG)**, prinsip akuntansi buku besar berpresisi tinggi (Integer Rupiah), dan ditenagai oleh arsitektur **Full Cloud Supabase PostgreSQL** dengan isolasi ketat **Row Level Security (RLS)**.

Aplikasi ini mengintegrasikan otentikasi awan aman (*Supabase Auth*), penyimpanan berkas struk privat (*Supabase Storage*), sinkronisasi data keuangan *multi-device*, serta perlindungan keamanan biometrik dan kode sandi PIN.

---

## 🏛️ Arsitektur & Prinsip Desain

1. **Full Cloud Supabase PostgreSQL Architecture**
   - Basis data relasional terkelola menggunakan **Supabase PostgreSQL**.
   - Setiap tabel data finansial (`wallets`, `categories`, `transactions`, `budgets`, `budget_category_limits`, `app_settings`, `transaction_attachments`) dilindungi secara mandatori oleh **Row Level Security (RLS)** berbasis `auth.uid() = user_id`.
   - Menggunakan *Clean Architecture* dan *Riverpod State Management* dengan isolasi penuh antara UI, Controller/Notifier, Usecase, Repository, dan Remote DataSource.

2. **Otentikasi & Manajemen Sesi Mandatori (Supabase Auth)**
   - Akses aplikasi mewajibkan autentikasi akun (*Login*, *Daftar Akun Baru*, *Verifikasi Email*, dan *Pemulihan Kata Sandi*).
   - Sesi login tersimpan secara persisten (*session persistence*) sehingga pengguna langsung masuk ke dashboard utama tanpa perlu login berulang saat membuka aplikasi.
   - Saat keluar akun (*Sign Out*), seluruh cache kredensial lokal dan sesi keamanan dibersihkan secara bersih (*clean reset*).

3. **Akuntansi Buku Besar Deterministik (Ledger Invariance)**
   - Saldo setiap dompet dihitung secara matematis dan deterministik dari riwayat mutasi transaksi:
     $$\text{Saldo} = \text{Saldo Awal} + \text{Pemasukan} + \text{Transfer Masuk} - \text{Pengeluaran} - \text{Transfer Keluar}$$
   - Transaksi transfer antar-dompet (*internal transfer*) tidak mengubah total kekayaan bersih (*total net worth*) maupun total pemasukan/pengeluaran.
   - Seluruh nilai nominal mata uang disimpan dalam satuan integer Rupiah (`int`), menghilangkan potensi *rounding error* desimal (*Zero Rounding Error*).

4. **Penyimpanan Struk Privat (Supabase Storage)**
   - Berkas struk/bukti transaksi disimpan di *private bucket* Supabase Storage (`receipts`) dengan struktur direktori terisolasi per akun (`<user_id>/<filename>`).
   - Akses unduh dan pratinjau struk menggunakan *signed URLs* dengan waktu kedaluwarsa terbatas (*time-limited token*).

5. **Pemindai Struk On-Device (OCR + Parser)**
   - Ekstraksi teks struk belanja diproses langsung di perangkat melalui *Optical Character Recognition (OCR)*.
   - Hasil ekstraksi OCR masuk sebagai draf (*ReceiptDraft*) dan wajib dikonfirmasi pengguna sebelum masuk ke buku besar cloud.

6. **Keamanan Berlapis (App Lock & Biometrik)**
   - Perlindungan kode sandi PIN 6-digit dan biometrik (*Face ID / Touch ID / WebAuthn*).
   - Status kunci terisolasi pada sesi akun aktif: saat logout atau berganti akun, status kunci akun sebelumnya otomatis di-reset.
   - Kunci Aplikasi dirancang non-intrusif: hanya meminta verifikasi saat aplikasi dibuka pertama kali atau di-refresh (cold start/reload), tanpa mengganggu alur kerja internal seperti pemindaian kamera (*Scan Struk*) atau perpindahan layar.

7. **Profil Pengguna & Personalisasi Akun**
   - Pendaftaran akun baru dan profil mendukung pencatatan nama lengkap (*full_name*) serta nomor telepon (*phone*) dengan konversi otomatis ke format E.164 (`+62...`) yang tersinkronisasi langsung dengan kolom `auth.users.phone` dan tabel profil Supabase.
   - Dashboard utama menampilkan salam waktu (*Title Case*: 'Selamat Pagi', 'Selamat Siang', 'Selamat Sore', 'Selamat Malam') yang menyapa nama pengguna secara personal.

8. **Migrasi Data Lokal ke Cloud (Local-to-Cloud Migration)**
   - Dilengkapi modul migrasi transaksional otomatis untuk memindahkan data pengguna lokal terdahulu (*SQLite*) ke *Supabase PostgreSQL Cloud* secara terverifikasi.

9. **Operasi CRUD Bersih (Clean In-Place Edit & Permanent Hard Delete)**
   - **Edit Langsung (In-Place)**: Pembaruan transaksi, transfer saldo, dompet, dan anggaran dilakukan langsung pada baris data yang ada tanpa menghasilkan entri duplikasi atau perubahan ID.
   - **Hapus Permanen Tanpa Coretan**: Menghilangkan seluruh konsep pembatalan semu (*void*) atau teks dicoret (*strikethrough*). Ketika data dihapus, data tersebut dihilangkan secara permanen dari SQLite lokal dan Supabase Cloud, serta saldo buku besar disinkronkan kembali secara otomatis.

10. **Desain Kartu Fisik Realistis & Carousel Dompet Per Kategori (Physical Bank Cards & E-Wallet Themes)**
    - **UI Carousel / Dek Kartu Per Tipe**: Menu Dompet & Rekening mengelompokkan kartu ke masing-masing kategori akun (*Rekening Bank*, *Kas Tunai*, *E-Wallet*, *Lainnya/Investasi*, dan *Dompet Diarsipkan*). Setiap tipe yang memiliki lebih dari satu kartu menampilkan slider horizontal bergaya dek kartu dengan efek intip kartu berikutnya (*peek fraction 0.88*), indikator titik dinamis, dan petunjuk *Geser kartu ➔*. Kategori dengan kartu tunggal ditampilkan proporsional penuh tanpa duplikasi daftar vertikal.
    - **12 Aset Kartu Bank Realistis Asli (`assets/kartu_bank/`)**:
      - Menggunakan grafis kartu debit fisik asli beresolusi tinggi dengan rasio standar ID-1 ISO 7810 (`1.586`): **BCA**, **Mandiri**, **BNI**, **BRI**, **BSI**, **BTN**, **CIMB Niaga**, **Danamon**, **Bank Jago**, **OCBC**, **Permata**, dan **SeaBank**.
      - **Penempatan Nama Akun yang Presisi**:
        - **Seluruh Bank Standard**: Nama akun dicetak elegan di pojok bawah sebelah kiri (*bottom-left*) sesuai standar penamaan kartu fisik.
        - **Khusus Bank Jago**: Nama akun dicetak di pojok bawah sebelah kanan (*bottom-right*) menyesuaikan tata letak vertikal logo VISA pada kartu Jago.
        - **Saldo Real-Time**: Ditampilkan presisi di area tengah kanan kartu tanpa menimpa logo penerbit maupun logo jaringan pembayaran (Mastercard/VISA).
    - **E-Wallet & Kas Tunai Tematik (Minimalist & Clean Card Layout)**:
      - **Penyederhanaan Tata Letak Kartu Non-Bank**:
        - Teks/logo di pojok kanan atas **dihilangkan** secara bersih.
        - Area pojok kiri bawah **hanya memuat nama akun pemilik** secara rapi tanpa nomor kartu atau teks masa berlaku.
        - Teks di pojok kiri atas otomatis menampilkan nama templat:
          - **Uang Tunai (Cash)**: `Cash` (dengan pola *guilloche geometric* zamrud).
          - **E-Wallet**: `GoPay`, `OVO`, `DANA`, `ShopeePay`, `LinkAja`, dan `AstraPay`.
          - **Lainnya / Portofolio**: Mempertahankan header portofolio aset minimalis.
      - **Palet Visual Khusus**:
        - **GoPay**: Biru toska segar (*mint*) dengan cincin konsentris logo GoPay.
        - **OVO**: Ungu royal dengan aksen cahaya magenta.
        - **DANA**: Biru langit cerah dengan kurva gelombang dinamis DANA.
        - **ShopeePay**: Oranye cerah khas Shopee dengan aksen tas belanja.
        - **LinkAja**: Merah kobalt dinamis.
        - **AstraPay**: Biru navy korporat AstraPay dengan aksen sapphire.
        - **Cash**: Pola *guilloche geometric* hijau zamrud khas uang kertas fisik.
    - **Modal Detail Dompet Adaptif & Anti-Terpotong**: Lembar detail dompet (*Wallet Detail Sheet*) dioptimalkan dengan batasan tinggi aman 88% layar dan kontainer gulir mulus (*BouncingScrollPhysics*), memastikan seluruh tombol aksi (*Riwayat Mutasi*, *Transfer*, *Edit*, *Arsipkan*, dan *Hapus*) tampil utuh di semua perangkat termasuk Safari iOS.
    - **Rasio Kartu Presisi ISO/IEC 7810 ID-1 (1.586)**: Dimensi kartu fisik di seluruh modal (rincian dompet, tambah dompet baru, dan edit dompet) dikunci pada rasio standar baku `1.586` dan batas lebar adaptif (max 420px), mencegah distorsi kartu menjadi lonjong atau gepeng di layar lebar maupun sempit.
    - **Form Tambah & Edit Dompet Dinamis & Terfilter Sesuai Tipe**:
      - Urutan form yang ergonomis: *Live Card Preview* -> *Tipe Dompet* -> *Pilih Templat/Penerbit Kartu* -> *Nama Dompet* -> *Saldo Awal*.
      - Templat kartu difilter otomatis berdasarkan tipe yang dipilih:
        - *Rekening Bank*: Menampilkan 12 bank (BCA, Mandiri, BNI, BRI, BSI, BTN, CIMB Niaga, Danamon, Bank Jago, OCBC, Permata, SeaBank).
        - *E-Wallet*: Menampilkan 6 dompet digital resmi (GoPay, OVO, DANA, ShopeePay, LinkAja, AstraPay).
        - *Kas Tunai*: Menampilkan templat Cash.
        - *Lainnya*: Menampilkan Portofolio Investasi dan Titanium Generic.
      - Menghilangkan selektor warna aksen manual yang usang untuk menjaga estetika kartu realistis yang konsisten.

---

## 📱 Navigasi & Tampilan Antarmuka (Apple HIG)

- **Landing Page / Layar Sambutan**: Halaman pembuka minimalis (*quiet luxury design*) yang menyambut pengguna saat pertama kali membuka aplikasi tanpa sesi login aktif. Memperkenalkan pilar utama MyFinance (buku besar integer Rupiah, cloud terisolasi RLS, OCR struk, dan keamanan biometrik) dengan tombol aksi bersih dan tipografi modern tanpa garis bawah (*clean text buttons*).
- **Tab Bar Navigasi Utama:**
  1. **Home / Dashboard**: Ringkasan saldo bersih, total aset, mutasi terkini, dan pintasan cepat.
  2. **Transaksi**: Riwayat pencatatan arus kas bulanan, filter transaksi, dan penambahan mutasi.
  3. **Dompet**: Manajemen dompet/rekening (tunai, bank, e-wallet), saldo real-time, dan arsip dompet.
  4. **Profil**: Informasi akun pengguna, status sesi cloud aktif, preferensi keamanan, dan tombol keluar.
- **Rute Khusus & Modal Cepat:**
  - **Aksi Cepat (Quick Actions Modal `+`)**: Akses instan pencatatan pengeluaran, pemasukan, transfer saldo, anggaran bulanan, laporan keuangan, dan pemindai struk OCR. Didesain ramah layar sentuh dan dioptimalkan secara adaptif untuk browser seluler (termasuk Safari di iOS) dengan penanganan *isScrollControlled*, *useSafeArea*, dan *SingleChildScrollView* agar tidak terpotong oleh *floating address bar* atau *home indicator*.
  - **Laporan Keuangan**: Grafik arus kas bulanan, perbandingan periode, serta ekspor laporan ke format PDF dan CSV (dapat diakses langsung via AppBar Dashboard dan menu aksi cepat `+`).
  - **Anggaran Bulanan**: Manajemen batas pengeluaran per kategori dengan progres real-time.
  - **Pengaturan (Settings)**:
    - *Tampilan & Tema*: Pemilihan tema Sistem, Terang, atau Gelap di urutan paling atas.
    - *Umum*: Format Wilayah & Bahasa (id_ID), Awal Periode Laporan (Tgl 1), Mata Uang Utama (IDR Rupiah tabular figures), dan sheet reaktif Daftar Kategori.
    - *Keamanan & Privasi*: Pengaturan Kunci Aplikasi PIN/Biometrik dan informasi privasi enkripsi TLS 1.3.

---

## 📂 Struktur Direktori Proyek

```text
assets/
├── icons/                      # Ikon-ikon aplikasi
├── images/                     # Gambar dan ilustrasi
└── kartu_bank/                 # 12 Aset grafis kartu debit fisik bank Indonesia (BCA, Mandiri, BNI, BRI, BSI, BTN, CIMB, Danamon, Jago, OCBC, Permata, SeaBank)
lib/
├── app/                        # Bootstrapping aplikasi, App Providers, Router (GoRouter), Shell
├── core/
│   ├── config/                 # Konfigurasi Supabase (URL, Anon Key, Enkripsi)
│   ├── database/               # Drift SQLite lokal (Cache & Offline Support)
│   ├── errors/                 # Domain Failures & Exceptions terstandarisasi
│   ├── formatting/             # Formatter Tanggal & Integer Rupiah (CurrencyFormatter)
│   ├── network/                # Supabase Service & Client Lifecycle
│   ├── services/               # AppLockService (PIN & Biometrik)
│   ├── theme/                  # Desain Token Apple HIG (Warna, Tipografi, Spacing, Tema)
│   └── utils/                  # AppHaptics, FileExportHelper, FilePickerHelper
├── features/
│   ├── auth/                   # Supabase Auth: Login, Register, Forgot & Reset Password
│   ├── wallets/                # Engine Saldo Cloud & Drift Cache, CRUD Dompet
│   ├── categories/             # Manajemen Kategori Cloud Pemasukan & Pengeluaran
│   ├── transactions/           # Buku Besar Cloud, Transaksi Pemasukan, Pengeluaran & Transfer
│   ├── transfers/              # Transfer Antar-Dompet Cloud dengan Integritas Aset
│   ├── budgets/                # Anggaran Bulanan Cloud, Limit Kategori, Indikator Real-time
│   ├── receipt_scanner/        # Pemindai Struk, OCR, dan Supabase Storage Private Bucket
│   ├── reports/                # Laporan Finansial Bulanan, Ekspor PDF & CSV
│   ├── backup_restore/         # Cadangan & Pemulihan Cloud JSON terenkripsi
│   ├── migration/              # Modul Migrasi Data Lokal SQLite ke Cloud Supabase
│   ├── profile/                # Halaman Profil Pengguna Minimalis Apple HIG
│   ├── security/               # Layar Kunci Biometrik & PIN (AppLockListener)
│   └── settings/               # Pengaturan Tema, Format Regional, dan Kategori
└── shared/                     # Komponen UI Reusable Minimalis (Buttons, TextFields, Cards)
```

---

## 🚀 Panduan Menjalankan Proyek

### Prasyarat
- **Flutter SDK**: `>= 3.19.0` (Dart `>= 3.3.0`)
- **Git**
- **Xcode** (untuk simulator iOS / macOS) atau **Android Studio**
- Akun atau Proyek **Supabase** aktif

### 1. Klon Repositori
```bash
git clone https://github.com/febriezm/app-finance.git
cd app-finance
```

### 2. Konfigurasi Lingkungan Supabase
Aplikasi menggunakan environment configuration untuk URL dan Anon Key Supabase. Pastikan `supabase/migrations/` telah diaplikasikan pada proyek Supabase Anda:

```bash
# Direktori migrasi basis data PostgreSQL:
supabase/migrations/
├── 20261123180001_create_extensions_and_utilities.sql
├── 20261123180002_create_profiles_table.sql
├── 20261123180003_create_wallets_table.sql
├── 20261123180004_create_categories_table.sql
├── 20261123180005_create_transactions_table.sql
├── 20261123180006_create_transaction_attachments_table.sql
├── 20261123180007_create_budgets_table.sql
├── 20261123180008_create_budget_category_limits_table.sql
├── 20261123180009_create_app_settings_table.sql
├── 20261123180010_create_row_level_security_policies.sql
├── 20261123180011_create_storage_bucket_and_policies.sql
└── 20261123180012_create_rpc_functions.sql
```

### 3. Instalasi Dependensi
```bash
flutter pub get
```

### 4. Menjalankan Aplikasi
```bash
# Menjalankan di perangkat / simulator (contoh: Chrome atau iOS)
flutter run -d chrome
# atau
flutter run -d iPhone
```

### 5. Menjalankan Pratinjau Web Rilis
```bash
# Build paket rilis web
flutter build web --release

# Jalankan server lokal untuk pratinjau
python -m http.server 8085 --directory build/web

# Buka pada browser:
# http://localhost:8085
```

---

## 🧪 Pengujian & Jaminan Kualitas

Aplikasi dilengkapi suite pengujian otomatis komprehensif mencakup unit test arsitektur cloud, integritas buku besar, dan skenario interaksi widget:

```bash
# 1. Analisis statis kode (Harus 0 issues)
flutter analyze

# 2. Menjalankan seluruh pengujian unit domain & cloud repositories (207+ tests)
flutter test test/unit/

# 3. Menjalankan pengujian skenario aplikasi & navigasi auth
flutter test test/widget/app_launch_test.dart
```

### Status Verifikasi Pengujian
- **Static Analysis**: `flutter analyze` $\rightarrow$ **0 issues (Clean)**.
- **Unit Test Suite**: **207 dari 207 tests passed (100%)**.
- **Widget & Navigation Scenarios**: **6 dari 6 skenario lolos (100%)**.
  - Alur pembukaan pertama kali $\rightarrow$ Login & Registrasi wajib.
  - Sesi aktif $\rightarrow$ Langsung masuk ke Dashboard.
  - Penataan menu Pengaturan (Tampilan paling atas, Umum gabung mata uang & kategori reaktif).
  - Profil Pengguna mandiri pada Tab Bar.
  - Navigasi bolak-balik Login $\leftrightarrow$ Register $\leftrightarrow$ Forgot Password.
  - Isolasi AppLock dan pembersihan sesi saat Logout.

---

## 🛡️ Keamanan & Privasi Data

- **Row Level Security (RLS)**: Setiap kueri data ke Supabase dibatasi hanya untuk baris milik pengguna terautentikasi (`auth.uid()`). Upaya membaca atau mengubah data milik akun lain dicegah secara mutlak di tingkat mesin basis data.
- **Enkripsi dalam Transit**: Seluruh komunikasi antara aplikasi dan Supabase Cloud diamankan dengan protokol **TLS 1.3**.
- **Penyimpanan Struk Privat**: Bucket `receipts` berstatus privat; berkas hanya dapat diakses melalui *authenticated signed URL* berdurasi terbatas.
- **Zero Sensitive Credential Leaks**: Kunci `service_role` tidak pernah disertakan di sisi klien Flutter; hanya menggunakan *Publishable Anon Key*.

---

## 📄 Lisensi

Hak Cipta © 2026 MyFinance. Seluruh hak cipta dilindungi undang-undang.
