{# 町丁目ごとの地価の目安。1 行が国勢調査の小地域 (e_stat.boundary.small_area) 1 つ × 1 年。
   地価公示・地価調査の地点も土地の取引も町丁目の数よりずっと少ないので、値は「町」
   (key_code の先頭 9 桁。丁目をまとめた単位) で集計し、同じ町の丁目には同じ値を入れる。
   公示・調査の地点は位置で町に入れ、取引は地区（大字・町）の町すべてに入れる (trade_district) #}

-- 公開中の e_stat を HTTPS で読むので、2 か所から使う境界は 1 回だけ読む
with small_area as materialized (
    select
        key_code,
        prefecture_code,
        prefecture_code || city_code as city_code,
        left(key_code, 9) as town_code,
        area_name,
        geometry
    from e_stat.boundary.small_area
    -- 町丁・字等は 9 桁、その内訳は 11 桁。2 桁 (都道府県コードだけ) の行は名前の無い水面などで、
    -- 先頭 9 桁が町にならず、別の市区町村の形が 1 つの「町」にまとまってしまう
    where length(key_code) in (9, 11)
),

-- 地価公示・地価調査。mart_land_prices も HTTPS で読み 3 か所から使うので、使う列を 1 回だけ読む
land_price_row as materialized (
    select longitude, latitude, year, current_price, change_rate, use_category
    from reinfolib.main.mart_land_prices
),

-- 地点を位置で町丁目に入れる。同じ地点が年ごとに並ぶので、位置だけ先に解く
point_location as (
    select distinct longitude, latitude
    from land_price_row
    where longitude is not null and latitude is not null
),

point_town as (
    select p.longitude, p.latitude, min(s.town_code) as town_code
    from point_location p
    join small_area s on st_contains(s.geometry, st_point(p.longitude, p.latitude))
    group by p.longitude, p.latitude
),

land as (
    select
        pt.town_code,
        l.year,
        count(*) as land_point_count,
        median(l.current_price) as land_price_median,
        median(l.change_rate) as land_change_rate_median,
        -- 商業地と住宅地は同じ町でも値段の桁が違うので、混ぜた値とは別に用途ごとに持つ
        count(*) filter (where l.use_category = '住宅地') as residential_point_count,
        median(l.current_price) filter (where l.use_category = '住宅地') as residential_price_median,
        count(*) filter (where l.use_category = '商業地') as commercial_point_count,
        median(l.current_price) filter (where l.use_category = '商業地') as commercial_price_median
    from land_price_row l
    join point_town pt using (longitude, latitude)
    where l.current_price > 0
    group by pt.town_code, l.year
),

-- 土地の取引: ㎡単価を持つのは「宅地(土地)」だけ。建物込みの取引は土地の値段にならないので使わない。
-- 取引は位置を地区（大字・町）までしか持たないので、地区の町すべてに入れる（trade_district）
trade as (
    select municipality_code, district_name, year, unit_price
    from reinfolib.main.mart_trade_prices
    where property_type = '宅地(土地)'
      and unit_price > 0
),

district_town as (
    select distinct municipality_code, district_name, town_code
    from {{ ref('trade_district') }}
    -- 同じ名前の大字・町が市区町村に複数あるときは、どちらの取引か決められないので使わない
    where town_code is not null and oaza_count = 1
),

years as (
    select distinct year from land_price_row
    union
    select distinct year from trade
),

-- 1 年分では件数が足りない町が多いので、その年までの 3 年分の取引をまとめる
trade_by_town as (
    select
        dt.town_code,
        y.year,
        count(*) as trade_count,
        median(tr.unit_price) as trade_unit_price_median
    from trade tr
    join district_town dt using (municipality_code, district_name)
    join years y on tr.year between y.year - 2 and y.year
    group by dt.town_code, y.year
),

town_year as (
    select
        coalesce(l.town_code, t.town_code) as town_code,
        coalesce(l.year, t.year) as year,
        coalesce(l.land_point_count, 0) as land_point_count,
        l.land_price_median,
        l.land_change_rate_median,
        coalesce(l.residential_point_count, 0) as residential_point_count,
        l.residential_price_median,
        coalesce(l.commercial_point_count, 0) as commercial_point_count,
        l.commercial_price_median,
        coalesce(t.trade_count, 0) as trade_count,
        t.trade_unit_price_median
    from land l
    full join trade_by_town t on t.town_code = l.town_code and t.year = l.year
)

select
    s.key_code,
    s.prefecture_code,
    s.city_code,
    s.town_code,
    s.area_name,
    ty.year,
    ty.land_point_count,
    cast(round(ty.land_price_median) as bigint) as land_price_median,
    round(ty.land_change_rate_median, 1) as land_change_rate_median,
    ty.residential_point_count,
    cast(round(ty.residential_price_median) as bigint) as residential_price_median,
    ty.commercial_point_count,
    cast(round(ty.commercial_price_median) as bigint) as commercial_price_median,
    ty.trade_count,
    cast(round(ty.trade_unit_price_median) as bigint) as trade_unit_price_median
from town_year ty
join small_area s using (town_code)
order by s.key_code, ty.year
