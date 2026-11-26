-- Migration 01: Ekstensi & Fungsi Utilitas
-- Deskripsi: Menyiapkan uuid-ossp dan fungsi trigger otomatis updated_at

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Fungsi otomatisasi pembaruan updated_at pada saat baris diperbarui
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
