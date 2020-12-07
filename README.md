# aws-personal-bastion

These AWS Cloudformation templates and scripts adds bastion hosts to your AWS environment on demand.  Every host is restricted to a single user, with access lists and keys created specifically for that user.

The project is based on the AWS Quick Start project 'linux-bastion': https://docs.aws.amazon.com/quickstart/latest/linux-bastion.

Modify the templates with default parameters appropriate for your environment.  S3 buckets, template URLs, and regions must be changed for your environment. Other parameters such as AWS object names may be changed to suit your conventions.

Deployment steps:

1. Create the global IAM resources first using the Cloudformation stack with the bastion-iam.yaml template.  This stack can be deployed in any region.
2. Create the shared IAM resources in each region where bastion hosts may be deployed (subnets, security groups, etc) using the bastion-shared.yaml Cloudformation template.
3. When needed, create a bastion host by running the bastion.sh bash script, which deploys the bastion.yaml Cloudformation template.

