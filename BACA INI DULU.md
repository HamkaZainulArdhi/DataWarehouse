Buat laporan — bahan + cara jalanin

Databasenya ada 2:
1. nrg_ecom (database SUMBER / OLTP) — file dump-nya udah ada, tinggal import ke MySQL. Nama databasenya harus sama persis: nrg_ecom.
2. nrg_dw (database OUTPUT / warehouse) — yang ada baru strukturnya doang (nrg_dw.sql). tinggal import ke MySQL. NAMA databasenya: "nrg_dw", Datanya masih kosong, baru keisi pas Pentaho di-run.

FOLDER DATA CSV DAN JSON(s1-s5), JGN DI UTAK ATIK, PENTAHO NYA UDH AMBIL FILE DARI FOLDER INI

FILE PROOF_QUERIES.SQL, ITU BUAT AKHIRAN, BUAT JAWAB PERTANYAAN DIREKTUR

Urutan run di Spoon (satu-satu, jgn loncat say):
0_init_dw → 1_dim_produk → 2_dim_pelanggan_toko → 6_dim_promo_S5 → 5a_dim_mpl_buyers → 3_fact_S1_ecom → 4_fact_S2_pos → 5b_fact_S3_mpl


NGAPAIN AJA KTR KTR (kentirrrr) NYA :

0_init_dw — modal awal
- Masukan: tidak baca sumber mana-mana, cuma SQL INSERT langsung.
- Ngapain: bikin baris pengaman — pelanggan UNKNOWN, toko WEB/marketplace/UNKNOWN, promo NO_PROMO — plus isi dim_waktu tanggal 2022–2023. Tanpa ini, transaksi yang infonya tidak ketemu (member kosong, produk belum terdaftar) tidak punya tempat nyangkut.
- Keluaran: seed di tiap dimensi + 730 hari di dim_waktu.


1_dim_produk — kamus produk
- Masukan: produk_master.csv (S4, isinya riwayat — 1 material bisa muncul berkali-kali karena harga pokok direvisi) + supplier_master.csv.
- Ngapain: ambil atribut terakhir tiap material buat dimensi (SCD1, timpa saja), tapi SEMUA versi riwayat disimpan ke stg_produk_hpp karena fact butuh HPP yang berlaku pada tanggal transaksi, bukan HPP terakhir.
- Keluaran: dim_produk 61 baris (60 material + 1 UNKNOWN buat ORD-9999) + stg_produk_hpp 79 baris.


2_dim_pelanggan_toko — kamus orang + toko
- Masukan: customers + customer_addresses (S1, join is_primary=1 biar 1 pelanggan = 1 kota), member.csv (S2, delimiter ;), store_master.csv, ref_kota.csv.
- Ngapain: nomor HP dibersihkan (buang +, spasi, strip, titik) lalu diseragamkan ke format 62xxx — ini kunci jawaban Q2 (cocokkan ECOM vs MEMBER). Kota diseragamkan: UPPER(TRIM) lalu dipetakan lewat tabel alias (MDN→MEDAN, SBY→SURABAYA, dst; tidak dikenal → UNKNOWN). Buyer marketplace TIDAK dimasukkan di sini (cuma hash, tidak bisa di-match).
- Keluaran: dim_pelanggan 1201 baris (ECOM 600 + MEMBER 600 + UNKNOWN 1; MPL_ANON nyusul di 5a) + dim_toko_kanal 46 baris (42 toko + 4 seed).


6_dim_promo_S5 — kamus promo (file terkotor)
- Masukan: kampanye_marketing.csv (S5 — sengaja kotor: baris kosong, huruf besar-kecil campur, spasi berlebih, duplikat persis) + tabel vouchers S1.
- Ngapain: baris kosong dibuang; kode di-UPPER(TRIM) (newyear10→NEWYEAR10); duplikat persis digabung; kolom diskon dicek — yang isinya teks (sepuluh) dilempar ke tabel error, tidak dipaksa jadi angka; voucher S1 dinormalkan dan digabung (UNION) ke aliran yang sama.
- Keluaran: dim_promo 32 baris + err_promo_S5 1 baris (sepuluh, beserta alasannya).


5a_dim_mpl_buyers — kamus pembeli marketplace
- Masukan: 16 file JSON S3 (mpl_pull_page_*.json), diambil field level-record saja (buyer.hash, buyer.city).
- Ngapain: bikin nama samaran (MPL buyer <hash>), kota di-upper; dedup per hash (1530 record → 556 unik) karena retry API bikin data ganda. Tidak di-match ke ECOM/MEMBER (soal A.3.5: hash bukan identitas yang bisa dipadankan).
- Keluaran: dim_pelanggan tipe MPL_ANON 556 baris.


3_fact_S1_ecom — transaksi web
- Masukan: orders + order_items + vouchers + alamat HP dari nrg_ecom (status DIBATALKAN dibuang di SQL).
- Ngapain: SKU ECOM dipetakan ke material_no S4 (SKU-1001-996→P-1001; SKU-NEWARR-001→UNKNOWN); unit_price yang masih termasuk PPN dibagi 1,11; tanggal diambil dari order_ts; lookup ke 4 dimensi (gagal → default sk=1); HPP diambil dari staging sesuai tanggal transaksi.
- Keluaran: fact kanal WEB 4236 baris (sumber='S1').


4_fact_S2_pos — transaksi toko fisik
- Masukan: trx_header + trx_line + trx_payment 42 toko (delimiter ;, tanggal DD/MM/YYYY), dibaca 3x lalu di-join per trx_no.
- Ngapain: baris VOID (175) dibuang; harga sudah ex-PPN jadi tidak dibagi; disc_pct diubah ke rupiah (qty×harga×pct/100); payment SPLIT (868 transaksi multi-baris) digabung jadi CASH, DEBIT; member_no di-lookup ke dimensi.
- Keluaran: fact kanal TOKO_FISIK 8386 baris (sumber='S2', fee=0).


5b_fact_S3_mpl — transaksi marketplace (paling rumit)
- Masukan: JSON S3 yang sama, tapi dipecah dua step (satu baca record + kantong items, satu pecah items[] — PDI tidak bisa campur level).
- Ngapain: paid_at UTC +7 jam (Calculator); price incl-PPN dibagi 1,11; seller_sku ambil 4 digit kanan (SAMSUN1005→P-1005); 34 duplikat (invoice, seller_sku) dibuang ambil tarikan terakhir; fee per invoice (commission+service) dibagi proporsional ke tiap item; line_no nomor urut per invoice.
- Keluaran: fact kanal MARKETPLACE 1797 baris (sumber='S3').