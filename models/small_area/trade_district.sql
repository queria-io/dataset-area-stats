{# 不動産取引価格（reinfolib.main.mart_trade_prices）の地区と国勢調査の小地域の対応。
   取引は位置を地区名（大字・町）までしか持たない。地区名をアドレス・ベース・レジストリの
   大字・町の名前に当て、その町字を japan_address_code の対応表で小地域へつなぐ。
   取引には (municipality_code, district_name) で結合する #}

with district as (
    select distinct
        municipality_code,
        lpad(municipality_code, 5, '0') as city_code,
        district_name,
        {{ normalize_town_name("district_name") }} as name
    from reinfolib.main.mart_trade_prices
    where coalesce(district_name, '') not in ('', '（大字なし）')
),

-- 大字・町。同じ市区町村に同じ名前の大字・町が複数あるときは oaza_count に数を出す
oaza as (
    select
        left(lg_code, 5) as city_code,
        lg_code,
        machiaza_id,
        {{ normalize_town_name("oaza_cho") }} as name,
        left(machiaza_id, 4) as oaza_id
    from address_br.main.mart_town
    where oaza_cho is not null
      and status_flg <> '3'
),

matched as (
    select d.municipality_code, d.district_name, o.lg_code, o.oaza_id, o.machiaza_id
    from district d
    join oaza o on o.city_code = d.city_code and o.name = d.name
    -- そろえると空になる地区名（「一丁目」だけなど）は当てない
    where d.name <> ''
),

oaza_count as (
    select municipality_code, district_name, count(distinct oaza_id) as oaza_count
    from matched
    group by all
),

small_area as (
    select distinct m.municipality_code, m.district_name, m.lg_code, s.key_code
    from matched m
    join japan_address_code.main.town_small_area s using (lg_code, machiaza_id)
    where s.key_code is not null
)

select
    d.municipality_code,
    d.district_name,
    s.lg_code,
    s.key_code,
    left(s.key_code, 9) as town_code,
    coalesce(c.oaza_count, 0) as oaza_count
from district d
left join small_area s using (municipality_code, district_name)
left join oaza_count c using (municipality_code, district_name)
order by d.municipality_code, d.district_name, s.key_code
