# Create list of route table options that need the value to have a -vpcname suffix
{% set rt_append_list = [ 'internet_gateway_name', 'nat_gateway_subnet_name'] %}

{% from "aws/map.jinja" import aws_data with context %}

# Loop through regions
{%- for region_name, region_data in aws_data.get('region', {}).items() %}
  {%- set profile = region_data.get('profile')  %}

# Loop through VPCs
  {%- for vpc_name, vpc_data in region_data.get('vpc').items() %}

# Create VPC
aws_vpc_{{ vpc_name }}_create:
  boto_vpc.present:
    {%- for option, value in vpc_data.get('vpc', {}).items() %}
    - {{ option }}: '{{ value }}'
    {%- endfor %}
    - profile: {{ profile }}

# Create Internet Gateway
aws_vpc_{{ vpc_name }}_create_internet_gateway:
  boto_vpc.internet_gateway_present:
    - name: {{ vpc_data.get('internet_gateway:name', 'internet_gateway') }}-{{ vpc_name }}
    - vpc_name: {{ vpc_name }}
    - profile: {{ profile }}

# Create Subnets. Optionally NAT Gateways
    {%- for subnet_number, subnet_data in vpc_data.get('subnets', {}).items() %}
aws_vpc_{{ vpc_name }}_create_subnet_{{ subnet_data.name }}:
  boto_vpc.subnet_present:
    - name: {{ subnet_data.name }}-{{ vpc_name }}
    - vpc_name: {{ vpc_name }}
    - cidr_block: {{ vpc_data.cidr_prefix }}.{{ subnet_number }}.0/24
    - availability_zone: {{ region_name }}{{ subnet_data.az }}
    - profile: {{ profile }}

      {%- if subnet_data.get('nat_gateway', False ) %}
aws_vpc_{{ vpc_name }}_create_nat_gateway_{{ subnet_data.name }}:
  boto_vpc.nat_gateway_present:
    - subnet_name: {{ subnet_data.name }}-{{ vpc_name }}
    - profile: {{ profile }}
      {%- endif %}
    {% endfor %}

# Create Routing Tables.  Optionally create
# - routes
# - Global routes ( must be routes in order for global routes will be created )
# - subnet associations

    {%- for table_name, table_data in vpc_data.get('routing_tables', {}).items() %}
aws_vpc_{{ vpc_name }}_create_routing_table_{{ table_name }}:
  boto_vpc.route_table_present:
    - name: {{ table_name }}-{{ vpc_name }}
    - vpc_name: {{ vpc_name }}
    - profile: {{ profile }}
      {%- if table_data.get('routes', false ) %}
    - routes:
        {%- for route_name, route_data in table_data.get('routes').items() %}
          {%- for option, value in route_data.items() %}
          {% if option in rt_append_list %}
            {% set value = '{0}-{1}'.format( value, vpc_name ) %}
          {% endif %}
            {%- if loop.first %}
      - {{ option }}: '{{ value }}'
            {%- else %}
        {{ option }}: '{{ value }}'
            {%- endif %}
          {%- endfor %}
        {%- endfor %}
        {%- for route_name, route_data in vpc_data.get('routing_global_routes',{}).items() %}
          {%- for option, value in route_data.items() %}
          {% if option in rt_append_list %}
            {% set value = '{0}-{1}'.format( value, vpc_name ) %}
          {% endif %}
            {%- if loop.first %}
      - {{ option }}: '{{ value }}'
            {%- else %}
        {{ option }}: '{{ value }}'
            {%- endif %}
          {%- endfor %}
        {%- endfor %}
      {%- endif %}

      {%- if table_data.get('subnet_names', false ) %}
    - subnet_names:
        {%- for subnet_name in table_data.subnet_names %}
      - {{ subnet_name }}-{{ vpc_name }}
        {%- endfor %}
      {%- endif %}
    {% endfor %}
  {% endfor %}
{% endfor %}
