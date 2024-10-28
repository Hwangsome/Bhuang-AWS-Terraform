# Terraform Output Values
/* Concepts Covered
1. For Loop with List
2. For Loop with Map
3. For Loop with Map Advanced
4. Legacy Splat Operator (latest) - Returns List
5. Latest Generalized Splat Operator - Returns the List
*/

# Output - For Loop with List
# 输出 list, 包含每个 EC2 实例的 ID
output "list_of_instance_ids" {
  value = [for instance in aws_instance.myec2vm : instance.id]
}

# Output - For Loop with Map
# 输出 map, 包含每个 EC2 实例的 ID 和 Private IP
output "map_of_instance_ids_and_private_ips" {
  value = { for instance in aws_instance.myec2vm : instance.id => instance.private_ip }
}

# Output - For Loop with Map Advanced
/**
for_output_map2                     = {
+ "0" = (known after apply)
+ "1" = (known after apply)
}
**/
output "for_output_map2" {
  description = "For Loop with Map - Advanced"
#  aws_instance.myec2vm 是所有创建的 EC2 实例的集合，instance 表示每个实例对象，而 c 是 count.index。
#  输出的 value 是一个 map，其中键是 c（即 count.index），值是每个实例的 public_dns。
  value = {for c, instance in aws_instance.myec2vm: c => instance.public_dns}
}

# 过滤映射中的键值对
output "running_servers" {
  value = { for server, status in var.server_statuses : server => status if status == "running" }
}

/**
list_user_role                      = [
      "admin",
      "developer",
    ]
**/
output "list_user_role" {
  value = [for user in var.users : user.role]
}

output "local_test" {
  value = local.users_by_role
}
