data "aws_region" "current_region" {}

data "http" "alb_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

data "aws_route53_zone" "selected" {
  zone_id = var.route53_zone_id
}

###################################################
#                                                 #
#              Setting up the network             #
#                                                 #
###################################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Two Public Subnets (EKS requirement)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = "${data.aws_region.current_region.name}${count.index == 0 ? "a" : "b"}"
  map_public_ip_on_launch = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

###################################################
#                                                 #
#                 SSL Certifficate                #
#                                                 #
###################################################

resource "aws_acm_certificate" "cert" {
  domain_name       = "*.${var.domain}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

###################################################
#                                                 #
#               Role and permissions              #
#                                                 #
###################################################

# For the simplicity of this setup, we will create just one
# role, which will have all the necessary permissions, and
# will be used by the cluster, node pool, and therefore also
# ALB controller and External-DNS which will run within the cluster

resource "aws_iam_role" "eks_role" {
  name = "eks-role-${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "eks.amazonaws.com",
            "ec2.amazonaws.com"
          ]
        }
      }
    ]
  })
}

locals {
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
    "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  ]
}

resource "aws_iam_role_policy_attachment" "eks_policies" {
  for_each   = toset(local.policy_arns)
  policy_arn = each.value
  role       = aws_iam_role.eks_role.name
}

### Needed for the ALB Controller

resource "aws_iam_policy" "alb_controller" {
  name   = "AWSLoadBalancerControllerIAMPolicy-${var.cluster_name}"
  policy = data.http.alb_policy.response_body
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  policy_arn = aws_iam_policy.alb_controller.arn
  role       = aws_iam_role.eks_role.name
}

### Needed for the External DNS

resource "aws_iam_policy" "external_dns" {
  name = "ExternalDNSPolicy-${var.cluster_name}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  policy_arn = aws_iam_policy.external_dns.arn
  role       = aws_iam_role.eks_role.name
}

###################################################
#                                                 #
#                   EKS Cluster                   #
#                                                 #
###################################################

resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_role.arn
  version  = "1.29"

  vpc_config {
    subnet_ids              = aws_subnet.public[*].id
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  depends_on = [aws_iam_role_policy_attachment.eks_policies]
}

resource "aws_eks_node_group" "node_pool" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "${var.cluster_name}-pool"
  node_role_arn   = aws_iam_role.eks_role.arn
  subnet_ids      = aws_subnet.public[*].id

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  instance_types = ["c5.xlarge"]

  depends_on = [aws_iam_role_policy_attachment.eks_policies]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name  = aws_eks_cluster.cluster.name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = "v1.38.1-eksbuild.1"

  depends_on = [aws_eks_node_group.node_pool]
}

###################################################
#                                                 #
#         Helm and necessary "helper" pods        #
#                                                 #
###################################################

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.cluster.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.cluster.name]
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.cluster.name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "enableServiceAccount"
    value = "false"
  }

  depends_on = [
    aws_eks_cluster.cluster,
    aws_eks_node_group.node_pool,
    aws_iam_role_policy_attachment.alb_controller
  ]
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"

  set {
    name  = "provider.name"
    value = "aws"
  }

  set {
    name  = "aws.region"
    value = data.aws_region.current_region.name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "domainFilters[0]"
    value = trimsuffix(data.aws_route53_zone.selected.name, ".")
  }

  set {
    name  = "policy"
    value = "sync"
  }

  set {
    name  = "txtOwnerId"
    value = aws_eks_cluster.cluster.name
  }

  set {
    name  = "env[0].name"
    value = "AWS_DEFAULT_REGION"
  }

  set {
    name  = "env[0].value"
    value = data.aws_region.current_region.name
  }

  set {
    name  = "env[1].name"
    value = "AWS_REGION"
  }

  set {
    name  = "env[1].value"
    value = data.aws_region.current_region.name
  }

  depends_on = [
    aws_eks_cluster.cluster,
    aws_eks_node_group.node_pool,
    aws_iam_role_policy_attachment.external_dns
  ]
}