{{ config(alias='municipality') }}

{# japan_address_code.main.hellowork_city に移した。移す前の名前で読む SQL のため、しばらく同じ行を出す #}

select
    lg_code,
    city_code,
    prefecture_code,
    prefecture_name,
    county_name,
    city_name,
    ward_name,
    office_name,
    office_kind,
    coverage,
    item_order,
    area_text
from {{ ref('stg_japan_address_code_hellowork_city') }}
