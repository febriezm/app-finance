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
