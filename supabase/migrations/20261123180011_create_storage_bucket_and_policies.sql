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
