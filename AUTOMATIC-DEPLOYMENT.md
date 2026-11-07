# Automatic configuration of newly created Auto Scaling instances

This project extends **Morays Terraform HA** with boot-time website configuration and a recurring Systems Manager State Manager association. All application files are authored in the *separate* `morays-ansible-ha/site/` folder.

## Added/updated files

| File | Purpose |
|---|---|
| `site_artifacts.tf` | Private, encrypted, versioned S3 release bucket. |
| `ssm_website.tf` | SSM Command document and 30-minute tag-targeted State Manager association. |
| `scripts/configure_from_s3.sh.tftpl` | Shared EC2 user-data/SSM script that downloads, validates and runs a release. |
| `iam.tf` | Restricts EC2 S3 permissions to release reads only. |
| `main.tf` | Adds user-data bootstrap and deployment tag to Launch Template. |
| `autoscaling.tf` | Propagates the tag and introduces opt-in ELB replacement health checks. |
| `alb.tf` | Uses `/healthz` as the target group's health check. |
| `outputs.tf`, `variables.tf`, `terraform.tfvars.example` | New outputs and activation flag. |

## Commands (first deployment)

```bash
cd ~/morays-project/morays-terraform-ha
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform output site_artifact_bucket
```

Because the S3 website has not yet been uploaded, new EC2 instances will initially *not* be able to serve the website. This is expected. Keep `enable_elb_health_checks = false` initially (the default). Then from the **Ansible** folder publish and configure the website:

```bash
cd ~/morays-project/morays-ansible-ha
./scripts/publish_site.sh  # no SSH required, SSM configures instances within its schedule
# OR, if SSH is configured and working:
./scripts/deploy.sh        # publish + immediate Ansible deployment
```

Confirm the ALB target group's `/healthz` checks are healthy before enabling ELB-based Auto Scaling recovery:

```bash
cd ~/morays-project/morays-terraform-ha
# Edit terraform.tfvars to include:
# enable_elb_health_checks = true
terraform plan
terraform apply
```

## What happens when the Auto Scaling Group launches a replacement?

1. Terraform's Launch Template attaches the project deployment tag and an EC2 IAM role with S3 read + SSM permissions.
2. At boot, `user_data` retrieves the current S3 release, installs Apache and deploys the static website.
3. State Manager also automatically applies its Command association to each newly tagged managed EC2 instance and retries drift repair every 30 minutes.
4. The load balancer begins forwarding traffic only when `/healthz` responds successfully.
5. With `enable_elb_health_checks=true`, Auto Scaling can replace instances that repeatedly fail HTTP health checks (after its boot grace period).

## Check/diagnose

```bash
terraform output -raw website_url
terraform output -raw site_artifact_bucket
aws ssm describe-instance-information --region eu-west-2
aws ssm describe-association-executions \
  --association-id "$(terraform output -raw ssm_association_id)" --region eu-west-2
aws elbv2 describe-target-health \
  --target-group-arn "$(terraform output -raw target_group_arn)" --region eu-west-2
```

If SSM is offline, check outbound HTTPS, the attached role, and SSM Agent logs. Amazon Linux 2023 includes AWS CLI v2 and generally includes SSM Agent. The new bucket is private: do **not** add a public ACL/policy. S3 versioning retains rollback options and can accumulate storage cost. **Do not destroy resources in your original project or delete existing Terraform state.**

## Boundaries

This supplies automatic recovery of the **website configuration** when new instances launch. It does not provide a full blue/green release controller, a multi-region disaster recovery plan, a database, backups, autoscaling alarms beyond the existing CPU policy, or HTTPS/TLS. Verify the environment before calling it production-ready.