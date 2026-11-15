{# e_stat.boundary.small_area を読む。Queria の公開データセットの表をこのデータセットの raw とみなし、使う列だけを選ぶ #}

select
    key_code,
    prefecture_code,
    city_code,
    area_name,
    geometry
from e_stat.boundary.small_area
