##terraform-aws-gatsby

This module sets up the infrastructure required to host a Gatsby static site on AWS with S3 and CloudFront.

Once your infrastructure is set up, we strongly recommend that you use [gatsby-plugin-s3](https://github.com/jariz/gatsby-plugin-s3) to deploy your site.

### Status

This module is in the early phases of development. It should not be used for any serious projects yet.

### Features

 * Provides a module (`modules/s3-cloudfront-staticwebsitehosting`) which creates a site using CloudFront and S3's Static Website Hosting system.
 * Provides a module (`modules/s3-cloudfront-originaccessidentity`) which creates a site using S3 & CloudFront's Origin Access Identity, including a lambda script to handle per-directory index files. (Useful for situations where direct bucket access must be securely prohibited, such as for a password-protected site. Not free tier eligible. Does not support redirect rules, so you'll need to use a clientside redirect plugin like `gatsby-plugin-meta-redirect`.)
 * Root module automatically creates an HTTPS certificate and Route53 DNS records, in addition to creating a site using s3-cloudfront-staticwebsitehosting.

### Roadmap

 * Add support for missing trailing slashes to Origin Request Lambda@Edge script in OAI module
 * Add support for setting CloudFront Lambda@Edge functions to both CloudFront modules, including passthrough mechanism for Origin Request on OAI module
 * Create module (modules/codebuild-gatsby) which sets up CodeBuild to deploy Gatsby sites using gatsby-plugin-s3 
 * Write documentation
 * Create an example Terraform module which sets up a CI/CD pipeline with two environments, based on [this blog post](https://blog.joshwalsh.me/aws-gatsby/)
 * Upgrade to Terraform 0.12 (once it comes out)