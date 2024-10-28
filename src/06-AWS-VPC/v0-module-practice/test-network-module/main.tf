module "network_module" {
  source           = "../network"
  cidr_block       = "10.0.0.0/16"
  subnet_cidr_block = "10.0.1.0/24"
}

output "created_vpc_id" {
  value = module.network_module.vpc_id
}

output "created_subnet_id" {
  value = module.network_module.subnet_id
}