data "aws_vpc" "vpc_datasource" {
  id = "vpc-07bd49a034b4dfc44"
}

data "aws_availability_zones" "azs" {
  all_availability_zones = true
}

data "aws_subnets" "example" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_datasource.id]
  }
}

data "aws_subnet" "example" {
  for_each = toset(data.aws_subnets.example.ids)
  id       = each.value
}

data "aws_caller_identity" "current" {
}