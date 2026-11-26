-- Migration 09: Tabel App Settings (Preferensi & Konfigurasi Pengguna)
-- Deskripsi: Key-value store preferensi aplikasi per pengguna (mata uang, tema, app lock)

CREATE TABLE public.app_settings (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    key VARCHAR(100) NOT NULL,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, key)
);
