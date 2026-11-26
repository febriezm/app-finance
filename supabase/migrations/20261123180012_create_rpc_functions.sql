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
