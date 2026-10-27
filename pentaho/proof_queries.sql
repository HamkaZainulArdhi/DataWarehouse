-- =============================================================
-- Kueri pembuktian nrg_dw (4 pertanyaan direktur, Bagian 1 & 3.3) INI BUAT TERAKHIRRAN
-- =============================================================
USE nrg_dw;

-- ---------- Q1: margin kotor per sub-kategori per kanal, YoY kuartal sama ----------
-- Contoh: Q1 2023 vs Q1 2022
SELECT p.sub_kategori, f.kanal, w.tahun, w.kuartal,
       SUM(f.qty) AS total_qty,
       SUM(f.penjualan_bersih) AS omzet_bersih,
       SUM(f.margin_kotor) AS margin_kotor
FROM fact_penjualan f
JOIN dim_produk p ON p.sk_produk = f.sk_produk
JOIN dim_waktu w ON w.id_tanggal = f.id_tanggal
WHERE w.kuartal = 1 AND w.tahun IN (2022, 2023)
  AND f.status_transaksi IN ('SELESAI','DIKIRIM','NORMAL','RETUR')
GROUP BY p.sub_kategori, f.kanal, w.tahun, w.kuartal
ORDER BY p.sub_kategori, f.kanal, w.tahun;

-- ---------- Q2: pelanggan online vs member toko (match HP) ----------
-- a) Sebaran tipe pelanggan di fact
SELECT pl.tipe, COUNT(*) AS baris_fact, COUNT(DISTINCT pl.hp_norm) AS hp_unik
FROM fact_penjualan f JOIN dim_pelanggan pl ON pl.sk_pelanggan = f.sk_pelanggan
GROUP BY pl.tipe;
-- b) HP yang muncul di ECOM sekaligus MEMBER (jawaban inti Q2)
SELECT COUNT(*) AS hp_overlap_online_member
FROM (SELECT hp_norm FROM dim_pelanggan WHERE tipe='ECOM' AND hp_norm IS NOT NULL GROUP BY hp_norm) e
JOIN (SELECT hp_norm FROM dim_pelanggan WHERE tipe='MEMBER' AND hp_norm IS NOT NULL GROUP BY hp_norm) m
  ON m.hp_norm = e.hp_norm;

-- ---------- Q3: kampanye diskon — volume naik tanpa gerus margin ----------
SELECT pr.kode_promo_norm, pr.nama_kampanye, pr.target_diskon_persen,
       COUNT(*) AS baris_terjual, SUM(f.qty) AS total_qty,
       SUM(f.penjualan_bersih) AS omzet_bersih, SUM(f.margin_kotor) AS margin_kotor,
       IF(SUM(f.penjualan_bersih)=0, 0, SUM(f.margin_kotor)/SUM(f.penjualan_bersih)) AS margin_ratio
FROM fact_penjualan f JOIN dim_promo pr ON pr.sk_promo = f.sk_promo
WHERE f.sk_promo IS NOT NULL
GROUP BY pr.kode_promo_norm, pr.nama_kampanye, pr.target_diskon_persen
ORDER BY total_qty DESC, margin_ratio DESC;

-- ---------- Q4: produk laku di MPL tapi sepi di toko fisik & web ----------
SELECT p.material_no, p.nama_produk, p.sub_kategori,
       SUM(IF(f.kanal='MARKETPLACE', f.qty, 0)) AS qty_mpl,
       SUM(IF(f.kanal='TOKO_FISIK', f.qty, 0)) AS qty_toko,
       SUM(IF(f.kanal='WEB', f.qty, 0)) AS qty_web,
       SUM(f.qty) AS qty_total
FROM fact_penjualan f JOIN dim_produk p ON p.sk_produk = f.sk_produk
GROUP BY p.material_no, p.nama_produk, p.sub_kategori
HAVING qty_mpl > qty_toko AND qty_mpl > qty_web AND qty_total >= 10
ORDER BY qty_mpl DESC
LIMIT 20;
