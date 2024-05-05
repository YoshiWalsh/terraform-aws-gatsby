variable "canonical_domain" {
    type = string
    description = "The domain name to host the website at."
}

variable "domain_route53_zones" {
    type = list
    default = []
    description = "List of zone names of all R53 zones which we need to create domains in. Zone names must include the trailing '.'"
}

variable "region" {
    type = string
    description = "The AWS region to create resources in."
    default = "us-east-1"
}

variable "redirect_sources" {
    type = list
    default = []
    description = "A list of additional domains which will be configured to redirect to this domain."
}

variable "preview_site_users" {
    type = map
    default = null
    description = "A map of username/password combinations for people that should be given access to the preview site. If this is null (default) the preview site will be disabled."
}

variable "preview_site_domain" {
    type = string
    default = null
    description = "The domain that the preview site should reside at. Defaults to a 'preview.' subdomain of the canonical domain (without any www. prefix, if applicable)."
}

variable "git_provider" {
    type = string
    description = "The Git repository provider. Supported values: "
    nullable = false
    validation {
        condition = contains(["CodeCommit", "Bitbucket", "GitHub", "GitLab", "GitHub Enterprise Server", "GitLab self-managed"], var.git_provider)
        error_message = "Unsupported git_provider value"
    }
}

variable "git_connection_arn" {
    type = string
    default = null
    description = "Required if git_provider is not CodeCommit."
    nullable = true
}

variable "git_repository" {
    type = string
    default = null
    description = "Full name of repository containing Gatsby project."
    nullable = false
}

variable "git_branch" {
    type = string
    default = null
    description = "Git branch to build from."
    nullable = false
}