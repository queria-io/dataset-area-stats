{# address_br.main.mart_city を読む。Queria の公開データセットの表をこのデータセットの raw とみなし、使う列だけを選ぶ #}

select
    lg_code,
    pref_name,
    county_name,
    city_name,
    ward_name
from address_br.main.mart_city
