locals {
  enable_route53_records = var.route53_zone_id != ""
}

# When enabled, this creates DNS records pointing to the ingress-nginx LoadBalancer.
# IMPORTANT: This only works after ingress-nginx has been installed and the LB exists.

data "aws_route53_zone" "public" {
  count   = local.enable_route53_records ? 1 : 0
  zone_id = var.route53_zone_id
}

data "aws_resourcegroupstaggingapi_resources" "ingress_nginx_lb" {
  count = local.enable_route53_records ? 1 : 0

  resource_type_filters = ["elasticloadbalancing:loadbalancer"]

  tag_filter {
    key    = "kubernetes.io/service-name"
    values = ["ingress-nginx/ingress-nginx-controller"]
  }

  # Most clusters tag the LB with kubernetes.io/cluster/<cluster_name>=owned
  # Include both common values.
  tag_filter {
    key    = "kubernetes.io/cluster/${var.cluster_name}"
    values = ["owned", "shared"]
  }
}

locals {
  ingress_lb_arn = local.enable_route53_records ? try(
    data.aws_resourcegroupstaggingapi_resources.ingress_nginx_lb[0].resource_tag_mapping_list[0].resource_arn,
    null
  ) : null
}

data "aws_lb" "ingress_nginx" {
  count = local.ingress_lb_arn != null ? 1 : 0
  arn   = local.ingress_lb_arn
}

resource "aws_route53_record" "airflow" {
  count   = local.ingress_lb_arn != null ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "${var.airflow_subdomain}.${trim(data.aws_route53_zone.public[0].name, ".")}"
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress_nginx[0].dns_name
    zone_id                = data.aws_lb.ingress_nginx[0].zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "mlflow" {
  count   = local.ingress_lb_arn != null ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "${var.mlflow_subdomain}.${trim(data.aws_route53_zone.public[0].name, ".")}"
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress_nginx[0].dns_name
    zone_id                = data.aws_lb.ingress_nginx[0].zone_id
    evaluate_target_health = false
  }
}
