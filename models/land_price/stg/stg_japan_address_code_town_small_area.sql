{# japan_address_code.main.town_small_area を読む。Queria の公開データセットの表をこのデータセットの raw とみなし、使う列だけを選ぶ #}

select
    lg_code,
    machiaza_id,
    key_code
from japan_address_code.main.town_small_area
