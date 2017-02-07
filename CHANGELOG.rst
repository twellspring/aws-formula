=============
aws-formula
=============


0.1.3
-----

- Limit states to a single VPC using command line pillar

0.1.2
-----

- Remove un-used include from init.sls

0.1.1
-----

- Fixed the NAT Gateway so it no longer requires a workaround
- Object names from pillar have the vpc name appended for uniqueness
- "Object names must be unique" workaround added
- "Security Group rule creation failure" workaround added

0.1.0
-----

- Create a functional VPC with workarounds for VPN and NAT Gateways
