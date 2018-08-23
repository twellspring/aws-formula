aws-formula
============

Configure the non-server parts of an AWS datacenter without using CloudFormation.  Multiple VPCs in multiple regions can be configured with one pillar.

**Requires**: Saltstack 2016.11 ( 2015.8.2 if not using NAT Gateway ) and Boto3

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

- Key pairs

``secgroups``
----------------

Create and update Security Groups rules.  Servers must be added to the Security Groups as part of the salt-cloud creation proces.

Limitations and Workarounds
==================================

The salt boto states used in this formula have some limitations that require workarounds for the formula to work.  These are:

- Many object names must be unique.
- Inter-Region VPN connections can not be added to routing table
- Security Group rule creation can fail when when referencing other groups

**Object names must be unique**

The saltstack states/modules do a check if the resource exists before creating it.  This lookup is not VPC specific, so will match on objects of the same name in different VPCs.  If only one VPC is created in a region, this is not a problem, but if multiple are created it will cause some of the required resources to not be created. The workaround is most objects will have the VPC name appended as a suffix ( example:  subAppA in the pillar will have -myVPC appended to become subAppA-myVPC )

**Inter-Region VPN**

AWS currently does not offer a service for VPC peering between regions.  This means the recommended solution is to create a VPN instance and then use an ipsec VPN tunnel between regions.  Unfortunately, when using VPN instances you can not use the **Route Propagation** functionality, so those routes have to be manually added to all routing tables for a VPC.  VPN routing is shown commented out in the pillar example.  Like above, run the states once to create all of the objects. Then when the VPN tunnel is created/active, add the IPs to the pillar and rerun the states.

**Security Group rule creation failure**

Security Group rules will sometimes include references to other Security Groups.  But the oder Groups are Created is indeterminate ( not alphabetical or pillar order ).  So sometimes a Security Group creation will fail because it is being created before the group it references.  Re-running the formula to create these failed security groups.

VPC Selection
=================
By default the states for all VPCs defined in the aws pillar will be run.
To limit states to a single VPC use the command line pillar

.. code-block::

  salt myserver state.apply pillar='{"vpc":"myvpc"}'


Configuration
=================

All configuration is done through the AWS pillar. The hierarchy of this pillar is:

.. code-block:: yaml

  aws:
    region:
      us-east-2:
        key_pairs:
        profile:
        vpc:
          myvpc:
            vpc:
            internet_gateway:
            subnets:
            routing_tables:
            routing_global_routes:
            security_groups:

In this hierarchy, the 3rd level ( us-east-2 ) is a region name and the 5th level ( myvpc ) is a vpc name.  These are the names that will be used for the region and the name of the VPC.  All items besides internet_gateway can have multiple values.

The below examples and the sample pillar uses single quotes in many places to ensure data is interepreted correctly.  Not using quotes per the examples is done at your own risk.

.. contents::
    :local:


``key_pairs``
-------------
Key pairs are included under at the region level since they are not generally VPC specific.  Key pair format is a key pair with the name and RSA public key.

.. code-block:: yaml

  key_pairs:
    mykey: 'ssh-rsa XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX admin@mycompany.com'

``profile``
------------
This formula uses an AWS profile for all states instead of the individual fields. The key and keyid should be gpg encrypted using the `Saltstack gpg renderer <https://docs.saltstack.com/en/latest/ref/renderers/all/salt.renderers.gpg.html>`_.  Example below shows it in unencrypted format.

.. code-block:: yaml

  profile:
    region: us-east-2
    keyid: ASDFASDFASDFASDFASDF
    key: AB12Cd3Efg45hIjk67lMNop8q9RST0uvwXyz


``vpc``
------------
VPC contains vpcs for a given region. Each vpc will have data for all VPC specific states, even if they are not in the vpc.sls.  The vpc pillar name is the name that will be used for the VPC in AWS.  The only data directly under the vpc name is the CIDR block for the VPC.  This Formula is designed using a class B network for the VPC and class C for all subnets.

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
Routing tables will create the tables, add routes, and assign subnets to routing tables.  The below example uses a subnet name that has a NAT Gateway to assocate that NAT Gateway with the routing table.

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
              nat_gateway_subnet_name: subWebA
          subnet_names:
            - subAppA

``vpc:routing_global_routes``
------------------------------
Routes that will be added to all routing tables.  Use this for adding vpn routes.

.. code-block:: yaml

  vpc:
    myvpc:
      routing_global_routes:
        vpnPROD:
          destination_cidr_block: '10.10.0.0/16'
          instance_id: 'i-xxxxxxxxxxxxxxx'

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
        sgApp:
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
        sgSalt:
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
