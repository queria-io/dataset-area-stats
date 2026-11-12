# 地域ごとの指標

町丁目・メッシュ・市区町村などの地域ごとの指標を、SQL で集計できるテーブルにしたデータセットです。ほかの Queria のデータセットを読んで、地域コードごとの値にしたものを収録しています。

- 地点の値を地域にまとめたもの（地価公示の地点を町丁目ごとに、など）
- 名前で地域コードに当て直したもの（取引の地区名を町丁目に、など）
- いくつかのデータセットを合わせたもの

元のデータセットがすでに地域コードで持っている値（国勢調査の小地域の人口など）は収録しません。元のデータセットを読んでください。スキーマはテーマ（地価なら `land_price`）、テーブルは地域の単位（町丁目なら `small_area`）です。

## 出典と利用条件

Queria の公開データセット reinfolib・e_stat・address_br・japan_address_code・mhlw を読んで作ります。

| 原典 | 使うテーブル |
| --- | --- |
| [不動産情報ライブラリ](https://www.reinfolib.mlit.go.jp/)（国土交通省） | `reinfolib.main.mart_land_prices`、`reinfolib.main.mart_trade_prices` |
| [国勢調査 町丁・字等別境界データ](https://www.e-stat.go.jp/gis)（総務省統計局、令和2年） | `e_stat.boundary.small_area` |
| [アドレス・ベース・レジストリ](https://dataset.address-br.digital.go.jp/)（デジタル庁） | `address_br.main.mart_town`、`address_br.main.mart_city`、`japan_address_code.main.town_small_area` |
| [都道府県労働局（労働基準監督署、公共職業安定所）所在地一覧](https://www.mhlw.go.jp/kouseiroudoushou/shozaiannai/roudoukyoku/index.html)（厚生労働省） | `mhlw.hellowork.jurisdiction_area` |

- 元データの利用規約に従います
- 不動産情報ライブラリ: 「このサービスは、国土交通省の不動産情報ライブラリのAPI機能を使用していますが、提供情報の最新性、正確性、完全性等が保証されたものではありません。」

## テーブル

| テーブル | 内容 |
| --- | --- |
| `land_price.small_area` | 町丁目ごとの地価の目安。1 行が国勢調査の小地域 1 つの 1 年 |
| `land_price.trade_district` | 不動産取引の地区と小地域の対応。1 行が地区と小地域の 1 組 |
| `hellowork.municipality` | 市区町村ごとの管轄ハローワーク。1 行が市区町村と公共職業安定所の 1 組 |

## 使い方

2025 年の新宿区の町丁目ごとの住宅地の地価:

```sql
SELECT key_code, area_name, residential_price_median, residential_point_count
FROM area_stats.land_price.small_area
WHERE city_code = '13104' AND year = 2025
ORDER BY key_code;
```

取引ごとに小地域コードを付ける（地区が 1 つの大字・町に決まるものだけ）:

```sql
SELECT t.*, d.key_code
FROM reinfolib.main.mart_trade_prices AS t
JOIN area_stats.land_price.trade_district AS d USING (municipality_code, district_name)
WHERE d.oaza_count = 1;
```

つくば市を受け持つハローワークと、その所在地:

```sql
SELECT m.office_name, m.office_kind, m.coverage, o.full_address, o.phone
FROM area_stats.hellowork.municipality AS m
JOIN mhlw.hellowork.office AS o USING (prefecture_code, office_name, office_kind)
WHERE m.lg_code = '082201';
```

## 町丁目別の地価（land_price.small_area）の作り方

- 地価公示・地価調査の地点の価格（`reinfolib.main.mart_land_prices`）と、土地だけの取引（宅地(土地)）の㎡単価（`reinfolib.main.mart_trade_prices`）を、町（`key_code` の先頭 9 桁。丁目をまとめた単位）ごとにまとめます。同じ町の丁目には同じ値が入ります
- 地点は位置で町に入れます。取引は位置を地区（大字・町）までしか持たないため、`land_price.trade_district` で地区を小地域に当て、地区の町すべてに同じ取引を入れます。そのため `trade_count` を町をまたいで合計すると、取引の数より多くなります
- 地区名が住所の台帳にない取引と、同じ名前の大字・町が市区町村に複数ある取引は入りません
- 取引の値はその年までの 3 年分をまとめます。取引の収録は 2005 年第 3 四半期からで、2005・2006 年と最新の年は 3 年に満たない値です
- 件数が少ない町の値は目安になりません。`land_point_count` と `trade_count` と一緒に見てください。地点も取引もない町丁目の行はありません

## 取引の地区と小地域の対応（land_price.trade_district）の作り方

- 地区名をアドレス・ベース・レジストリの大字・町の名前に当て、その町字を `japan_address_code.main.town_small_area` で小地域に結合します
- 1 つの地区は、大字・町にかかる小地域すべてと組になります。取引がその中のどこかは判定できません
- `mart_trade_prices` とは `municipality_code` と `district_name` の 2 つで結合します（どちらも `mart_trade_prices` の値のままです。北海道などは先頭の 0 が落ちた 4 桁です）
- 地区名が住所の台帳にない地区は、`key_code` が空の 1 行になります。同じ名前の大字・町が市区町村に複数あるときは、そのすべての小地域と組になり、`oaza_count` が 2 以上になります
- 名前は「ヶ」と「ケ」、先頭の「大字」「字」、末尾の丁目を正規化して比較します

## 市区町村ごとの管轄ハローワーク（hellowork.municipality）の作り方

- 厚生労働省の管轄一覧表の項目（`mhlw.hellowork.jurisdiction_area`）を、アドレス・ベース・レジストリの市区町村の名前（`address_br.main.mart_city`）と照合します
- 「水戸市」「愛知郡東郷町」のような市区町村の名前はそのまま、「猿島郡」は郡の町村すべて、「横浜市」は区すべてに当てます
- 「稲敷郡のうち阿見町」「横浜市のうち鶴見区」の後ろに続く項目は、同じ郡の町村、同じ市の区として照合します
- 「長岡市のうち川口相川」「青森市（黒石公共職業安定所の管轄区域を除く。）」のような項目は、市区町村の一部として `coverage` を `partial` にします。「のうち」の後ろに続く町・字は市区町村には当てません。その市区町村の大字・町（`address_br.main.mart_town`）に同じ名前が無く、市区町村の名前と一致する項目だけを市区町村として照合します
- 名前は「ヶ」と「ケ」を正規化して比較します。同じ都道府県に同じ名前の市区町村が 2 つあるとき（北海道の泊村）は照合しません
- 管轄一覧表に合併・改称の前の名前が残っている市区町村（篠山市、塩釜市）と、廃止された郡（東磐井郡）の項目は照合できず、行になりません

## ビルド

毎月 3 日に `Sync` のワークフローが作り直して公開します。手元で実行するときは次のとおりです。

```bash
uv sync
FDL_TOKEN=... scripts/build.sh
```
