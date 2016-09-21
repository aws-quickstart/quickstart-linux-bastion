# quickstart-linux-bastion

This Quick Start adds Linux bastion functionality to your AWS Cloud environment. It deploys Linux bastion hosts that provide secure access to your Linux instances in public or private subnets. Use this Quick Start as a building block for your Linux-based deployments on AWS. You can choose to create a new VPC environment for your Linux bastion hosts or deploy them into your existing VPC environment. After you deploy the Quick Start, you can add other AWS services, infrastructure components, and software layers to complete your test or production Linux environment on the AWS Cloud.

![Quick Start Linux Bastion Design Architecture](https://docs.aws.amazon.com/quickstart/latest/linux-bastion/images/linux-bastion-hosts-on-aws-architecture.png )

Deployment steps:

1. Sign up for an AWS account at http://aws.amazon.com, select a region, and create a key pair.
2. In the AWS CloudFormation console, launch one of the following templates to build a new stack:
  * /templates/linux-bastion-master.template (to deploy bastion hosts into a new VPC)
  * /templates/linux-bastion.template (to deploy bastion hosts into your existing VPC)
3. Add AWS services and other applications.

The Quick Start provides parameters that you can set to customize your deployment. For architectural details, best practices, step-by-step instructions, and customization options, see the deployment guide: http://docs.aws.amazon.com/quickstart/latest/linux-bastion/
