{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CodeBuildLogging",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:logs:*:*:log-group:/aws/codebuild/${name}",
                "arn:aws:logs:*:*:log-group:/aws/codebuild/${name}:*",
                "arn:aws:logs:*:*:log-group:/aws/codebuild/${name}:log-stream:*"
            ],
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ]
        },
        {
            "Sid": "CodePipelineArtifactStorage",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::${codepipeline_artifact_bucket}"
            ],
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:GetBucketAcl",
                "s3:GetBucketLocation"
            ]
        },
        {
            "Sid": "CodeBuildReports",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:codebuild:*:*:report-group/${name}-*"
            ],
            "Action": [
                "codebuild:CreateReportGroup",
                "codebuild:CreateReport",
                "codebuild:UpdateReport",
                "codebuild:BatchPutTestCases"
            ]
        },
        {
            "Sid": "S3Deployment",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::${bucket}/*",
                "arn:aws:s3:::${bucket}"
            ],
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:PutBucketWebsite",
                "s3:ListBucket",
                "s3:DeleteObject",
                "s3:GetBucketLocation",
                "s3:PutObjectAcl"
            ]
        },
        {
            "Sid": "CloudFrontInvalidations",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:cloudfront:*:*:distribution/${cloudfront_distribution}"
            ],
            "Action": [
                "cloudfront:GetInvalidation",
                "cloudfront:CreateInvalidation"
            ]
        },
        {
            "Sid": "CacheBucket",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::${cache_bucket}",
                "arn:aws:s3:::${cache_bucket}/*"
            ],
            "Action": [
                "s3:ListBucket",
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetBucketAcl",
                "s3:GetBucketLocation"
            ]
        }
    ]
}