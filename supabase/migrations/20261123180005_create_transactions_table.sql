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
