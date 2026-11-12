{{ config(alias='municipality') }}

{# 公共職業安定所（ハローワーク）の管轄区域（mhlw.hellowork.jurisdiction_area）を、
   アドレス・ベース・レジストリの市区町村の名前に当てて、市区町村コードを付ける。
   1 行が市区町村と安定所の 1 組。

   管轄一覧表の項目の書き方と当て方:
   - 「水戸市」「愛知郡東郷町」「北九州市門司区」: 市区町村の名前。そのまま当てる
   - 「猿島郡」「横浜市」: 郡の町村すべて、政令指定都市の区すべて
   - 「松前郡（松前町、福島町）」: 括弧の中の町村
   - 「稲敷郡のうち阿見町」「横浜市のうち鶴見区」: 郡の町村、政令指定都市の区。
     後ろに続く「美浦村」「西区」のような項目も同じ郡の町村、同じ市の区
   - 「長岡市のうち川口相川」「青森市（…を除く。）」「度会郡のうち大紀町錦」: 市区町村の一部（coverage = 'partial'）
   - 市区町村の「のうち」の後ろに続く項目は、その市区町村の町・字（大字・町）なので当てない。
     ただし、その市区町村の町・字に同じ名前が無く、市区町村の名前と一致すれば市区町村として当てる
     （「入間市のうち仏子・野田・新光，日高市」の「日高市」）
   どれにも当たらない項目（合併・改称の前の名前、廃止された郡、案内の文など）は行にならない #}

with city as (
    select
        lg_code,
        pref_name,
        county_name,
        city_name,
        ward_name,
        translate(city_name, 'ヶヵ', 'ケカ') as city_key,
        translate(coalesce(ward_name, ''), 'ヶヵ', 'ケカ') as ward_key,
        translate(coalesce(county_name, ''), 'ヶヵ', 'ケカ') as county_key,
        bool_or(ward_name is not null) over (partition by pref_name, city_name) as in_designated_city
    from address_br.main.mart_city
    where lg_code is not null
),

-- 名前から市区町村コードを引く表。kind が county・designated_city の名前は複数の市区町村に当たる
names as (
    select pref_name, city_key as name, lg_code, 'municipality' as kind, null as designated_city
    from city where not in_designated_city
    union all
    select pref_name, county_key || city_key, lg_code, 'municipality', null
    from city where county_key <> ''
    union all
    select pref_name, city_key || ward_key, lg_code, 'ward', city_key
    from city where ward_name is not null
    union all
    select pref_name, county_key, lg_code, 'county', null
    from city where county_key <> ''
    union all
    select pref_name, city_key, lg_code, 'designated_city', city_key
    from city where ward_name is not null
),

name_kind as (
    select
        pref_name,
        name,
        any_value(kind) as kind,
        count(distinct lg_code) as lg_count,
        any_value(designated_city) as designated_city
    from names
    group by all
),

single as (
    select * from names where kind in ('municipality', 'ward')
),

-- 市区町村の町・字（大字・町）の名前。「Xのうち」の後ろの項目が町・字かどうかを見る
town as (
    select distinct lg_code, translate(oaza_cho, 'ヶヵ', 'ケカ') as name
    from address_br.main.mart_town
    where oaza_cho is not null
),

-- 読点の抜けで「幸区 横浜市のうち鶴見区」のように空白で並ぶ項目があるので、空白でも区切る
items as (
    select
        j.prefecture_code,
        j.prefecture_name,
        j.office_name,
        j.office_kind,
        j.item_order,
        j.area_text,
        j.item_order * 100 + u.sub_order as seq,
        u.parts[u.sub_order] as t
    from mhlw.hellowork.jurisdiction_area j,
        (
            select
                string_split(translate(j.area_text, 'ヶヵ（）《》〈〉，、', 'ケカ()()(),,'), ' ') as parts,
                unnest(generate_series(1, len(string_split(j.area_text, ' ')))) as sub_order
        ) as u
    where u.parts[u.sub_order] <> ''
),

parsed as (
    select
        *,
        nullif(regexp_extract(t, '^(.+?(?:市|区|町|村|郡))(?:のうち|\(|$)', 1), '') as head,
        regexp_replace(t, '\(.*$', '') as bare,
        contains(t, 'のうち') as has_part,
        nullif(regexp_extract(t, 'のうち(.+)$', 1), '') as part_text,
        nullif(regexp_extract(t, '\(([^)]*)', 1), '') as inner_text
    from items
),

-- 前の「Xのうち」が指す政令指定都市。後ろの「西区」「南区のうち…」を「大阪市西区」として引く
with_city_context as (
    select
        *,
        last_value(case when has_part then n.designated_city end ignore nulls) over (
            partition by prefecture_code, office_name, office_kind
            order by seq
            rows between unbounded preceding and 1 preceding
        ) as city_context
    from parsed p
    left join name_kind n on n.pref_name = p.prefecture_name and n.name = p.head
),

resolved as (
    select
        w.* exclude (name, kind, lg_count, designated_city, pref_name),
        case
            when w.name is not null then w.head
            when n2.name is not null then w.city_context || w.head
        end as head_full
    from with_city_context w
    left join name_kind n2 on n2.pref_name = w.prefecture_name and n2.name = w.city_context || w.head
),

-- 前の「Xのうち」の X と、その種類
with_context as (
    select
        r.*,
        n.kind as head_kind,
        n.lg_count as head_lg_count,
        cn.kind as context_kind
    from (
        select
            *,
            last_value(case when has_part then head_full end ignore nulls) over (
                partition by prefecture_code, office_name, office_kind
                order by seq
                rows between unbounded preceding and 1 preceding
            ) as context_head
        from resolved
    ) r
    left join name_kind n on n.pref_name = r.prefecture_name and n.name = r.head_full
    left join name_kind cn on cn.pref_name = r.prefecture_name and cn.name = r.context_head
),

-- 「X郡のうちA町・B町」「X市のうちA区（…）」の A町・B町、A区。括弧があれば一部
parts as (
    select
        w.*,
        regexp_replace(u.part, '\(.*$', '') as part_name,
        contains(u.part, '(') as part_qualified
    from with_context w,
        unnest(string_split(w.part_text, '・')) as u(part)
    where w.has_part and w.head_kind in ('county', 'designated_city')
),

-- 郡の括弧の中の町村（「松前郡（松前町、福島町）」）
listed as (
    select w.*, u.town_name
    from with_context w,
        unnest(string_split(replace(w.inner_text, '・', ','), ',')) as u(town_name)
    where not w.has_part and w.head_kind = 'county' and not contains(w.inner_text, '除')
),

matched as (
    -- 郡・政令指定都市のうち町村・区
    select p.prefecture_code, p.office_name, p.office_kind, p.item_order, p.area_text,
        s.lg_code, case when p.part_qualified then 'partial' else 'full' end as coverage
    from parts p
    join single s on s.pref_name = p.prefecture_name and s.name = p.head_full || p.part_name

    -- 郡・政令指定都市のうち町村・区の一部（「度会郡のうち大紀町錦」）
    union all
    select p.prefecture_code, p.office_name, p.office_kind, p.item_order, p.area_text,
        s.lg_code, 'partial'
    from parts p
    join single s
        on s.pref_name = p.prefecture_name
        and s.name = p.head_full || regexp_extract(p.part_name, '^(.+?(?:市|区|町|村))', 1)
    where not exists (
        select 1 from single x where x.pref_name = p.prefecture_name and x.name = p.head_full || p.part_name
    )

    -- 市区町村のうち町・字
    union all
    select w.prefecture_code, w.office_name, w.office_kind, w.item_order, w.area_text,
        s.lg_code, 'partial'
    from with_context w
    join single s on s.pref_name = w.prefecture_name and s.name = w.head_full
    where w.has_part and w.head_lg_count = 1

    -- 郡の括弧の中の町村
    union all
    select l.prefecture_code, l.office_name, l.office_kind, l.item_order, l.area_text,
        s.lg_code, 'full'
    from listed l
    join single s on s.pref_name = l.prefecture_name and s.name = l.head_full || l.town_name

    -- 郡の括弧の中の町村の一部（「久遠郡（せたな町大成区）」）
    union all
    select l.prefecture_code, l.office_name, l.office_kind, l.item_order, l.area_text,
        s.lg_code, 'partial'
    from listed l
    join single s
        on s.pref_name = l.prefecture_name
        and s.name = l.head_full || regexp_extract(l.town_name, '^(.+?(?:市|区|町|村))', 1)
    where not exists (
        select 1 from single x where x.pref_name = l.prefecture_name and x.name = l.head_full || l.town_name
    )

    -- 名前だけの項目と、括弧で一部を除く項目
    union all
    select w.prefecture_code, w.office_name, w.office_kind, w.item_order, w.area_text,
        n.lg_code, case when w.inner_text is null then 'full' else 'partial' end
    from with_context w
    join names n on n.pref_name = w.prefecture_name and n.name = w.head_full and n.kind = w.head_kind
    where not w.has_part
        and w.bare = w.head
        and (w.inner_text is null or contains(w.inner_text, '除') or w.head_kind <> 'county')
        -- 同じ都道府県に同じ名前の市区町村が 2 つあるとき（北海道の泊村）は決めない
        and (w.head_kind not in ('municipality', 'ward') or w.head_lg_count = 1)
        -- 市区町村のうちの後ろは、その市区町村の町・字に同じ名前があれば町・字
        and not exists (
            select 1 from single cs join town tw on tw.lg_code = cs.lg_code
            where cs.pref_name = w.prefecture_name and cs.name = w.context_head and tw.name = w.bare
        )

    -- 市区町村の名前に町・字が続く項目（「日高郡新ひだか町静内」）。いちばん長い名前に当てる
    union all
    select w.prefecture_code, w.office_name, w.office_kind, w.item_order, w.area_text,
        arg_max(s.lg_code, length(s.name)), 'partial'
    from with_context w
    join single s on s.pref_name = w.prefecture_name and starts_with(w.t, s.name) and w.t <> s.name
    where w.head is null and w.context_head is null
    group by all

    -- 「X郡のうち」の後ろに続く町村
    union all
    select w.prefecture_code, w.office_name, w.office_kind, w.item_order, w.area_text,
        s.lg_code, case when w.inner_text is null then 'full' else 'partial' end
    from with_context w
    join single s on s.pref_name = w.prefecture_name and s.name = w.context_head || w.bare
    where not w.has_part and w.context_kind = 'county'
)

select
    m.lg_code,
    left(m.lg_code, 5) as city_code,
    m.prefecture_code,
    c.pref_name as prefecture_name,
    c.county_name,
    c.city_name,
    c.ward_name,
    m.office_name,
    m.office_kind,
    m.coverage,
    m.item_order,
    m.area_text
from matched m
join city c using (lg_code)
-- 同じ安定所の 2 つの項目が同じ市区町村に当たるときは、全域（full）の項目を残す
qualify row_number() over (
    partition by m.lg_code, m.office_name, m.office_kind
    order by m.coverage, m.item_order
) = 1
order by m.lg_code, m.office_kind, m.office_name
