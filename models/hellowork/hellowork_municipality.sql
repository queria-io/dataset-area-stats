{{ config(alias='municipality') }}

{# japan_address_code.main.hellowork_city に移した。移す前の名前で読む SQL のため、しばらく同じ行を出す #}

select * from japan_address_code.main.hellowork_city
