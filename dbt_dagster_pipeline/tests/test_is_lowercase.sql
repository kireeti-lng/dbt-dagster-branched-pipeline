{% test is_lowercase(model, column_name) %}

with validation as (
    select
        {{ column_name }} as text_field
    from {{ model }}
),

validation_errors as (
    select
        text_field
    from validation
    -- If string changes under UPPERCASE transformations, it is not purely lowercase
    where text_field != lower(text_field)
)

select *
from validation_errors

{% endtest %}
