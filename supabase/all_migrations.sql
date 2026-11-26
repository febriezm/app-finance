-- Migration 01: Ekstensi & Fungsi Utilitas
-- Deskripsi: Menyiapkan uuid-ossp dan fungsi trigger otomatis updated_at

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Fungsi otomatisasi pembaruan updated_at pada saat baris diperbarui
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- Migration 02: Tabel Profiles (Ekstensi User Identity Supabase Auth)
-- Deskripsi: Menyimpan profil dasar pengguna terikat auth.users dengan auto-trigger saat pendaftaran

CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'IDR',
    theme_mode VARCHAR(10) NOT NULL DEFAULT 'system',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigger pembaruan timestamp updated_at
CREATE TRIGGER tr_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Fungsi & trigger untuk auto-create profil saat user baru terdaftar via Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email)
    VALUES (NEW.id, NEW.email);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 13. PEMBARUAN CONSTRAINT TRANSFER EKSTERNAL (BANK / ORANG LAIN)
-- ============================================================================
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS chk_transactions_transfer_wallets;

ALTER TABLE public.transactions ADD CONSTRAINT chk_transactions_transfer_wallets CHECK (
    (type = 'transfer' AND wallet_id IS NOT NULL AND (
        (destination_wallet_id IS NOT NULL AND wallet_id <> destination_wallet_id) OR
        (destination_wallet_id IS NULL AND (merchant IS NOT NULL OR description IS NOT NULL))
    )) OR
    (type <> 'transfer')
);


CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
-- Migration 03: Tabel Wallets (Dompet & Rekening Keuangan)
-- Deskripsi: Menyimpan rekening bank, kas tunai, e-wallet, dan akun aset finansial pengguna

CREATE TABLE public.wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('cash', 'bank', 'e_wallet', 'other')),
    opening_balance BIGINT NOT NULL DEFAULT 0,
    opening_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    currency_code VARCHAR(3) NOT NULL DEFAULT 'IDR',
    icon_key VARCHAR(50),
    color_hex VARCHAR(20),
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indeks performa per pengguna
CREATE INDEX idx_wallets_user_id ON public.wallets(user_id);
CREATE INDEX idx_wallets_user_archived ON public.wallets(user_id, is_archived);

-- Trigger pembaruan timestamp updated_at
CREATE TRIGGER tr_wallets_updated_at
    BEFORE UPDATE ON public.wallets
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
-- Migration 04: Tabel Categories & Initial System Seeds
-- Deskripsi: Menyimpan pos kategori pemasukan & pengeluaran (sistem global & kustom pengguna)

CREATE TABLE public.categories (
    id TEXT PRIMARY KEY, -- Mendukung ID bawaan (cth: 'cat-exp-food') dan UUID kustom
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- NULL untuk kategori bawaan sistem
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('income', 'expense')),
    icon_key VARCHAR(50),
    color_hex VARCHAR(20),
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_categories_user_or_system CHECK (
        (is_system = TRUE AND user_id IS NULL) OR
        (is_system = FALSE AND user_id IS NOT NULL)
    )
);

-- Indeks performa query kategori per pengguna
CREATE INDEX idx_categories_user_type ON public.categories(user_id, type, is_archived);

-- Trigger pembaruan timestamp updated_at
CREATE TRIGGER tr_categories_updated_at
    BEFORE UPDATE ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- SEED 11 KATEGORI BAWAAN SISTEM (Identik 100% dengan SQLite AppDatabase)
INSERT INTO public.categories (id, user_id, name, type, icon_key, color_hex, is_system, is_archived, sort_order) VALUES
-- Kategori Pemasukan (Income)
('cat-inc-salary', NULL, 'Gaji', 'income', 'briefcase', '0xFF0E7A4A', TRUE, FALSE, 1),
('cat-inc-bonus', NULL, 'Bonus & THR', 'income', 'gift', '0xFF2ED573', TRUE, FALSE, 2),
('cat-inc-investment', NULL, 'Investasi', 'income', 'trending-up', '0xFF10AC84', TRUE, FALSE, 3),
('cat-inc-other', NULL, 'Pemasukan Lainnya', 'income', 'plus-circle', '0xFF0984E3', TRUE, FALSE, 4),

-- Kategori Pengeluaran (Expense)
('cat-exp-food', NULL, 'Makanan & Minuman', 'expense', 'utensils', '0xFFD63031', TRUE, FALSE, 1),
('cat-exp-transport', NULL, 'Transportasi', 'expense', 'car', '0xFFE17055', TRUE, FALSE, 2),
('cat-exp-bills', NULL, 'Tagihan & Utilitas', 'expense', 'file-text', '0xFFE67E22', TRUE, FALSE, 3),
('cat-exp-shopping', NULL, 'Belanja & Kebutuhan', 'expense', 'shopping-bag', '0xFF9B59B6', TRUE, FALSE, 4),
('cat-exp-entertainment', NULL, 'Hiburan & Liburan', 'expense', 'film', '0xFFF368E0', TRUE, FALSE, 5),
('cat-exp-health', NULL, 'Kesehatan', 'expense', 'heart', '0xFFFF6B6B', TRUE, FALSE, 6),
('cat-exp-other', NULL, 'Pengeluaran Lainnya', 'expense', 'more-horizontal', '0xFF636E72', TRUE, FALSE, 7)
ON CONFLICT (id) DO NOTHING;
-- Migration 05: Tabel Transactions (Buku Besar Mutasi Transaksi)
-- Deskripsi: Menyimpan seluruh transaksi (pemasukan, pengeluaran, dan transfer internal antar dompet)

CREATE TABLE public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
    amount BIGINT NOT NULL CHECK (amount > 0),
    occurred_at TIMESTAMPTZ NOT NULL,
    wallet_id UUID REFERENCES public.wallets(id) ON DELETE RESTRICT,
    destination_wallet_id UUID REFERENCES public.wallets(id) ON DELETE RESTRICT,
    category_id TEXT REFERENCES public.categories(id) ON DELETE RESTRICT,
    merchant TEXT,
    description TEXT,
    notes TEXT,
    source VARCHAR(30) NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'receipt_scan', 'recurring')),
    status VARCHAR(20) NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed', 'voided')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Integritas Data Transaksi:
    -- 1. Transfer wajib memiliki wallet sumber dan tujuan yang berbeda
    CONSTRAINT chk_transactions_transfer_wallets CHECK (
        (type = 'transfer' AND wallet_id IS NOT NULL AND destination_wallet_id IS NOT NULL AND wallet_id <> destination_wallet_id) OR
        (type <> 'transfer')
    ),
    -- 2. Income/Expense wajib memiliki wallet_id dan category_id, serta destination_wallet_id harus NULL
    CONSTRAINT chk_transactions_income_expense_wallets CHECK (
        (type IN ('income', 'expense') AND wallet_id IS NOT NULL AND destination_wallet_id IS NULL AND category_id IS NOT NULL) OR
        (type = 'transfer')
    )
);

-- Indeks performa query buku besar dan dashboard per pengguna
CREATE INDEX idx_transactions_user_occurred ON public.transactions(user_id, occurred_at DESC);
CREATE INDEX idx_transactions_user_type_status ON public.transactions(user_id, type, status, occurred_at DESC);
CREATE INDEX idx_transactions_user_wallet ON public.transactions(user_id, wallet_id, occurred_at DESC);
CREATE INDEX idx_transactions_user_dest_wallet ON public.transactions(user_id, destination_wallet_id, occurred_at DESC);
CREATE INDEX idx_transactions_user_category ON public.transactions(user_id, category_id, occurred_at DESC);

-- Trigger pembaruan timestamp updated_at
CREATE TRIGGER tr_transactions_updated_at
    BEFORE UPDATE ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
-- Migration 06: Tabel Transaction Attachments (Lampiran Foto Struk Belanja)
-- Deskripsi: Menyimpan referensi foto struk belanja terikat transaksi dengan ON DELETE CASCADE

CREATE TABLE public.transaction_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    transaction_id UUID NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL, -- Path berkas di Supabase Storage (cth: 'receipts/<user_id>/<attachment_id>.jpg')
    mime_type VARCHAR(50) NOT NULL DEFAULT 'image/jpeg',
    file_size INT NOT NULL CHECK (file_size > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indeks relasi lampiran per transaksi
CREATE INDEX idx_attachments_user_tx ON public.transaction_attachments(user_id, transaction_id);
-- Migration 07: Tabel Budgets (Master Anggaran Bulanan)
-- Deskripsi: Menyimpan plafon total anggaran pengeluaran bulanan (format YYYY-MM) per pengguna

CREATE TABLE public.budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    month_key VARCHAR(7) NOT NULL CHECK (month_key ~ '^[0-9]{4}-[0-9]{2}$'), -- Validasi regex format YYYY-MM
    total_limit BIGINT NOT NULL CHECK (total_limit >= 0),
    alert_thresholds JSONB NOT NULL DEFAULT '[75, 90, 100]'::jsonb,
    carry_over_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- 1 user hanya memiliki 1 master budget per bulan
    CONSTRAINT uq_budgets_user_month UNIQUE (user_id, month_key)
);

-- Indeks performa pencarian budget bulanan
CREATE INDEX idx_budgets_user_month ON public.budgets(user_id, month_key);

-- Trigger pembaruan timestamp updated_at
CREATE TRIGGER tr_budgets_updated_at
    BEFORE UPDATE ON public.budgets
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
-- Migration 08: Tabel Budget Category Limits (Sub-Alokasi Plafon Kategori)
-- Deskripsi: Menyimpan batas pengeluaran spesifik per kategori di bawah anggaran master

CREATE TABLE public.budget_category_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    budget_id UUID NOT NULL REFERENCES public.budgets(id) ON DELETE CASCADE,
    category_id TEXT NOT NULL REFERENCES public.categories(id) ON DELETE RESTRICT,
    limit_amount BIGINT NOT NULL CHECK (limit_amount >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Kombinasi budget_id dan category_id harus unik
    CONSTRAINT uq_budget_cat_limits UNIQUE (budget_id, category_id)
);

-- Indeks performa pencarian limit per master budget
CREATE INDEX idx_budget_limits_user_budget ON public.budget_category_limits(user_id, budget_id);
-- Migration 09: Tabel App Settings (Preferensi & Konfigurasi Pengguna)
-- Deskripsi: Key-value store preferensi aplikasi per pengguna (mata uang, tema, app lock)

CREATE TABLE public.app_settings (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    key VARCHAR(100) NOT NULL,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, key)
);
-- Migration 10: Kebijakan Keamanan Row Level Security (RLS)
-- Deskripsi: Mengaktifkan RLS dan membuat kebijakan ketat pada seluruh tabel data finansial

-- 1. AKTIFKAN RLS PADA SELURUH TABEL
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budget_category_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- 2. KEBIJAKAN PROFILES
CREATE POLICY "profiles_select_own" ON public.profiles
    FOR SELECT TO authenticated USING (auth.uid() = id);

CREATE POLICY "profiles_insert_own" ON public.profiles
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON public.profiles
    FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_delete_own" ON public.profiles
    FOR DELETE TO authenticated USING (auth.uid() = id);

-- 3. KEBIJAKAN WALLETS
CREATE POLICY "wallets_select_own" ON public.wallets
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "wallets_insert_own" ON public.wallets
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "wallets_update_own" ON public.wallets
    FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "wallets_delete_own" ON public.wallets
    FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- 4. KEBIJAKAN CATEGORIES (Sistem Global + Kustom Pengguna)
-- User dapat membaca kategori sistem bawaan (user_id IS NULL) DAN kategori miliknya sendiri
CREATE POLICY "categories_select_system_and_own" ON public.categories
    FOR SELECT TO authenticated USING (user_id IS NULL OR user_id = auth.uid());

-- User hanya dapat membuat, mengedit, atau menghapus kategori kustom miliknya sendiri
CREATE POLICY "categories_insert_own" ON public.categories
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id AND is_system = FALSE);

CREATE POLICY "categories_update_own" ON public.categories
    FOR UPDATE TO authenticated USING (auth.uid() = user_id AND is_system = FALSE) WITH CHECK (auth.uid() = user_id AND is_system = FALSE);

CREATE POLICY "categories_delete_own" ON public.categories
    FOR DELETE TO authenticated USING (auth.uid() = user_id AND is_system = FALSE);

-- 5. KEBIJAKAN TRANSACTIONS
CREATE POLICY "transactions_select_own" ON public.transactions
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "transactions_insert_own" ON public.transactions
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "transactions_update_own" ON public.transactions
    FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "transactions_delete_own" ON public.transactions
    FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- 6. KEBIJAKAN TRANSACTION ATTACHMENTS
CREATE POLICY "attachments_select_own" ON public.transaction_attachments
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "attachments_insert_own" ON public.transaction_attachments
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "attachments_update_own" ON public.transaction_attachments
    FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "attachments_delete_own" ON public.transaction_attachments
    FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- 7. KEBIJAKAN BUDGETS
CREATE POLICY "budgets_select_own" ON public.budgets
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "budgets_insert_own" ON public.budgets
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "budgets_update_own" ON public.budgets
    FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "budgets_delete_own" ON public.budgets
    FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- 8. KEBIJAKAN BUDGET CATEGORY LIMITS
CREATE POLICY "budget_limits_select_own" ON public.budget_category_limits
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "budget_limits_insert_own" ON public.budget_category_limits
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "budget_limits_update_own" ON public.budget_category_limits
    FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "budget_limits_delete_own" ON public.budget_category_limits
    FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- 9. KEBIJAKAN APP SETTINGS
CREATE POLICY "app_settings_select_own" ON public.app_settings
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "app_settings_insert_own" ON public.app_settings
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "app_settings_update_own" ON public.app_settings
    FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "app_settings_delete_own" ON public.app_settings
    FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- 10. HAK AKSES PERAN POSTGRESQL (ROLE GRANTS)
-- Memberikan izin dasar skema & tabel ke peran Supabase (anon, authenticated, service_role).
-- Akses data baris tetap terisolasi 100% dan dikontrol mutlak oleh aturan RLS (auth.uid() = user_id) di atas.
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
-- Migration 11: Konfigurasi Supabase Storage & Kebijakan Berkas Struk
-- Deskripsi: Membuat bucket privat 'receipts' dan mengamankan berkas berdasarkan user_id

-- 1. DAFTARKAN BUCKET STORAGE PRIVAT 'receipts'
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'receipts',
    'receipts',
    FALSE,
    5242880, -- Maksimal 5 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = FALSE,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- 2. KEBIJAKAN STORAGE RLS: HANYA MENGAKSES FOLDER MILIK SENDIRI
-- Pola path penyimpanan: receipts/<user_id>/<attachment_id>.jpg

CREATE POLICY "storage_receipts_select_own"
    ON storage.objects FOR SELECT TO authenticated
    USING (
        bucket_id = 'receipts' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "storage_receipts_insert_own"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'receipts' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "storage_receipts_update_own"
    ON storage.objects FOR UPDATE TO authenticated
    USING (
        bucket_id = 'receipts' AND
        (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'receipts' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "storage_receipts_delete_own"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'receipts' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );
-- Migration 12: Fungsi Stored Procedure (RPC) untuk Transaksi Atomik
-- Deskripsi: Menjamin atomisitas multi-tabel untuk penyimpanan budget & void transaksi

-- 1. RPC: Menyimpan master budget dan limit kategori dalam satu transaksi atomik
CREATE OR REPLACE FUNCTION public.save_budget_with_limits(
    p_budget_id UUID,
    p_month_key VARCHAR(7),
    p_total_limit BIGINT,
    p_alert_thresholds JSONB,
    p_carry_over BOOLEAN,
    p_notes TEXT,
    p_limits JSONB -- Array of JSON: [{"category_id": "cat-...", "limit_amount": 500000}]
)
RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_item JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Pengguna belum terautentikasi (401 Unauthorized)';
    END IF;

    -- Upsert master budget
    INSERT INTO public.budgets (
        id, user_id, month_key, total_limit, alert_thresholds, carry_over_enabled, notes
    ) VALUES (
        p_budget_id, v_user_id, p_month_key, p_total_limit, p_alert_thresholds, p_carry_over, p_notes
    )
    ON CONFLICT (user_id, month_key) DO UPDATE SET
        total_limit = EXCLUDED.total_limit,
        alert_thresholds = EXCLUDED.alert_thresholds,
        carry_over_enabled = EXCLUDED.carry_over_enabled,
        notes = EXCLUDED.notes,
        updated_at = NOW();

    -- Hapus limit kategori lama untuk budget ini
    DELETE FROM public.budget_category_limits 
    WHERE user_id = v_user_id AND budget_id = p_budget_id;

    -- Masukkan limit kategori baru
    IF p_limits IS NOT NULL AND jsonb_array_length(p_limits) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_limits) LOOP
            INSERT INTO public.budget_category_limits (
                user_id, budget_id, category_id, limit_amount
            ) VALUES (
                v_user_id, p_budget_id, (v_item->>'category_id'), (v_item->>'limit_amount')::BIGINT
            );
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 13. PEMBARUAN CONSTRAINT TRANSFER EKSTERNAL (BANK / ORANG LAIN)
-- ============================================================================
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS chk_transactions_transfer_wallets;

ALTER TABLE public.transactions ADD CONSTRAINT chk_transactions_transfer_wallets CHECK (
    (type = 'transfer' AND wallet_id IS NOT NULL AND (
        (destination_wallet_id IS NOT NULL AND wallet_id <> destination_wallet_id) OR
        (destination_wallet_id IS NULL AND (merchant IS NOT NULL OR description IS NOT NULL))
    )) OR
    (type <> 'transfer')
);


-- 2. RPC: Membatalkan transaksi (soft-delete / void) secara atomik
CREATE OR REPLACE FUNCTION public.void_transaction(
    p_transaction_id UUID
)
RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Pengguna belum terautentikasi (401 Unauthorized)';
    END IF;

    UPDATE public.transactions
    SET status = 'voided',
        updated_at = NOW()
    WHERE id = p_transaction_id AND user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transaksi tidak ditemukan atau bukan milik pengguna aktif';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 13. PEMBARUAN CONSTRAINT TRANSFER EKSTERNAL (BANK / ORANG LAIN)
-- ============================================================================
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS chk_transactions_transfer_wallets;

ALTER TABLE public.transactions ADD CONSTRAINT chk_transactions_transfer_wallets CHECK (
    (type = 'transfer' AND wallet_id IS NOT NULL AND (
        (destination_wallet_id IS NOT NULL AND wallet_id <> destination_wallet_id) OR
        (destination_wallet_id IS NULL AND (merchant IS NOT NULL OR description IS NOT NULL))
    )) OR
    (type <> 'transfer')
);

