/*AWS Resources*/

# VPC Resources
data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.2.0"

  name = var.prefix
  cidr = var.vpc_cidr
  azs  = data.aws_availability_zones.available.names
  tags = var.tags

  enable_dns_hostnames = true
  enable_nat_gateway   = true
  create_igw           = true

  public_subnets = [cidrsubnet(var.vpc_cidr, 3, 0)]
  private_subnets = [cidrsubnet(var.vpc_cidr, 3, 1),
  cidrsubnet(var.vpc_cidr, 3, 2)]

  default_security_group_egress = [{
    cidr_blocks = "0.0.0.0/0"
  }]

  default_security_group_ingress = [{
    description = "Allow all internal TCP and UDP"
    self        = true
  }]
}

resource "databricks_mws_networks" "this" {
  provider           = databricks.mws
  account_id         = var.databricks_account_id
  network_name       = "${var.prefix}-network"
  security_group_ids = [module.vpc.default_security_group_id]
  subnet_ids         = module.vpc.private_subnets
  vpc_id             = module.vpc.vpc_id
}

# Root S3 Bucket
resource "aws_s3_bucket" "root_storage_bucket" {
  bucket        = "${var.prefix}-rootbucket"
  force_destroy = true
  tags = merge(var.tags, {
    Name = "${var.prefix}-rootbucket"
  })
}

resource "aws_s3_bucket_public_access_block" "root_storage_bucket" {
  bucket             = aws_s3_bucket.root_storage_bucket.id
  ignore_public_acls = true
  depends_on         = [aws_s3_bucket.root_storage_bucket]
}

data "databricks_aws_bucket_policy" "this" {
  bucket = aws_s3_bucket.root_storage_bucket.bucket
}

resource "aws_s3_bucket_policy" "root_bucket_policy" {
  bucket = aws_s3_bucket.root_storage_bucket.id
  policy = data.databricks_aws_bucket_policy.this.json
}

resource "databricks_mws_storage_configurations" "this" {
  provider                   = databricks.mws
  account_id                 = var.databricks_account_id
  bucket_name                = aws_s3_bucket.root_storage_bucket.bucket
  storage_configuration_name = "${var.prefix}-storage"
}


/*Group B with IP*/
#add group B S3 Bucket
resource "aws_s3_bucket" "group_b" {
  bucket = "${var.prefix}-group-b"

  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = "${var.prefix}-group-b"
  })
}

# Group B public access block for bucket
resource "aws_s3_bucket_public_access_block" "group_b_pub_block" {
  bucket = aws_s3_bucket.group_b.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Group B Role in AWS
#trust relationships policy json text
data "aws_iam_policy_document" "group_b_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  } #add this second statement to give UC master role access to an external bucket
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"]
      type        = "AWS"
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.databricks_account_id]
    }
  }
}

#trust relationships policy apply
resource "aws_iam_role" "group_b_role" {
  name               = "${var.prefix}-groupb"
  assume_role_policy = data.aws_iam_policy_document.group_b_assume_role_policy.json
  tags               = var.tags
}

#inline policy json text
data "aws_iam_policy_document" "group_b_policy" {
  statement {
    effect = "Allow"
    actions = ["s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:PutObject",
    "s3:DeleteObject"]
    resources = [
      "${aws_s3_bucket.group_b.arn}/*",
    aws_s3_bucket.group_b.arn]
  }
}

#inline policy apply
resource "aws_iam_role_policy" "group_b_role_policy" {
  name   = "${var.prefix}-groupb-policy"
  role   = aws_iam_role.group_b_role.id
  policy = data.aws_iam_policy_document.group_b_policy.json
}

#add instance profile to group B role
resource "aws_iam_instance_profile" "group_b_profile" {
  name = "${var.prefix}-group_b_instance_profile"
  role = aws_iam_role.group_b_role.name
}

/*Audit Logs for UC*/
#add audit log bucket
resource "aws_s3_bucket" "logdelivery" {
  bucket = "${var.prefix}-logs"

  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = "${var.prefix}-logs"
  })
}

#public access block for log bucket
resource "aws_s3_bucket_public_access_block" "logs_pub_block" {
  bucket = aws_s3_bucket.logdelivery.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "databricks_aws_assume_role_policy" "log_delivery_doc" {
  external_id      = var.databricks_account_id
  for_log_delivery = true
}

data "aws_iam_policy_document" "logdelivery" {
  source_policy_documents = [data.databricks_aws_assume_role_policy.log_delivery_doc.json]
  statement {
    actions = ["sts:AssumeRole"]
    principals  {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "logdelivery" {
  name               = "${var.prefix}-logdelivery"
  description        = "(${var.prefix}) UsageDelivery role"
  assume_role_policy = data.aws_iam_policy_document.logdelivery.json
  tags               = var.tags
}


#log bucket policy
data "databricks_aws_bucket_policy" "logdelivery" {
  full_access_role = aws_iam_role.logdelivery.arn
  bucket           = aws_s3_bucket.logdelivery.bucket
}

#add instance profile to log role
resource "aws_iam_instance_profile" "logs_profile" {
  name = "${var.prefix}-logs_instance_profile"
  role = aws_iam_role.logdelivery.name
}

# Cross-account IAM role
data "databricks_aws_assume_role_policy" "this" {
  external_id = var.databricks_account_id
}

resource "aws_iam_role" "cross_account_role" {
  name               = "${var.prefix}-crossaccount"
  assume_role_policy = data.databricks_aws_assume_role_policy.this.json
  tags               = var.tags
}

#cross-account policy
data "databricks_aws_crossaccount_policy" "this" {
}

#modify policy to include instance profile for group B
data "aws_iam_policy_document" "default_with_instance_profiles" {
  source_policy_documents = [data.databricks_aws_crossaccount_policy.this.json]
  # Adding instance profiles
  statement {
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.group_b_role.arn, aws_iam_role.logdelivery.arn]
  }
}

#apply to inline policy of cross-account role
resource "aws_iam_role_policy" "this" {
  name   = "${var.prefix}-policy"
  role   = aws_iam_role.cross_account_role.id
  policy = data.aws_iam_policy_document.default_with_instance_profiles.json
}


#insert a delay to avoid eventual consistency error with AWS
resource "time_sleep" "wait" {
  depends_on = [
  aws_iam_role.cross_account_role]
  create_duration = "10s"
}

#apply log bucket policy
resource "aws_s3_bucket_policy" "logdelivery" {
  bucket = aws_s3_bucket.logdelivery.id
  policy = data.databricks_aws_bucket_policy.logdelivery.json
}

resource "databricks_mws_credentials" "this" {
  provider         = databricks.mws
  account_id       = var.databricks_account_id
  role_arn         = aws_iam_role.cross_account_role.arn
  credentials_name = "${var.prefix}-creds"
  depends_on       = [aws_iam_role_policy.this]
}

/*
 Databricks Workspace Resources
 Once you have all of the required AWS resources, you can deploy a Databricks Workspace
*/

# Databricks Workspace Credentials Config
resource "databricks_mws_workspaces" "this" {
  provider        = databricks.mws
  account_id      = var.databricks_account_id
  aws_region      = var.region
  workspace_name  = var.prefix
  deployment_name = var.prefix

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id
  depends_on = [
    time_sleep.wait
  ]
}
