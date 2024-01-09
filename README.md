# aws-openid-role-for-stacks

This module creates an AWS IAM role which uses OpenID Connect to authorize Terraform Cloud to perform operations in your AWS account. The module is intended for use with the stacks private preview.

## Usage

1. Take a note of your Terraform Cloud organization's ID. You can find this at the top of the organization settings page. It begins with `org-`.
2. Create a workspace using this repository (or a fork) as the VCS source.
3. Fill in the required variables (which will include your organization ID from step 1). If you don't want to fiddle with permissions, you can set `allowed_actions` to `["*"]`.
4. Authenticate your workspace to your AWS account, likely using [`doormat aws tf-push`](https://docs.prod.secops.hashicorp.services/doormat/cli/aws/#get-credentials-and-upload-them-to-your-tfce-workspace).
5. Start a workspace run, check the plan, and apply it.
6. Look at the run or workspace outputs to see the `role_arn` value. You'll use this [in your stack configuration](https://github.com/hashicorp/lambda-api-gateway-stack/blob/069f93798c983a23b93ac6699407a76b29fd563d/deployments.tfdeploy.hcl#L8) to configure the AWS provider.

## Note

If your AWS account is already configured for dynamic provider credentials (i.e., you already have an IAM OIDC provider for `app.terraform.io`), this configuration will fail to apply because only one OIDC provider per URL is allowed.

Workaround:

1. Replace the `aws_iam_openid_connect_provider` resource in this configuration with:

    ```terraform
    data "aws_iam_openid_connect_provider" "stacks" {
      url = "https://app.terraform.io"
    }
    ```

2. Update the policy in the `aws_iam_role.stacks` resource to refer to the data source instead: `aws_iam_openid_connect_provider.stacks.arn` --> `data.aws_iam_openid_connect_provider.stacks.arn`.
3. When configuring your stacks deployments (`*.tfdeploy.hcl` file), set the audience to the value from your current OIDC configuration (likely `aws.workload.identity`).
