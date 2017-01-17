{% from "states/aws/defaults.yaml"  import aws with context %}

include:
  - .vpc
  - .secgroup
  - .ec2

