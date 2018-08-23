{% from "aws/map.jinja" import aws_data with context %}

# Loop through regions
{%- for region_name, region_data in aws_data.get('region', {}).items() %}
  {%- set profile = region_data.get('profile') %}

# Create Key pairs
  {%- for key_name, key_value in region_data.get('key_pairs', {} ).items() %}
aws_region_{{ region_name }}_default_keypair_{{ key_name }}:
  boto_ec2.key_present:
    - name: {{ key_name }}
    - upload_public: '{{ key_value }}'
    - profile: {{ profile }}
  {%- endfor %}

{% endfor %}
