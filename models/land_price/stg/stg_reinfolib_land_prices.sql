{# reinfolib.main.mart_land_prices を読む。Queria の公開データセットの表をこのデータセットの raw とみなし、使う列だけを選ぶ #}

select
    longitude,
    latitude,
    year,
    current_price,
    change_rate,
    use_category
from reinfolib.main.mart_land_prices
