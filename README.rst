
=====
aws-formula
=====

Configures the non-server parts of an AWS datacenter without using CloudFormation.  Can configure one or more VPCs in the same or different regions

.. note::

    See the full `Salt Formulas installation and usage instructions
    <http://docs.saltstack.com/en/latest/topics/development/conventions/formulas.html>`_.

Available states
=======================

.. contents::
    :local:

``vpc``
---------

Create VPC objects, including:

- VPC
- Internet Gateway
- NAT Gateway
- Subnets
- Routing Tables

``ec2``
----------------

Create ec2 components including:

- Keys

``secgroups``
----------------

Create Security Groups

Limitations and Workarounds
==================================

The salt boto states used in this formula have some limitations that do not allow for the full creation of a VPC datacenter.   The current issues are:

- NAT Gateways can not be added to a routing table by name

**NAT Gateway Workaround**

The workaround for the nat gateway is to do an initial salt state run to create the gateways, then add the NAT Gateway's interface_id to the routing tables in the pillar and re-run the state.  In the sample pillar the default Gateways are commented out to indicate where the NAT Gateway interface_id should go.


Configuration
=================

All configuration is done through the AWS pillar. The below examples and the sample pillar uses single quotes in many places to ensure data is interepreted correctly.  Not using quotes per the examples is done at your own risk.

The pillar hierarchy is:

.. code-block:: yaml
aws:
  region:
    us-east-2:
      keys:
      profile:
      vpc:
        myvpc:
          vpc:
          internet_gateway:
          subnets:
          routing_tables:
          security_groups:

Section Descriptions and Examples
-----------------------------------

.. contents::
    :local:

``keys``
---------
Keys are included under at the region level since they are not generally VPC specific.  Key format is a key pair with the name and RSA key.

.. code-block:: yaml
  keys:
    mykey: 'ssh-rsa XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX admin@mycompany.com'

``profile``
------------
This formula uses an AWS profile for all states instead of the individual fields. The key and keyid should be gpg encrypted using the [salt gpg renderer](https://docs.saltstack.com/en/latest/ref/renderers/all/salt.renderers.gpg.html).  Example below shows it in unencrypted format.

.. code-block:: yaml
  profile:
    region: us-east-2
    keyid: ASDFASDFASDFASDFASDF
    key: AB12Cd3Efg45hIjk67lMNop8q9RST0uvwXyz


``vpc``
------------
VPC contains vpcs for a given region. Each vpc will have data for all VPC specific states, even if they are not in the vpc.sls.  The vpc pillar name is the name that will be used for the VPC in AWS.  The only data directly under the vpc name is the CIDR block for the VPC

.. code-block:: yaml
  vpc:
    myvpc:
      cidr_prefix: '10.10'

``vpc:vpc``
------------
the VPC subsection contains the data needed to create the VPC.  The names on the left are the configuration item names from the boto_vpc.present states. The vpc pillar name should always match the name in the vpc section beneath.  The cidr_block should start with the same two octets as the cidr_prefix above.

.. code-block:: yaml
  vpc:
    myvpc:
      vpc:
        name: myvpc
        cidr_block: 10.10.0.0/16
        instance_tennancy: default
        dns_support: 'true'
        dns_hostnames: 'true'

``vpc:internet_gateway``
-----------------------------
An internet gateway is needed for most use cases.

.. code-block:: yaml
  vpc:
    myvpc:
      internet_gateway:
        name: internet_gateway


``vpc:subnets``
------------------
Subnets are named by their subnet ID ( assumes we are using class C subnets). The subnet ID will be appended to the cidr_prefix above to create the CIDR or the subnet. Every subnet has to at least have a subnet name and availability zone.  if nat_gateway is specified, then a NAT Gateway will be created in that subnet.  Subnet associations are done in the Routing Table section below.

.. code-block:: yaml
  vpc:
    myvpc:
      subnets:
        1:
          name: subWebA
          az: a
          nat_gateway: true
        11:
          name: appwebA
          az: a

The above example would create two subnets:

- subWebA with CIDR 10.10.1.0/24
- subAppA with CIDR 10.10.1.0/24

Both are in Availability Zone A and a NAT Gateway would be created in subWebA.

``vpc:routing_tables``
------------------------------
Routing tables will create the tables, add routes, and assign subnets to routing tables.  The below example include the interface_id of a already created NAT Gateway.

.. code-block:: yaml
  vpc:
    myvpc:
      routig_tables:
        publicA:
          routes:
            default:
              destination_cidr_block: 0.0.0.0/0
              internet_gateway_name: internet_gateway
          subnet_names:
            - subWebA
        privateA:
          routes:
            default:
              destination_cidr_block: 0.0.0.0/0
              interface_id: eni-5d6b5e34
          subnet_names:
            - subAppA


``vpc:security_groups``
---------------------------
Create security groups and rules.  Usage notes:

- If a single port is being specified, the `from_port` and `to port` can be replace with just `port`.
- source_group_name and cidr_ip can be either a single item or a list.
- Use `port: -1` to specify all ports
- A rules pillar name is for information purposes only and is not used in the actual rule creation.s

.. code-block:: yaml
  vpc:
    myvpc:
      security_groups:
        sgApp-myvpc:
          description: SG for all App servers
          rules:
            http:
              ip_protocol: tcp
              port: 80
              source_group_name:
                - sgWeb-myvpc
                - sgApp-myvpc
          rules_egress:
            all:
              ip_protocol: all
              port: -1
              cidr_ip: '0.0.0.0/0'
        sgSalt-myvpc:
          description: SG for all Salt servers
          rules:
            salt-master:
              ip_protocol: tcp
              from_port: 4505
              to_port: 4506
              cidr_ip: '10.10.0.0/16'
            salt-api:
              ip_protocol: tcp
              port: 443
              cidr_ip:
                - '10.10.0.0/16'
                - '10.20.0.0/16'
