#Configure provider
provider "aws" {
    region = "eu-north-1"
}

#VPC for networking
resource "aws_vpc" "fargate_vpc" {
  cidr_block = "10.0.0.0/16"
}