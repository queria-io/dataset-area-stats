{{ config(alias='trade_district') }}

{# japan_address_code.main.trade_district_small_area に移した。移す前の名前で読む SQL のため、しばらく同じ行を出す #}

select municipality_code, district_name, lg_code, key_code, town_code, oaza_count
from japan_address_code.main.trade_district_small_area
