-- Migration: Dukungan Kolom Phone dan Full Name pada auth.users dan public.profiles
-- Deskripsi: Menjamin nomor telepon selalu terisi di tabel auth.users (kolom Phone) dan profiles

-- 1. Tambah kolom full_name dan phone pada tabel public.profiles jika belum ada
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;

-- 2. Stored Procedure (RPC) untuk memperbarui nomor telepon langsung ke auth.users dan profiles
CREATE OR REPLACE FUNCTION public.update_user_phone(p_phone TEXT)
RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Pengguna belum terautentikasi (401 Unauthorized)';
    END IF;

    -- Update kolom phone di auth.users agar muncul di dashboard Supabase Authentication > Users
    UPDATE auth.users
    SET phone = p_phone,
        phone_confirmed_at = COALESCE(phone_confirmed_at, NOW()),
        updated_at = NOW()
    WHERE id = v_user_id;

    -- Update kolom phone di public.profiles
    UPDATE public.profiles
    SET phone = p_phone,
        updated_at = NOW()
    WHERE id = v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Trigger otomatis: Jika metadata user diperbarui dengan 'phone', salin ke auth.users.phone
CREATE OR REPLACE FUNCTION public.sync_user_phone_from_metadata()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.raw_user_meta_data->>'phone' IS NOT NULL AND (NEW.phone IS NULL OR NEW.phone = '') THEN
        NEW.phone := NEW.raw_user_meta_data->>'phone';
        IF NEW.phone_confirmed_at IS NULL THEN
            NEW.phone_confirmed_at := NOW();
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_sync_user_phone ON auth.users;
CREATE TRIGGER tr_sync_user_phone
    BEFORE INSERT OR UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.sync_user_phone_from_metadata();
