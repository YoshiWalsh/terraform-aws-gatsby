variable "name" {
    type = string
    description = "A short name to describe the CodeBuild Project and other resources."
}

variable "address" {
    type = string
    description = "The web address to host the website at, including protocol."
    nullable = false
}

variable "bucket" {
    type = string
    description = "The bucket name to deploy to."
    nullable = false
}

variable "codepipeline_bucket" {
    type = string
    description = "The bucket name that CodePipeline artifacts are stored in."
    nullable = false
}

variable "cache_bucket" {
    type = string
    description = "The bucket to store the CodeBuild build cache in."
    nullable = false
}

variable "cloudfront_distribution" {
    type = string
    description = "The CloudFront distribution to invalidate during deplyoments."
    nullable = true
}