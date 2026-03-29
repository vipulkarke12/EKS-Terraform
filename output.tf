output "cluster_id" {
  value = aws_eks_cluster.vipulk.id
}

output "node_group_id" {
  value = aws_eks_node_group.vipulk.id
}

output "vpc_id" {
  value = aws_vpc.vipulk_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.vipulk_subnet[*].id
}
