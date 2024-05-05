provider "aws" {
    region = var.region
}

provider "aws" {
    alias = "certificates"
    region = "us-east-1"
}

resource "random_id" "environment_identifier" {
    keepers = {
    }

    byte_length = 8
}

locals {
    is_www = startswith(var.canonical_domain, "www.")
    unprefixed_domain = local.is_www ? substr(var.canonical_domain, 4, length(var.canonical_domain) - 4) : var.canonical_domain
    inverse_www_domain = "${local.is_www ? "" : "www."}${local.unprefixed_domain}"

    preview_domain = coalesce(var.preview_site_domain, "preview.${local.unprefixed_domain}")
}



resource "aws_iam_role" "lambda_role" {
  name = "${replace("${var.canonical_domain}", ".", "-")}_customlambda"


  assume_role_policy = file("${path.module}/modules/s3-cloudfront-staticwebsitehosting/data/lambda_role_assumepolicy.json")
}

resource "aws_iam_role_policy" "lambda_role_policy" {
  name = "${replace("${var.canonical_domain}", ".", "-")}_customlambda"
  role = aws_iam_role.lambda_role.id

  policy = file("${path.module}/data/lambda_role_policy.json")
}


data "template_file" "preview_viewerrequest_lambda_template" {
    count = var.preview_site_users != null ? 1 : 0
    
    template = file("${path.module}/data/password.js.tpl")
    vars = {
        user_declaration = jsonencode(var.preview_site_users)
    }
}

data "archive_file" "preview_viewerrequest_lambda_archive" {
    count = var.preview_site_users != null ? 1 : 0
    
    type = "zip"
    output_path = "${path.module}/artifacts/${random_id.environment_identifier.hex}_viewerrequest_lambda.zip"

    source {
        filename = "index.js"
        content = data.template_file.preview_viewerrequest_lambda_template[0].rendered
    }
}

resource "aws_lambda_function" "preview_viewerrequest_lambda" {
    count = var.preview_site_users != null ? 1 : 0
    
    filename = "${path.module}/artifacts/${random_id.environment_identifier.hex}_viewerrequest_lambda.zip"
    function_name = "gatsby_${random_id.environment_identifier.hex}_viewerrequest"
    role = aws_iam_role.lambda_role.arn
    handler = "index.handler"

    source_code_hash = data.archive_file.preview_viewerrequest_lambda_archive[0].output_base64sha256
    runtime = "nodejs20.x"
    publish = true

    lifecycle {
        create_before_destroy = true
    }
}

module "main_site" {
    source = "./modules/simple-static-site"

    providers = {
        aws = aws
        aws.certificates = aws.certificates
    }

    domain = var.canonical_domain

    domain_route53_zones = var.domain_route53_zones

    redirect_sources = concat(
        [local.inverse_www_domain],
        var.redirect_sources
    )

    use_private_bucket = false
}

module "preview_site" {
    count = var.preview_site_users != null ? 1 : 0
    
    source = "./modules/simple-static-site"

    providers = {
        aws = aws
        aws.certificates = aws.certificates
    }

    domain = local.preview_domain

    cloudfront_lambda_viewerrequest_qualifiedarn = aws_lambda_function.preview_viewerrequest_lambda[0].qualified_arn

    domain_route53_zones = var.domain_route53_zones

    use_private_bucket = true
}



resource "aws_s3_bucket" "codepipeline_bucket" {
	bucket_prefix = "${substr(var.domain, 0, 31)}-build"
}

resource "aws_s3_bucket_public_access_block" "codepipeline_bucket_publicaccess" {
    bucket = aws_s3_bucket.codepipeline_bucket.id

    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}

module "codebuild_preview" {
	source = "./modules/gatsby-codebuild"

	name = "${substr(var.canonical_domain, 0, 25)}-pre"
	address = "https://${local.preview_domain}/"
	bucket = module.preview_site.static_s3_bucket_name
	codepipeline_bucket = aws_s3_bucket.codepipeline_bucket
	cache_bucket = aws_s3_bucket.codepipeline_bucket
	cloudfront_distribution = module.preview_site.cf_distribution_id
}

module "codebuild_production" {
	source = "./modules/gatsby-codebuild"

	name = "${substr(var.canonical_domain, 0, 25)}"
	address = "https://${var.canonical_domain}/"
	bucket = module.main_site.static_s3_bucket_name
	codepipeline_bucket = aws_s3_bucket.codepipeline_bucket
	cache_bucket = aws_s3_bucket.codepipeline_bucket
	cloudfront_distribution = module.main_site.cf_distribution_id
}

resource "aws_codepipeline" "codepipeline" {
	name = "${substr(var.canonical_domain, 0, 25)}"
	role_arn = aws_iam_role.codepipeline_role.arn

	pipeline_type = "V1"

	artifact_store {
		type = "S3"
		location = aws_s3_bucket.codepipeline_bucket.bucket
	}

	stage {
		name = "Source"

		action {
			name = "Source"
			category = "Source"
			owner = "AWS"
			provider = var.git_provider == "CodeCommit" ? "CodeCommit" : "CodeStarSourceConnection"
			version = "1"
			output_artifacts = ["source_output"]

			configuration = var.git_provider == "CodeCommit" ? {
				RepositoryName = var.git_repository
				BranchName = var.git_branch
				PollForSourceChanges = true # TODO: Convert from polling pipeline https://docs.aws.amazon.com/codepipeline/latest/userguide/update-change-detection.html#update-change-detection-cli-codecommit
				OutputArtifactFormat = "CODE_ZIP"
			} : {
				ConnectionArn = var.git_connection_arn
				FullRepositoryId = var.git_repository
				BranchName = var.git_branch
				DetectChanges = true
				OutputArtifactFormat = "CODE_ZIP"
			}
		}
	}

	stage {
		name = "DeployPreview"

		action {
			name = "DeployPreview"
			category = "Build"
			owner = "AWS"
			provider = "CodeBuild"
			input_artifacts = ["source_output"]
			output_artifacts = ["preview_build_output"]
			version = "1"

			configuration = {
				ProjectName = module.codebuild_preview.codebuild_project_name
			}
		}
	}

	stage {
		name = "Approval"

		action {
			name = "Approval"
			category = "Approval"
			owner = "AWS"
			provider = "Manual"
			input_artifacts = []
			output_artifacts = []
			version = "1"

			configuration = {
				ExternalEntityLink = "https://${local.preview_domain}/"
			}
		}
	}

	stage {
		name = "DeployProduction"

		action {
			name = "DeployProduction"
			category = "Build"
			owner = "AWS"
			provider = "CodeBuild"
			input_artifacts = ["source_output"]
			output_artifacts = ["production_build_output"]
			version = "1"

			configuration = {
				ProjectName = module.codebuild_production.codebuild_project_name
			}
		}
	}
}