# ################################################################################
# # Backend terraform Cloud
# ################################################################################

terraform {
  backend "remote" {
    organization = "langhae"

    workspaces {
      name = "eks-cluster"
    }
  }
}

################################################################################
# Local Variables
################################################################################

# locals {
#   aws_accounts = {
#     cloud5 = {
#       id     = "940168446867"
#       region = "ap-southeast-2"
#       alias  = "magiclanghae"
#     }
#   }
#   context = yamldecode(file(var.config_file)).context
#   config  = yamldecode(templatefile(var.config_file, local.context))
# }

################################################################################
# Provaiders
################################################################################

# provider "aws" {
#     region = local.aws_accounts.cloud5.region

#     allowed_account_ids = [local.aws_accounts.cloud5.id]

#     assume_role {
#       role_arn = "arn:aws:iam::${local.aws_accounts.cloud5.id}:role/terraform-access"
#       session_name = local.context.workspace
#     }
# }