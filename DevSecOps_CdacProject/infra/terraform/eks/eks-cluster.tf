module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  version                                  = "20.8.4"
  cluster_name                             = local.cluster_name
  cluster_version                          = var.kubernetes_version
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  enable_irsa                              = true
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true
  cluster_endpoint_private_access          = true
  cluster_endpoint_public_access_cidrs = [
    "0.0.0.0/0"
  ]
  tags = {
    cluster = "eks-cluster"
  }
  eks_managed_node_group_defaults = {
    ami_type               = "AL2023_x86_64_STANDARD"
    instance_types         = ["t3.medium"]
    vpc_security_group_ids = [aws_security_group.all_worker_mgmt.id]
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }
  eks_managed_node_groups = {
    node_group = {
      min_size     = 1
      max_size     = 3
      desired_size = 2
      # Override subnets for this node group only — use public subnets
      subnet_ids = module.vpc.public_subnets
      # Required for nodes in public subnets to actually get a public IP
      associate_public_ip_address = true
    }
  }
}