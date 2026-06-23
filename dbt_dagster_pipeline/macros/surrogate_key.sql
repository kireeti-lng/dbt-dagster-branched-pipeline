{#
  Local surrogate-key helper (BigQuery / GoogleSQL).
  Coalesces each field to a sentinel string, concatenates with a separator, and
  hashes with MD5. BigQuery MD5() returns BYTES, so we TO_HEX() it to a stable
  hex string. Kept local so the prototype needs no package install; swap for
  dbt_utils.generate_surrogate_key in production (it produces the same result).
#}
{% macro surrogate_key(field_list) -%}
    to_hex(md5(
        {%- for field in field_list %}
        coalesce(cast({{ field }} as string), '_null_')
        {%- if not loop.last %} || '-' || {% endif %}
        {%- endfor %}
    ))
{%- endmacro %}
