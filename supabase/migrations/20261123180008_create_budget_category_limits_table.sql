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
