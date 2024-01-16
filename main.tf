locals {
  module_name    = "collector-${var.sink_type}-ec2"
  module_version = "0.8.1"

  app_name    = "stream-collector"
  app_version = var.app_version

  local_tags = {
    Name           = var.name
    app_name       = local.app_name
    app_version    = local.app_version
    module_name    = local.module_name
    module_version = local.module_version
  }

  tags = merge(
    var.tags,
    local.local_tags
  )

  cloudwatch_log_group_name = "/aws/ec2/${var.name}"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

module "telemetry" {
  source  = "snowplow-devops/telemetry/snowplow"
  version = "0.5.0"

  count = var.telemetry_enabled ? 1 : 0

  user_provided_id = var.user_provided_id
  cloud            = "AWS"
  region           = data.aws_region.current.name
  app_name         = local.app_name
  app_version      = local.app_version
  module_name      = local.module_name
  module_version   = local.module_version
}

# --- CloudWatch: Logging

resource "aws_cloudwatch_log_group" "log_group" {
  count = var.cloudwatch_logs_enabled ? 1 : 0

  name              = local.cloudwatch_log_group_name
  retention_in_days = var.cloudwatch_logs_retention_days

  tags = local.tags
}

# --- IAM: Roles & Permissions

resource "aws_iam_role" "iam_role" {
  name        = var.name
  description = "Allows the collector nodes to access required services"
  tags        = local.tags

  assume_role_policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": [ "ec2.amazonaws.com" ]},
      "Action": [ "sts:AssumeRole" ]
    }
  ]
}
EOF

  permissions_boundary = var.iam_permissions_boundary
}

locals {
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id

  kinesis_arn_list = formatlist(
    "arn:aws:kinesis:%s:%s:stream/%s", local.region, local.account_id,
    compact(tolist([
      var.good_stream_name,
      var.bad_stream_name
    ]))
  )

  sqs_buffer_arn_list = formatlist(
    "arn:aws:sqs:%s:%s:%s", local.region, local.account_id,
    compact(tolist([
      var.good_sqs_buffer_name,
      var.bad_sqs_buffer_name
    ]))
  )

  sqs_arn_list = formatlist(
    "arn:aws:sqs:%s:%s:%s", local.region, local.account_id,
    compact(tolist([
      var.good_stream_name,
      var.bad_stream_name
    ]))
  )

  kinesis_statement = [{
    Sid    = "WriteToOutputStream"
    Effect = "Allow",
    Action = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:List*",
      "kinesis:Put*"
    ],
    Resource = local.kinesis_arn_list
  }]

  sqs_buffer_statement = [
    {
      Sid    = "WriteToOutputQueue"
      Effect = "Allow",
      Action = [
        "sqs:GetQueueUrl",
        "sqs:SendMessage"
      ],
      Resource = local.sqs_buffer_arn_list
    },
    {
      Sid    = "ListQueues"
      Effect = "Allow",
      Action = [
        "sqs:ListQueues"
      ],
      Resource = ["*"]
    }
  ]

  sqs_statement = [
    {
      Sid    = "WriteToOutputQueue"
      Effect = "Allow",
      Action = [
        "sqs:GetQueueUrl",
        "sqs:SendMessage"
      ],
      Resource = local.sqs_arn_list
    },
    {
      Sid    = "ListQueues"
      Effect = "Allow",
      Action = [
        "sqs:ListQueues"
      ],
      Resource = ["*"]
    }
  ]

  kinesis_statement_final    = var.sink_type == "kinesis" ? local.kinesis_statement : []
  sqs_buffer_statement_final = var.sink_type == "kinesis" && var.enable_sqs_buffer ? local.sqs_buffer_statement : []
  sqs_statement_final        = var.sink_type == "sqs" ? local.sqs_statement : []
}

resource "aws_iam_policy" "iam_policy" {
  name = var.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat(
      local.kinesis_statement_final,
      local.sqs_buffer_statement_final,
      local.sqs_statement_final,
      [
        {
          Effect = "Allow",
          Action = [
            "logs:PutLogEvents",
            "logs:CreateLogStream",
            "logs:DescribeLogStreams"
          ],
          Resource = [
            "arn:aws:logs:${local.region}:${local.account_id}:log-group:${local.cloudwatch_log_group_name}:*"
          ]
        }
      ]
    )
  })
}

resource "aws_iam_role_policy_attachment" "policy_attachment" {
  role       = aws_iam_role.iam_role.name
  policy_arn = aws_iam_policy.iam_policy.arn
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = var.name
  role = aws_iam_role.iam_role.name
}

# --- EC2: Security Group Rules

resource "aws_security_group" "sg" {
  name   = var.name
  vpc_id = var.vpc_id
  tags   = local.tags
}

resource "aws_security_group_rule" "ingress_tcp_22" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_ip_allowlist
  security_group_id = aws_security_group.sg.id
}

# Allows ingress from the load balancer to the webserver
resource "aws_security_group_rule" "ingress_tcp_webserver" {
  type                     = "ingress"
  from_port                = var.ingress_port
  to_port                  = var.ingress_port
  protocol                 = "tcp"
  source_security_group_id = var.collector_lb_sg_id
  security_group_id        = aws_security_group.sg.id
}

resource "aws_security_group_rule" "egress_tcp_80" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg.id
}

resource "aws_security_group_rule" "egress_tcp_443" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg.id
}

# Needed for clock synchronization
resource "aws_security_group_rule" "egress_udp_123" {
  type              = "egress"
  from_port         = 123
  to_port           = 123
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg.id
}

# --- EC2: Security Group Rules for the Load Balancer

# Allows egress from the load balancer to the webserver
resource "aws_security_group_rule" "lb_egress_tcp_webserver" {
  type                     = "egress"
  from_port                = var.ingress_port
  to_port                  = var.ingress_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.sg.id
  security_group_id        = var.collector_lb_sg_id
}

# --- EC2: Launch Templates, Auto-scaling group and Auto-scaling policies

module "instance_type_metrics" {
  source  = "snowplow-devops/ec2-instance-type-metrics/aws"
  version = "0.1.2"

  instance_type = var.instance_type
}

locals {
  collector_hocon = templatefile("${path.module}/templates/config.hocon.tmpl", {
    sink_type            = var.sink_type
    port                 = var.ingress_port
    paths                = var.custom_paths
    cookie_enabled       = var.cookie_enabled
    cookie_domain        = var.cookie_domain
    good_stream_name     = var.good_stream_name
    bad_stream_name      = var.bad_stream_name
    enable_sqs_buffer    = var.enable_sqs_buffer
    good_sqs_buffer_name = var.good_sqs_buffer_name
    bad_sqs_buffer_name  = var.bad_sqs_buffer_name
    region               = data.aws_region.current.name

    byte_limit    = var.sink_type == "kinesis" ? var.byte_limit : min(var.byte_limit, 192000)
    record_limit  = var.sink_type == "kinesis" ? var.record_limit : min(var.record_limit, 10)
    time_limit_ms = var.time_limit_ms

    telemetry_disable          = !var.telemetry_enabled
    telemetry_collector_uri    = join("", module.telemetry.*.collector_uri)
    telemetry_collector_port   = 443
    telemetry_secure           = true
    telemetry_user_provided_id = var.user_provided_id
    telemetry_auto_gen_id      = join("", module.telemetry.*.auto_generated_id)
    telemetry_module_name      = local.module_name
    telemetry_module_version   = local.module_version
  })

  user_data = templatefile("${path.module}/templates/user-data.sh.tmpl", {
    sink_type  = var.sink_type
    port       = var.ingress_port
    config_b64 = var.config_override_b64 == "" ? base64encode(local.collector_hocon) : var.config_override_b64
    version    = local.app_version

    telemetry_script = join("", module.telemetry.*.amazon_linux_2_user_data)

    cloudwatch_logs_enabled   = var.cloudwatch_logs_enabled
    cloudwatch_log_group_name = local.cloudwatch_log_group_name

    container_memory = "${module.instance_type_metrics.memory_application_mb}m"
    java_opts        = var.java_opts
  })
}

module "service" {
  source  = "snowplow-devops/service-ec2/aws"
  version = "0.2.1"

  user_supplied_script = local.user_data
  name                 = var.name
  tags                 = local.tags

  amazon_linux_2_ami_id       = var.amazon_linux_2_ami_id
  instance_type               = var.instance_type
  ssh_key_name                = var.ssh_key_name
  iam_instance_profile_name   = aws_iam_instance_profile.instance_profile.name
  associate_public_ip_address = var.associate_public_ip_address
  security_groups             = [aws_security_group.sg.id]

  min_size   = var.min_size
  max_size   = var.max_size
  subnet_ids = var.subnet_ids

  target_group_arns = [var.collector_lb_tg_id]

  health_check_type = "ELB"

  enable_auto_scaling                 = var.enable_auto_scaling
  scale_up_cooldown_sec               = var.scale_up_cooldown_sec
  scale_up_cpu_threshold_percentage   = var.scale_up_cpu_threshold_percentage
  scale_up_eval_minutes               = var.scale_up_eval_minutes
  scale_down_cooldown_sec             = var.scale_down_cooldown_sec
  scale_down_cpu_threshold_percentage = var.scale_down_cpu_threshold_percentage
  scale_down_eval_minutes             = var.scale_down_eval_minutes
}
