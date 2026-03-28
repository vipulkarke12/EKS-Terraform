output "cluster_id" {
  value = aws_eks_cluster.vipul.id
}

output "node_group_id" {
  value = aws_eks_node_group.vipul.id
}

output "vpc_id" {
  value = aws_vpc.vipul_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.vipul_subnet[*].id
}
