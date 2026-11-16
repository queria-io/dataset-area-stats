{# reinfolib.main.mart_trade_prices を読む。Queria の公開データセットの表をこのデータセットの raw とみなし、使う列だけを選ぶ #}

select
    municipality_code,
    district_name,
    year,
    unit_price,
    property_type
from reinfolib.main.mart_trade_prices
