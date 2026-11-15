{# address_br.main.mart_town を読む。Queria の公開データセットの表をこのデータセットの raw とみなし、使う列だけを選ぶ #}

select
    lg_code,
    machiaza_id,
    oaza_cho,
    status_flg
from address_br.main.mart_town
