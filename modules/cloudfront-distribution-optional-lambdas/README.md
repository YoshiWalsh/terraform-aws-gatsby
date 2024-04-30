**!!! DEPRECATED !!!**

This module was used in Terraform v0.11 and lower.

Back then, Terraform did not have any support for conditional blocks. This meant that it was not possible to create modules which would wrap CloudFront and make it optional to have attached Lambda functions and custom error responses.

In order to overcome this limitation, this helper module took a brute force approach of defining a conditional resource for every possible permutation of Lambda functions and error responses. You can view the generated file [here](https://github.com/YoshiWalsh/terraform-aws-gatsby/blob/87bfa915b1ce93d1d4aeeedd7b563c6d6cae202c/modules/cloudfront-distribution-optional-lambdas/generated.tf).

Fortunately since Terraform v0.12 this is no longer necessary. For backwards-compatibility purposes, this module has been updated to no longer use the brute-force approach. But going forward there's no reason to use this helper module at all.