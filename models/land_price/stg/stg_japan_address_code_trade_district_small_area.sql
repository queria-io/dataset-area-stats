{# japan_address_code.main.trade_district_small_area を読む。Queria の公開データセットの表をこのデータセットの raw とみなし、使う列だけを選ぶ #}

select
    municipality_code,
    district_name,
    lg_code,
    key_code,
    town_code,
    oaza_count
from japan_address_code.main.trade_district_small_area
