-- Migration: Pembaruan Constraint chk_transactions_transfer_wallets
-- Tanggal: 24 November 2026
-- Deskripsi: Mengizinkan mutasi transfer eksternal (Bank / Orang Lain) di mana destination_wallet_id bernilai NULL
--            dengan syarat rekanan (merchant) atau deskripsi terisi.

ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS chk_transactions_transfer_wallets;

ALTER TABLE public.transactions ADD CONSTRAINT chk_transactions_transfer_wallets CHECK (
    (type = 'transfer' AND wallet_id IS NOT NULL AND (
        (destination_wallet_id IS NOT NULL AND wallet_id <> destination_wallet_id) OR
        (destination_wallet_id IS NULL AND (merchant IS NOT NULL OR description IS NOT NULL))
    )) OR
    (type <> 'transfer')
);
