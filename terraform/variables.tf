variable "bucket_prefix" {
  description = "Globally unique prefix for your S3 bucket names. Example: 'johndoe' creates 'johndoe-dr-primary' and 'johndoe-dr-secondary'. Must be lowercase letters, numbers, and hyphens only."
  type        = string
}

variable "primary_region" {
  description = "AWS region for the primary (active) website bucket."
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "AWS region for the secondary (standby) website bucket."
  type        = string
  default     = "us-west-2"
}

variable "enable_route53_failover" {
  description = "Set to true to create Route 53 health check and failover DNS records. Requires hosted_zone_id and domain_name."
  type        = bool
  default     = false
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID. Required when enable_route53_failover is true."
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain or subdomain for the failover DNS record. Example: 'dr-demo.example.com'. Required when enable_route53_failover is true."
  type        = string
  default     = ""
}