variable "name" {
  description = "A name which will be pre-pended to the resources created"
  type        = string
}

variable "vpc_id" {
  description = "The VPC to deploy the collector within"
  type        = string
}

variable "subnet_ids" {
  description = "The list of at least two subnets in different availability zones to deploy the collector across"
  type        = list(string)
}

variable "collector_lb_sg_id" {
  description = "The ID of the load-balancer security group that sits upstream of the webserver"
  type        = string
}

variable "collector_lb_tg_id" {
  description = "The ID of the load-balancer target group to direct traffic from the load-balancer to the webserver"
  type        = string
}

variable "ingress_port" {
  description = "The port that the collector will be bound to and expose over HTTP"
  type        = number
}

variable "instance_type" {
  description = "The instance type to use"
  type        = string
  default     = "t3a.micro"
}

variable "associate_public_ip_address" {
  description = "Whether to assign a public ip address to this instance"
  type        = bool
  default     = true
}

variable "ssh_key_name" {
  description = "The name of the preexisting SSH key-pair to attach to all EC2 nodes deployed"
  type        = string
}

variable "ssh_ip_allowlist" {
  description = "The list of CIDR ranges to allow SSH traffic from"
  type        = list(any)
  default     = ["0.0.0.0/0"]
}

variable "iam_permissions_boundary" {
  description = "The permissions boundary ARN to set on IAM roles created"
  default     = ""
  type        = string
}

variable "min_size" {
  description = "The minimum number of servers in this server-group"
  default     = 1
  type        = number
}

variable "max_size" {
  description = "The maximum number of servers in this server-group"
  default     = 2
  type        = number
}

variable "amazon_linux_2_ami_id" {
  description = "The AMI ID to use which must be based of of Amazon Linux 2; by default the latest community version is used"
  default     = ""
  type        = string
}

variable "tags" {
  description = "The tags to append to this resource"
  default     = {}
  type        = map(string)
}

variable "cloudwatch_logs_enabled" {
  description = "Whether application logs should be reported to CloudWatch"
  default     = true
  type        = bool
}

variable "cloudwatch_logs_retention_days" {
  description = "The length of time in days to retain logs for"
  default     = 7
  type        = number
}

variable "java_opts" {
  description = "Custom JAVA Options"
  default     = "-Dorg.slf4j.simpleLogger.defaultLogLevel=info -Dcom.amazonaws.sdk.disableCbor -XX:MinRAMPercentage=50 -XX:MaxRAMPercentage=75"
  type        = string
}

# --- Auto-scaling options

variable "enable_auto_scaling" {
  description = "Whether to enable auto-scaling policies for the service"
  default     = true
  type        = bool
}

variable "scale_up_cooldown_sec" {
  description = "Time (in seconds) until another scale-up action can occur"
  default     = 180
  type        = number
}

variable "scale_up_cpu_threshold_percentage" {
  description = "The average CPU percentage that must be exceeded to scale-up"
  default     = 60
  type        = number
}

variable "scale_up_eval_minutes" {
  description = "The number of consecutive minutes that the threshold must be breached to scale-up"
  default     = 5
  type        = number
}

variable "scale_down_cooldown_sec" {
  description = "Time (in seconds) until another scale-down action can occur"
  default     = 600
  type        = number
}

variable "scale_down_cpu_threshold_percentage" {
  description = "The average CPU percentage that we must be below to scale-down"
  default     = 20
  type        = number
}

variable "scale_down_eval_minutes" {
  description = "The number of consecutive minutes that we must be below the threshold to scale-down"
  default     = 60
  type        = number
}

# --- Configuration options

variable "good_stream_name" {
  description = "The name of the good kinesis stream that the collector will insert data into"
  type        = string
}

variable "bad_stream_name" {
  description = "The name of the bad kinesis stream that the collector will insert data into"
  type        = string
}

variable "custom_paths" {
  description = "Optional custom paths that the collector will respond to, typical paths to override are '/com.snowplowanalytics.snowplow/tp2', '/com.snowplowanalytics.iglu/v1' and '/r/tp2'. e.g. { \"/custom/path/\" : \"/com.snowplowanalytics.snowplow/tp2\"}"
  default     = {}
  type        = map(string)
}

variable "cookie_enabled" {
  description = "Whether server side cookies are enabled or not"
  default     = true
  type        = bool
}

variable "cookie_domain" {
  description = "Optional first party cookie domain for the collector to set cookies on (e.g. acme.com)"
  default     = ""
  type        = string
}

variable "byte_limit" {
  description = "The amount of bytes to buffer events before pushing them to Kinesis"
  default     = 1000000
  type        = number
}

variable "record_limit" {
  description = "The number of events to buffer before pushing them to Kinesis"
  default     = 500
  type        = number
}

variable "time_limit_ms" {
  description = "The amount of time to buffer events before pushing them to Kinesis"
  default     = 500
  type        = number
}

# --- Telemetry

variable "telemetry_enabled" {
  description = "Whether or not to send telemetry information back to Snowplow Analytics Ltd"
  type        = bool
  default     = true
}

variable "user_provided_id" {
  description = "An optional unique identifier to identify the telemetry events emitted by this stack"
  type        = string
  default     = ""
}
