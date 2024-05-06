# terraform-aws-gatsby

This module sets up the infrastructure required to host a Gatsby static site on AWS with S3 and CloudFront, including a CodePipeline CI process.

Once your infrastructure is set up, we strongly recommend that you use [gatsby-plugin-s3](https://github.com/jariz/gatsby-plugin-s3) to deploy your site.

## Modules

### Root module

Highly opinionated module for setting up Gatsby on AWS.

Includes a production site and a password-protected preview site. Also includes a CI pipeline for automatically deploying updates.

### Nested module `modules/simple-static-site`

An opinionated module to host a static website using CloudFront and S3.

Includes some nice time-saving features:

 * Automatically deploys a www. prefixed redirect site (or an unprefixed site if your canonical domain already specifies www.)
 * Easily specify an arbitrary number of additional redirect sources
 * Option to host out of a private bucket (see `modules/s3-cloudfront-staticwebsitehosting` for details)
 * Automatic creation of DNS records and HTTPS certificates (including for redirect sites)

### Nested module `modules/s3-cloudfront-staticwebsitehosting`

A relatively unopinionated module to deploy a simple static site using CloudFront and S3's Static Website Hosting system.

Includes a few nice-to-have bonus features:

 * An option to host out of a private bucket, using Lambda@Edge to emulate S3's Static Website Hosting
 * An option to preserve query string parameters during serverside redirects
 * Automatic creation of DNS records and HTTPS certificate

## Roadmap

 * Improve documentation
 * Provide usage examples