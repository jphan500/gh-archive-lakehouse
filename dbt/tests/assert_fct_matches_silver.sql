select 1
from (
    select
        (select count(*) from {{ source('silver', 'silver_events') }}) as silver_rows,
        (select count(*) from {{ ref('fct_events') }}) as fct_rows
)
where silver_rows != fct_rows
