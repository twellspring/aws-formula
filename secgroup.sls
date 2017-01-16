{%- from "states/aws/macros.jinja" import secgroup_rules with context %}

{%- for region_name, region_data in salt['pillar.get']('aws:region', {}).items() %}
  {%- set profile = region_data.get('profile')  %}

  {%- for vpc_name, vpc_data in region_data.get('vpc').items() %}

# Security Groups
    {%- for sg_name, sg_data in vpc_data.get('security_groups', {}).items() %}
aws_vpc_{{ vpc_name }}_create_security_group_{{ sg_name }}:
  boto_secgroup.present:
    - name: {{ sg_name }}
    - description: {{ sg_data.description }}
    - vpc_name: {{ vpc_name }}
    - profile: {{ profile }}
    {{ secgroup_rules('rules', sg_data.get('rules', {}) ) }}
    {{ secgroup_rules('rules_egress',  sg_data.get('rules_egress',  {}) ) }}
    {% endfor %}

  {% endfor %}
{% endfor %}
