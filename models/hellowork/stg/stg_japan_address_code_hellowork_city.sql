{# japan_address_code.main.hellowork_city を読む。Queria の公開データセットの表をこのデータセットの raw とみなし、使う列だけを選ぶ #}

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
from japan_address_code.main.hellowork_city
