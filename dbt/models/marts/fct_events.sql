{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='event_id'
) }}

select * from {{ ref('stg_gh_events') }}
{% if is_incremental() %}
where ingested_at > (select max(ingested_at) from {{ this }})
{% endif %}
