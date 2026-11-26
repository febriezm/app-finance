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
