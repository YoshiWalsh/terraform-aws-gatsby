##terraform-aws-gatsby

This module sets up the infrastructure required to host a Gatsby static site on AWS with S3 and CloudFront.

Once your infrastructure is set up, we strongly recommend that you use [gatsby-plugin-s3](https://github.com/jariz/gatsby-plugin-s3) to deploy your site.

### Status

This module is in the early phases of development. It should not be used for any serious projects yet.

### Features

 * Provides a module (modules/s3-cloudfront-staticwebsitehosting) which creates a site using CloudFront and S3's Static Website Hosting system.
 * Root module automatically creates an HTTPS certificate and Route53 DNS records, in addition to creating a site using s3-cloudfront-staticwebsitehosting.

### Roadmap

 * A module (modules/s3-cloudfront-originaccessidentity) which creates a site using S3 & CloudFront's Origin Access Identity, including a lambda script to handle trailing slashes and directory indexes (would be useful for situations where direct bucket access needs to be prevented, such as password protected sites)
 * A module (modules/codebuild-gatsby) which sets up CodeBuild to deploy Gatsby sites using gatsby-plugin-s3 
 * Documentation
 * An example Terraform module which sets up a CI/CD pipeline with two environments, based on [this blog post](https://blog.joshwalsh.me/aws-gatsby/)
 * Upgrade to Terraform 0.12 (once it comes out)