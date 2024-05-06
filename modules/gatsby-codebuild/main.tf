data "aws_iam_policy_document" "assume_role" {
    statement {
        effect = "Allow"

        principals {
            type = "Service"
            identifiers = ["codebuild.amazonaws.com"]
        }

        actions = ["sts:AssumeRole"]
    }
}

resource "aws_iam_role" "role" {
    name = "codebuild-${var.name}"
    assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "template_file" "policy_template" {
    template = file("${path.module}/data/codebuild-project-policy.json.tpl")
    vars = {
        name = var.name
        codepipeline_artifact_bucket = var.codepipeline_bucket
        bucket = var.bucket
        cloudfront_distribution = var.cloudfront_distribution
        cache_bucket = var.cache_bucket
    }
}

resource "aws_iam_role_policy" "policy" {
    name = "codebuild-${var.name}"
    role = aws_iam_role.role.id

    policy = data.template_file.policy_template.rendered
}

resource "aws_codebuild_project" "project" {
    name = var.name
    build_timeout = 10
    queued_timeout = 60

    service_role = aws_iam_role.role.arn

    artifacts {
        type = "CODEPIPELINE"
    }

    cache {
        type = "S3"
        location = "${var.cache_bucket}/cache_${var.name}"
    }

    environment {
        type = "LINUX_CONTAINER"
        compute_type = "BUILD_GENERAL1_SMALL"
        image = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
        image_pull_credentials_type = "CODEBUILD"
        privileged_mode = false

        environment_variable {
            name = "TARGET_ADDRESS"
            value = var.address
        }

        environment_variable {
            name = "TARGET_BUCKET_NAME"
            value = var.bucket
        }

        environment_variable {
            name = "CLOUDFRONT_DISTRIBUTION"
            value = var.cloudfront_distribution
        }
    }

    source {
        type = "CODEPIPELINE"
    }
}