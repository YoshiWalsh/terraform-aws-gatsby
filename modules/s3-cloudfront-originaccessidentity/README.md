This module sets up an S3 bucket and CloudFront distribution, and connects them via an Origin Access Identity. It additionally deploys two Lambda@Edge scripts which emulate the behaviour of S3's Static Website Hosting feature.

You can use this if you want to replicate the functionality of S3's Static Website Hosting, but without having a publicly accessible S3 origin bucket.