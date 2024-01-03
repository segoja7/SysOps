locals {
  users = ["segoja7", ]
}
locals {
  azs = slice(data.aws_availability_zones.azs.names, 0, 3)
}