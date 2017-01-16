{%- for region_name, region_data in salt['pillar.get']('aws:region', {}).items() %}
  {%- set profile = region_data.get('profile') %}
  
# SSH Keys
  {%- for key_name, key_value in region_data.get('keys', {} ).items() %}
aws_region_{{ region_name }}_default_keypair_{{ key_name }}:
  boto_ec2.key_present:
    - name: {{ key_name }}
    - upload_public: '{{ key_value }}'
    - profile: {{ profile }}
  {%- endfor %}

{% endfor %}
