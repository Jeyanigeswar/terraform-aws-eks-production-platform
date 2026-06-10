resource "aws_eks_cluster" "main" {

  name = "${var.environment}-eks-cluster"

  role_arn = var.cluster_role_arn

  version = "1.31"

  vpc_config {

    subnet_ids = var.private_subnet_ids

    endpoint_private_access = true

    endpoint_public_access = true
  }

  depends_on = [
    var.cluster_role_arn
  ]
}

resource "aws_eks_node_group" "main" {

  cluster_name = aws_eks_cluster.main.name

  node_group_name = "${var.environment}-node-group"

  node_role_arn = var.node_role_arn

  subnet_ids = var.private_subnet_ids

  instance_types = ["t3.medium"]

  capacity_type = "ON_DEMAND"

  scaling_config {

    desired_size = 2

    min_size = 2

    max_size = 5
  }

  depends_on = [
    aws_eks_cluster.main
  ]
}

resource "aws_eks_addon" "vpc_cni" {

  cluster_name = aws_eks_cluster.main.name

  addon_name = "vpc-cni"
}

resource "aws_eks_addon" "coredns" {

  cluster_name = aws_eks_cluster.main.name

  addon_name = "coredns"
}

resource "aws_eks_addon" "kube_proxy" {

  cluster_name = aws_eks_cluster.main.name

  addon_name = "kube-proxy"
}