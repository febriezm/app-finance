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
