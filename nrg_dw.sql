-- hamka
-- ini database output cuma stuktur nya, ga ada data nya, 
-- biar di isi pas kalian run pentaho nya 1 1

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `nrg_dw`
--

-- --------------------------------------------------------

--
-- Struktur dari tabel `dim_pelanggan`
--

CREATE TABLE `dim_pelanggan` (
  `sk_pelanggan` int(11) NOT NULL,
  `tipe` varchar(12) NOT NULL COMMENT 'ECOM/MEMBER/MPL_ANON/UNKNOWN',
  `customer_id` int(11) DEFAULT NULL,
  `member_no` varchar(20) DEFAULT NULL,
  `buyer_hash` varchar(64) DEFAULT NULL,
  `nama` varchar(120) DEFAULT NULL,
  `hp_norm` varchar(20) DEFAULT NULL COMMENT 'dinormalkan: digit saja, 0xxx -> 62xxx',
  `email` varchar(120) DEFAULT NULL,
  `kota_baku` varchar(60) DEFAULT NULL,
  `gender` char(1) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Struktur dari tabel `dim_produk`
--

CREATE TABLE `dim_produk` (
  `sk_produk` int(11) NOT NULL,
  `material_no` varchar(20) NOT NULL,
  `nama_produk` varchar(150) NOT NULL,
  `brand` varchar(60) DEFAULT NULL,
  `kategori` varchar(60) DEFAULT NULL,
  `sub_kategori` varchar(60) DEFAULT NULL,
  `supplier` varchar(120) DEFAULT NULL,
  `status` varchar(15) DEFAULT NULL,
  `is_unknown` tinyint(4) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Struktur dari tabel `dim_promo`
--

CREATE TABLE `dim_promo` (
  `sk_promo` int(11) NOT NULL,
  `kode_promo_norm` varchar(30) NOT NULL,
  `nama_kampanye` varchar(120) DEFAULT NULL,
  `jenis_promo` varchar(30) DEFAULT NULL,
  `kanal_promo` varchar(30) DEFAULT NULL,
  `tanggal_mulai` date DEFAULT NULL,
  `tanggal_selesai` date DEFAULT NULL,
  `target_diskon_persen` decimal(5,2) DEFAULT NULL,
  `sumber` varchar(5) NOT NULL COMMENT 'S1/S5'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Struktur dari tabel `dim_toko_kanal`
--

CREATE TABLE `dim_toko_kanal` (
  `sk_toko_kanal` int(11) NOT NULL,
  `kanal` varchar(15) NOT NULL COMMENT 'WEB/TOKO_FISIK/MARKETPLACE/UNKNOWN',
  `kode_toko` varchar(20) NOT NULL COMMENT 'WEB/TS01..TS42/marketplace_a/marketplace_b',
  `nama_toko` varchar(120) DEFAULT NULL,
  `kota_baku` varchar(60) DEFAULT NULL,
  `provinsi` varchar(60) DEFAULT NULL,
  `format_toko` varchar(30) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Struktur dari tabel `dim_waktu`
--

CREATE TABLE `dim_waktu` (
  `id_tanggal` date NOT NULL,
  `tahun` smallint(6) NOT NULL,
  `kuartal` tinyint(4) NOT NULL,
  `bulan` tinyint(4) NOT NULL,
  `nama_bulan` varchar(15) NOT NULL,
  `minggu_ke` smallint(6) NOT NULL,
  `tanggal` smallint(6) NOT NULL,
  `hari_ke` tinyint(4) NOT NULL COMMENT '1=Senin..7=Minggu',
  `nama_hari` varchar(10) NOT NULL,
  `is_weekend` tinyint(4) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

-- Isi 2022-2023 (rentang data S1-S3). Minggu ISO.
INSERT INTO dim_waktu (id_tanggal, tahun, kuartal, bulan, nama_bulan, minggu_ke, tanggal, hari_ke, nama_hari, is_weekend)
WITH RECURSIVE d AS (
  SELECT DATE('2022-01-01') AS t UNION ALL SELECT DATE_ADD(t, INTERVAL 1 DAY) FROM d WHERE t < '2023-12-31'
)
SELECT t, YEAR(t), QUARTER(t), MONTH(t), MONTHNAME(t), WEEK(t, 3), DAY(t),
       WEEKDAY(t)+1, DAYNAME(t), IF(WEEKDAY(t) >= 5, 1, 0) FROM d;

--
-- Struktur dari tabel `err_promo_s5`
--

CREATE TABLE `err_promo_s5` (
  `id` int(11) NOT NULL,
  `kode_promo_raw` varchar(60) DEFAULT NULL,
  `nama_kampanye` varchar(120) DEFAULT NULL,
  `alasan` varchar(200) DEFAULT NULL,
  `loaded_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Struktur dari tabel `fact_penjualan`
--

CREATE TABLE `fact_penjualan` (
  `id_fact` bigint(20) NOT NULL,
  `id_tanggal` date NOT NULL,
  `sk_produk` int(11) NOT NULL,
  `sk_pelanggan` int(11) NOT NULL,
  `sk_toko_kanal` int(11) NOT NULL,
  `sk_promo` int(11) DEFAULT NULL,
  `no_transaksi` varchar(40) NOT NULL COMMENT 'order_id/trx_no/invoice',
  `line_no` smallint(6) NOT NULL,
  `kanal` varchar(15) NOT NULL,
  `qty` int(11) NOT NULL,
  `harga_ex_ppn` decimal(15,2) NOT NULL COMMENT 'per unit, tanpa PPN',
  `disc_amount` decimal(15,2) NOT NULL DEFAULT 0.00,
  `penjualan_bersih` decimal(15,2) NOT NULL COMMENT 'qty*harga_ex_ppn - disc',
  `hpp_total` decimal(15,2) NOT NULL DEFAULT 0.00 COMMENT 'qty * HPP S4 (0 jika UNKNOWN)',
  `fee_komisi` decimal(15,2) NOT NULL DEFAULT 0.00 COMMENT 'hanya S3, alokasi proporsional',
  `margin_kotor` decimal(15,2) NOT NULL COMMENT 'bersih - hpp - fee',
  `status_transaksi` varchar(15) NOT NULL,
  `sumber` varchar(5) NOT NULL COMMENT 'S1/S2/S3',
  `payment_info` varchar(80) DEFAULT NULL COMMENT 'S1 payment_method / S2 concat method / S3 channel'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Struktur dari tabel `stg_produk_hpp`
--

CREATE TABLE `stg_produk_hpp` (
  `material_no` varchar(20) NOT NULL,
  `harga_pokok` decimal(15,2) NOT NULL,
  `berlaku_sejak` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Indexes for dumped tables
--

--
-- Indeks untuk tabel `dim_pelanggan`
--
ALTER TABLE `dim_pelanggan`
  ADD PRIMARY KEY (`sk_pelanggan`),
  ADD KEY `idx_pel_hp` (`hp_norm`),
  ADD KEY `idx_pel_tipe` (`tipe`),
  ADD KEY `idx_pel_hash` (`buyer_hash`);

--
-- Indeks untuk tabel `dim_produk`
--
ALTER TABLE `dim_produk`
  ADD PRIMARY KEY (`sk_produk`),
  ADD UNIQUE KEY `material_no` (`material_no`);

--
-- Indeks untuk tabel `dim_promo`
--
ALTER TABLE `dim_promo`
  ADD PRIMARY KEY (`sk_promo`),
  ADD UNIQUE KEY `uq_promo_periode` (`kode_promo_norm`,`tanggal_mulai`);

--
-- Indeks untuk tabel `dim_toko_kanal`
--
ALTER TABLE `dim_toko_kanal`
  ADD PRIMARY KEY (`sk_toko_kanal`),
  ADD UNIQUE KEY `uq_kanal_kode` (`kanal`,`kode_toko`);

--
-- Indeks untuk tabel `dim_waktu`
--
ALTER TABLE `dim_waktu`
  ADD PRIMARY KEY (`id_tanggal`);

--
-- Indeks untuk tabel `err_promo_s5`
--
ALTER TABLE `err_promo_s5`
  ADD PRIMARY KEY (`id`);

--
-- Indeks untuk tabel `fact_penjualan`
--
ALTER TABLE `fact_penjualan`
  ADD PRIMARY KEY (`id_fact`),
  ADD UNIQUE KEY `uq_fact` (`no_transaksi`,`line_no`,`sumber`),
  ADD KEY `idx_fact_tgl` (`id_tanggal`),
  ADD KEY `idx_fact_prod` (`sk_produk`),
  ADD KEY `idx_fact_kanal` (`kanal`),
  ADD KEY `fk_fact_pel` (`sk_pelanggan`),
  ADD KEY `fk_fact_toko` (`sk_toko_kanal`),
  ADD KEY `fk_fact_promo` (`sk_promo`);

--
-- Indeks untuk tabel `stg_produk_hpp`
--
ALTER TABLE `stg_produk_hpp`
  ADD KEY `idx_hpp` (`material_no`,`berlaku_sejak`);

--
-- AUTO_INCREMENT untuk tabel yang dibuang
--

--
-- AUTO_INCREMENT untuk tabel `dim_pelanggan`
--
ALTER TABLE `dim_pelanggan`
  MODIFY `sk_pelanggan` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `dim_produk`
--
ALTER TABLE `dim_produk`
  MODIFY `sk_produk` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `dim_promo`
--
ALTER TABLE `dim_promo`
  MODIFY `sk_promo` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `dim_toko_kanal`
--
ALTER TABLE `dim_toko_kanal`
  MODIFY `sk_toko_kanal` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `err_promo_s5`
--
ALTER TABLE `err_promo_s5`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `fact_penjualan`
--
ALTER TABLE `fact_penjualan`
  MODIFY `id_fact` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- Ketidakleluasaan untuk tabel pelimpahan (Dumped Tables)
--

--
-- Ketidakleluasaan untuk tabel `fact_penjualan`
--
ALTER TABLE `fact_penjualan`
  ADD CONSTRAINT `fk_fact_pel` FOREIGN KEY (`sk_pelanggan`) REFERENCES `dim_pelanggan` (`sk_pelanggan`),
  ADD CONSTRAINT `fk_fact_prod` FOREIGN KEY (`sk_produk`) REFERENCES `dim_produk` (`sk_produk`),
  ADD CONSTRAINT `fk_fact_promo` FOREIGN KEY (`sk_promo`) REFERENCES `dim_promo` (`sk_promo`),
  ADD CONSTRAINT `fk_fact_toko` FOREIGN KEY (`sk_toko_kanal`) REFERENCES `dim_toko_kanal` (`sk_toko_kanal`),
  ADD CONSTRAINT `fk_fact_waktu` FOREIGN KEY (`id_tanggal`) REFERENCES `dim_waktu` (`id_tanggal`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
