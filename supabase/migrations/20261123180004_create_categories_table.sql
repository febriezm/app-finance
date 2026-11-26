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
