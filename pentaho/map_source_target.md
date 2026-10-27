# Peta Source-to-Target NRG DW (3.1.3) — ringkas

Grain: 1 baris/item (`S1.order_items`, `S2.trx_line`, `S3.items[]`).
Harga ex-PPN, waktu WIB, margin = bersih − HPP(S4) − fee(S3).

## Aturan global
- Produk → `dim_produk.material_no` (master S4). S1 `SKU-1001-996→P-1001` (MID 4 digit);
  S2 `item_code` langsung; S3 `seller_sku` (`SAMSUN1005→P-1005`, RIGHT 4 digit).
  Tanpa digit (`SKU-NEWARR-001`/ORD-9999) → `UNKNOWN` (late arriving, seed sk=1).
- `harga_ex_ppn`: S1 `/1.11` (Formula, aritmatika saja), S3 `/1.11`, S2 tetap (sudah ex-PPN).
- Derivasi string S1 (SKU→material, HP→62, kode promo, ymd) dikerjakan di SQL TableInput (MySQL/MariaDB deterministik), bukan Formula.
- `disc_amount`: S1 asli (Rp), S2 `qty*harga*disc_pct/100`, S3 kolom `voucher`.
- `penjualan_bersih = qty*harga_ex_ppn − disc_amount`.
- `hpp_total = qty * HPP`; HPP via Database Join ke `stg_produk_hpp`
  (`material_no=? AND berlaku_sejak<=? ORDER BY berlaku_sejak DESC LIMIT 1`, outer join;
  18 material multi-baris; miss → 0).
- `fee_komisi`: hanya S3, `(commission+service)` per invoice dialokasi `line_total/inv_total`; S1/S2 = 0.
- `margin_kotor = penjualan_bersih − hpp_total − fee_komisi`.
- Waktu WIB: S3 `paid_at` UTC +7 (Calculator ADD_HOURS), S2 `trx_date` Date mask `dd/MM/yyyy`, S1 langsung.
- Kota via `ref_kota.csv` (`UPPER(alias)` Stream Lookup). Pelanggan HP → digit saja
  (SUBSTITUTE +/spasi/-/.), `0…→62…`, tanpa kode → tambah `62` (Q2).
- Promo: `UPPER(TRIM(kode))`, dedup persis, `sepuluh→err_promo_S5`; UNION S1 vouchers + S5.
- Lookup gagal → default sk=1 (UNKNOWN/NO_PROMO/WEB, dibuat pertama di 0_init).

## Per sumber → target
| Sumber | Kolom sumber | Transform | Target |
|---|---|---|---|
| S1 orders/order_items | order_id, line_no | langsung | fact.no_transaksi, line_no (sumber='S1', kanal='WEB') |
| S1 order_items | unit_price (incl) | /1.11 | fact.harga_ex_ppn |
| S1 | disc_amount | langsung | fact.disc_amount |
| S1 orders | order_ts | DATE() | fact.id_tanggal |
| S1 | status (DIBATALKAN dibuang) | langsung + payment_method | fact.status_transaksi, payment_info |
| S1 customers+addresses | is_primary=1 → nama/hp/kota | HP→62, kota→ref_kota | dim_pelanggan (tipe='ECOM') |
| S1 vouchers | promo_code, discount_* | norm kode, UNION S5 | dim_promo (sumber='S1') |
| S2 header/line | trx_no, line_seq | Merge Join trx_no | fact.no_transaksi/line_no (sumber='S2', kanal='TOKO_FISIK') |
| S2 line | unit_price_excl | tetap | fact.harga_ex_ppn |
| S2 line | disc_pct | →Rp | fact.disc_amount |
| S2 header | trx_date DD/MM/YYYY | Date mask | fact.id_tanggal |
| S2 header | status VOID (6/121 di TS01) | BUANG | — |
| S2 payment | method/amount (868 trx multi-baris) | GroupBy concat `,` + sum, Merge Join | fact.payment_info |
| S2 member/store | member_no/hp/kota; store_* | HP→62; kota→ref_kota | dim_pelanggan('MEMBER'), dim_toko_kanal |
| S3 JSON 16 file | invoice, items[] | DUA JsonInput: #1 record+items_json, #2 pecah $[*] (parent terbawa) | fact (sumber='S3', kanal='MARKETPLACE') |
| S3 | paid_at UTC | +7 jam | fact.id_tanggal |
| S3 | fees per invoice | alokasi proporsional (GroupBy+Merge Join) | fact.fee_komisi |
| S3 | (invoice,seller_sku) 34 duplikat (~1.9%) | sort diambil_pada DESC + GroupBy keep-first | dedup keep-terakhir |
| S3 buyer | hash/city | Insert/Update, tanpa match | dim_pelanggan('MPL_ANON') |
| S3 | tanpa line_no di JSON | Add Sequence global | fact.line_no |
| S4 produk_master | 79 baris/60 material + berlaku_sejak | SCD1 dim + stg semua versi | dim_produk + fact.hpp_total |
| S4 supplier | supplier_* | langsung | dim_produk.supplier |
| S5 kampanye | kode/nama/jenis/kanal/target | upper/trim/dedup; `sepuluh`→err | dim_promo('S5') / err_promo_S5 |
| ref_kota | alias→kota_baku | UPPER join | dim kota_baku |

Stok harian (`stok_harian_feb2023.csv`, 10/42 toko): TIDAK dimodelkan (batasan A.4).
