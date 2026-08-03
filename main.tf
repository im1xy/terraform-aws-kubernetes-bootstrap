locals {
  name        = "${var.cluster.name}-bootstrap"
  description = "${var.cluster.name} Bootstrap"

  force_trigger = var.force ? timestamp() : ""

  build_path = "${path.module}/.build"
  build_zip  = "${path.module}/bootstrap.zip"

  source_path = "${path.module}/source"
  source_hash = base64sha256(join("", concat([local.force_trigger], [
    for file in sort(fileset(local.source_path, "**/*")) : filesha256("${local.source_path}/${file}")
  ])))
}

resource "aws_iam_role" "this" {
  name               = local.name
  description        = local.description
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_policy" "this" {
  name        = local.name
  description = local.description
  policy      = data.aws_iam_policy_document.policy.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "AWSLambdaBasicExecutionRole" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "AWSLambdaVPCAccessExecutionRole" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "aws_security_group" "this" {
  name        = local.name
  description = local.description
  vpc_id      = var.cluster.vpc_config[0].vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_egress_rule" "outbound" {
  description       = "Allow outbound traffic"
  security_group_id = aws_security_group.this.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "api" {
  description                  = "Allow access to the EKS API server"
  security_group_id            = var.cluster.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.this.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  tags                         = var.tags
}

action "local_command" "build" {
  config {
    command           = "sh"
    arguments         = ["scripts/build.sh"]
    working_directory = path.module
  }
}

resource "terraform_data" "build" {
  triggers_replace = {
    source_hash   = local.source_hash
    force_trigger = local.force_trigger
  }

  lifecycle {
    action_trigger {
      events  = [before_create]
      actions = [action.local_command.build]
    }
  }
}

resource "aws_lambda_function" "this" {
  function_name = local.name
  description   = local.description

  role = aws_iam_role.this.arn

  runtime = "python3.14"
  handler = "main.handler"

  timeout       = 900
  memory_size   = 1024
  architectures = ["x86_64"]

  filename         = local.build_zip
  source_code_hash = local.source_hash

  vpc_config {
    security_group_ids = [aws_security_group.this.id]
    subnet_ids         = var.cluster.vpc_config[0].subnet_ids
  }

  environment {
    variables = {
      CLUSTER = var.cluster.name
    }
  }

  tags = var.tags

  depends_on = [terraform_data.build]
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_eks_access_entry" "this" {
  cluster_name  = var.cluster.name
  principal_arn = aws_iam_role.this.arn
  tags          = var.tags
}

resource "aws_eks_access_policy_association" "this" {
  cluster_name  = var.cluster.name
  principal_arn = aws_iam_role.this.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}

action "aws_lambda_invoke" "invoke" {
  config {
    function_name = aws_lambda_function.this.function_name
    payload = jsonencode({
      charts = var.charts
    })
  }
}

resource "terraform_data" "invoke" {
  triggers_replace = {
    cluster_id    = var.cluster.id
    source_hash   = local.source_hash
    force_trigger = local.force_trigger
    charts_hash   = sha256(jsonencode(var.charts))
  }

  depends_on = [
    terraform_data.build,
    aws_lambda_function.this
  ]

  lifecycle {
    action_trigger {
      events  = [after_create]
      actions = [action.aws_lambda_invoke.invoke]
    }
  }
}

resource "time_sleep" "this" {
  count           = var.sleep != null ? 1 : 0
  create_duration = var.sleep
  depends_on      = [terraform_data.invoke]
}
