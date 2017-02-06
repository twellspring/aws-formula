{%- from "aws/macros.jinja" import secgroup_rules with context %}
{% from "aws/map.jinja" import aws_data with context %}

# Loop through regions
{%- for region_name, region_data in aws_data.get('region', {}).items() %}
  {%- set profile = region_data.get('profile')  %}

# Loop through VPCs
  {%- for vpc_name, vpc_data in region_data.get('vpc').items() %}

# Create Security Groups
    {%- for sg_name, sg_data in vpc_data.get('security_groups', {}).items() %}
aws_vpc_{{ vpc_name }}_create_security_group_{{ sg_name }}:
  boto_secgroup.present:
    - name: {{ sg_name }}-{{ vpc_name }}
    - description: {{ sg_data.description }}
    - vpc_name: {{ vpc_name }}
    - profile: {{ profile }}
    {{ secgroup_rules('rules', sg_data.get('rules', {}), vpc_name ) }}
    {{ secgroup_rules('rules_egress',  sg_data.get('rules_egress',  {}), vpc_name ) }}
    {% endfor %}

  {% endfor %}
{% endfor %}
