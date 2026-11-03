# dataset-area-stats

町丁目・メッシュ・市区町村などの地域ごとの指標を Queria のカタログ（[data.queria.io](https://data.queria.io/)）へ載せるデータセットです。

## 置くもの

ほかの Queria のデータセットを読んで、地域コードごとの値にしたものを置きます。

- 地点の値を地域にまとめたもの（地価公示の地点を町丁目ごとに、など）
- 名前で地域コードに当て直したもの（取引の地区名を町丁目に、など）
- いくつかのデータセットを合わせたもの

元のデータセットがすでに地域コードで持っている値（国勢調査の小地域の人口など）は写しません。元のデータセットを読んでください。

スキーマは地域の単位、表はテーマごとに 1 つです。

## データ出典

Queria の公開データセット reinfolib・e_stat を読んで作ります。取得はしません。

| 原典 | 使う表 |
| --- | --- |
| [不動産情報ライブラリ](https://www.reinfolib.mlit.go.jp/)（国土交通省） | `reinfolib.main.mart_land_prices`、`reinfolib.main.mart_trade_prices` |
| [国勢調査 町丁・字等別境界データ](https://www.e-stat.go.jp/gis)（総務省統計局、令和2年） | `e_stat.boundary.small_area` |

## 収録テーブル

### small_area.land_price

町丁目ごとの地価の目安。1行が国勢調査の小地域（`e_stat.boundary.small_area`）1つ × 1年です。

- 地価公示・地価調査の地点の価格と、土地だけの取引（宅地(土地)）の㎡単価を、町（key_code の先頭9桁。丁目をまとめた単位）ごとにまとめ、同じ町の丁目には同じ値を入れます
- 地点は位置で町に入れ、取引は地区名を町の名前に突き合わせます。地区名で始まる町や同じ名前の町が複数あるときは、その町すべてに入れます
- 取引の値はその年までの3年分です
- 地点も取引も無い町丁目の行はありません。件数が少ない町の値は目安にならないので、件数と一緒に見てください

主なカラム:

- key_code: 小地域コード（e_stat の境界・国勢調査の表と同じ）
- town_code: 町コード（key_code の先頭9桁）
- year: 年
- land_point_count / land_price_median / land_change_rate_median: 地点数 / 価格の中央値（円/㎡） / 対前年変動率の中央値（%）
- residential_price_median / commercial_price_median: 住宅地 / 商業地の価格の中央値（円/㎡）
- trade_count / trade_unit_price_median: その年までの3年分の土地の取引件数 / ㎡単価の中央値

```sql
-- 2025 年の新宿区の町丁目ごとの住宅地の地価
SELECT key_code, area_name, residential_price_median, residential_point_count
FROM area_stats.small_area.land_price
WHERE city_code = '13104' AND year = 2025
ORDER BY key_code
```

## ビルド

毎月 3 日に `Sync` のワークフローが作り直して公開します。手元で流すときは次のとおりです。

```bash
uv sync
FDL_TOKEN=... scripts/build.sh
```

## ライセンス

元データの利用規約に従います。不動産情報ライブラリは「このサービスは、国土交通省の不動産情報ライブラリのAPI機能を使用していますが、提供情報の最新性、正確性、完全性等が保証されたものではありません。」
