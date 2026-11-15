{# mhlw.hellowork.jurisdiction_area を読む。Queria の公開データセットの表をこのデータセットの raw とみなし、使う列だけを選ぶ #}

select
    prefecture_code,
    prefecture_name,
    office_name,
    office_kind,
    item_order,
    area_text
from mhlw.hellowork.jurisdiction_area
