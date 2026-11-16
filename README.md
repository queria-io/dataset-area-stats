# 地域ごとの指標

町丁目・メッシュ・市区町村などの地域ごとの指標を、SQL で集計できるテーブルにしたデータセットです。ほかの Queria のデータセットを読んで、地域コードごとの値にしたものを収録しています。

- 地点の値を地域にまとめたもの（地価公示の地点を町丁目ごとに、など）
- いくつかのデータセットを合わせたもの

元のデータセットがすでに地域コードで持っている値（国勢調査の小地域の人口など）は収録しません。元のデータセットを読んでください。名前や地区を地域コードに当てる対応表は japan_address_code（住所コード対応表）にあります。スキーマはテーマ（地価なら `land_price`）、テーブルは地域の単位（町丁目なら `small_area`）です。

## 出典と利用条件

Queria の公開データセット reinfolib・e_stat・japan_address_code を読んで作ります。

| 原典 | 使うテーブル |
| --- | --- |
| [不動産情報ライブラリ](https://www.reinfolib.mlit.go.jp/)（国土交通省） | `reinfolib.main.mart_land_prices`、`reinfolib.main.mart_trade_prices` |
| [国勢調査 町丁・字等別境界データ](https://www.e-stat.go.jp/gis)（総務省統計局、令和2年） | `e_stat.boundary.small_area` |
| [アドレス・ベース・レジストリ](https://dataset.address-br.digital.go.jp/)（デジタル庁） | `japan_address_code.main.trade_district_small_area`、`japan_address_code.main.hellowork_city` |
| [都道府県労働局（労働基準監督署、公共職業安定所）所在地一覧](https://www.mhlw.go.jp/kouseiroudoushou/shozaiannai/roudoukyoku/index.html)（厚生労働省） | `japan_address_code.main.hellowork_city` |

- 元データの利用規約に従います
- 不動産情報ライブラリ: 「このサービスは、国土交通省の不動産情報ライブラリのAPI機能を使用していますが、提供情報の最新性、正確性、完全性等が保証されたものではありません。」

## テーブル

| テーブル | 内容 |
| --- | --- |
| `land_price.small_area` | 町丁目ごとの地価の目安。1 行が国勢調査の小地域 1 つの 1 年 |
| `land_price.trade_district` | japan_address_code の `main.trade_district_small_area` に移しました。2026 年 12 月末に削除します |
| `hellowork.municipality` | japan_address_code の `main.hellowork_city` に移しました。2026 年 12 月末に削除します |

## 使い方

2025 年の新宿区の町丁目ごとの住宅地の地価:

```sql
SELECT key_code, area_name, residential_price_median, residential_point_count
FROM area_stats.land_price.small_area
WHERE city_code = '13104' AND year = 2025
ORDER BY key_code;
```

## 町丁目別の地価（land_price.small_area）の作り方

- 地価公示・地価調査の地点の価格（`reinfolib.main.mart_land_prices`）と、土地だけの取引（宅地(土地)）の㎡単価（`reinfolib.main.mart_trade_prices`）を、町（`key_code` の先頭 9 桁。丁目をまとめた単位）ごとにまとめます。同じ町の丁目には同じ値が入ります
- 地点は位置で町に入れます。取引は位置を地区（大字・町）までしか持たないため、japan_address_code の `main.trade_district_small_area` で地区を小地域に当て、地区の町すべてに同じ取引を入れます。そのため `trade_count` を町をまたいで合計すると、取引の数より多くなります
- 地区名が住所の台帳にない取引と、同じ名前の大字・町が市区町村に複数ある取引は入りません
- 取引の値はその年までの 3 年分をまとめます。取引の収録は 2005 年第 3 四半期からで、2005・2006 年と最新の年は 3 年に満たない値です
- 件数が少ない町の値は目安になりません。`land_point_count` と `trade_count` と一緒に見てください。地点も取引もない町丁目の行はありません
