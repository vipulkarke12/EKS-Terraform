provider "aws" {
  region = "ca-central-1"
}

resource "aws_vpc" "vipul_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "vipul-vpc"
  }
}

resource "aws_subnet" "vipul_subnet" {
  count = 2
  vpc_id                  = aws_vpc.vipul_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.vipul_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["ca-central-1a", "ca-central-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "vipul-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "vipul_igw" {
  vpc_id = aws_vpc.vipul_vpc.id

  tags = {
    Name = "vipul-igw"
  }
}

resource "aws_route_table" "vipul_route_table" {
  vpc_id = aws_vpc.vipul_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vipul_igw.id
  }

  tags = {
    Name = "vipul-route-table"
  }
}

resource "aws_route_table_association" "a" {
  count          = 2
  subnet_id      = aws_subnet.vipul_subnet[count.index].id
  route_table_id = aws_route_table.vipul_route_table.id
}

resource "aws_security_group" "vipul_cluster_sg" {
  vpc_id = aws_vpc.vipul_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vipul-cluster-sg"
  }
}

resource "aws_security_group" "vipul_node_sg" {
  vpc_id = aws_vpc.vipul_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vipul-node-sg"
  }
}

# 1. Add missing VPC policy for cluster role
resource "aws_iam_role_policy_attachment" "vipul_cluster_vpc_policy" {
  role       = aws_iam_role.vipul_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_eks_cluster" "vipul" {
  name     = "vipul-cluster"
  role_arn = aws_iam_role.vipul_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.vipul_subnet[*].id
    security_group_ids = [aws_security_group.vipul_cluster_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.vipul_cluster_role_policy,
    aws_iam_role_policy_attachment.vipul_cluster_vpc_policy,
  ]
}

resource "aws_eks_node_group" "vipul" {
  cluster_name    = aws_eks_cluster.vipul.name
  node_group_name = "vipul-node-group"
  node_role_arn   = aws_iam_role.vipul_node_group_role.arn
  subnet_ids      = aws_subnet.vipul_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["c7i-flex.large"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.vipul_node_sg.id]
  }
}

resource "aws_iam_role" "vipul_cluster_role" {
  name = "vipul-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "vipul_cluster_role_policy" {
  role       = aws_iam_role.vipul_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "vipul_node_group_role" {
  name = "vipul-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "vipul_node_group_role_policy" {
  role       = aws_iam_role.vipul_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "vipul_node_group_cni_policy" {
  role       = aws_iam_role.vipul_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "vipul_node_group_registry_policy" {
  role       = aws_iam_role.vipul_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
