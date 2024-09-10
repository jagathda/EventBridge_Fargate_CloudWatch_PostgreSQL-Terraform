#Configure provider
provider "aws" {
    region = "eu-north-1"
}

#VPC for networking
resource "aws_vpc" "fargate_vpc" {
  cidr_block = "10.0.0.0/16"
}

#Public networks
resource "aws_subnet" "public_subnet_1" {
  vpc_id = aws_vpc.fargate_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-north-1a"
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id = aws_vpc.fargate_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-north-1b"
}

resource "aws_internet_gateway" "fargate_igw" {
  vpc_id = aws_vpc.fargate_vpc.id
}