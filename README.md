# morays-upgrade-infra-tera

> **NEW: Auto Scaling replacement servers are automatically configured.** See [AUTOMATIC-DEPLOYMENT.md](AUTOMATIC-DEPLOYMENT.md) for the recommended updated workflow.

# Morays High Availability Terraform Infrastructure

This project builds **infrastructure only**. Ansible will install and configure the website later.
The configuration is intended as a **learning environment** with direct, tightly restricted SSH access from your computer.

## Architecture

```text
                      INTERNET
                          |
             Application Load Balancer :80
                  /                \
        Public subnet A        Public subnet B
        Availability Zone A    Availability Zone B
             EC2 #1               EC2 #2
                 \                /
                Auto Scaling Group
                min 2 / desired 2 / max 4
                 (CPU target 60%)
```

AWS Auto Scaling balances the application instances across two AZs. Both EC2 instances receive public IP addresses so that your later Ansible project can access them by SSH **once you restrict SSH to your own IP**. HTTP on the EC2 instances accepts traffic only from the ALB security group. An EC2 IAM instance profile also enables AWS Systems Manager access where the SSM agent and service access are available.

**Not yet a production design:** App servers are in public subnets, there is no HTTPS certificate or database, and new Auto Scaling replacements will **not** inherit Ansible changes made manually to old servers. To make the application highly available after an instance replacement, configure a repeatable bootstrap (custom AMI, user data, deployment agent or an Ansible deployment triggered for new instances). Use private subnets and SSM for production hardening.

## Files and what they do

| File | Purpose |
|---|---|
| `provider.tf` | Selects AWS provider and region; project uses separate local Terraform state. |
| `variables.tf` | Configurable settings (region, instance type, instance count, SSH source). |
| `vpc.tf` | Creates the VPC, 2 public subnets in different AZs, route table and Internet Gateway. |
| `securitygroup.tf` | ALB security group and protected EC2 security group. |
| `iam.tf` | IAM role/instance profile for SSM. |
| `main.tf` | Finds Amazon Linux 2023 and defines the EC2 Launch Template. |
| `alb.tf` | Application Load Balancer, target group and HTTP listener. |
| `autoscaling.tf` | Auto Scaling Group and CPU target-tracking policy. |
| `outputs.tf` | Prints important IDs, names and the ALB URL. |
| `terraform.tfvars.example` | Example values. Copy to `terraform.tfvars`. |
| `.gitignore` | Helps keep state, .pem files and local variables out of Git. |

## Step 1: Open in VS Code / WSL Ubuntu

Extract the ZIP under `~/morays-project/` so that you have a **new folder**, for example:

```text
~/morays-project/morays-terraform-ha/
```

Never place these new files on top of a different Terraform project's state files. Do not reuse the S3 state key from `morays-infra-terraform` or another existing project.

```bash
cd ~/morays-project/morays-terraform-ha
cp terraform.tfvars.example terraform.tfvars
```

## Step 2: Review key pair and SSH settings

Check that AWS already has the EC2 key pair named `olu1` in `eu-west-2`:

```bash
aws ec2 describe-key-pairs --region eu-west-2 --key-names olu1
```

If AWS uses another key name, edit `key_name` inside `terraform.tfvars`. The AWS key **name** is not the `.pem` file path. Keep the matching private key in your WSL `~/.ssh/` directory and outside Git.

SSH is **off by default**. To use direct Ansible SSH later, determine your current public IPv4 address:

```bash
curl -4 https://checkip.amazonaws.com
```

Then edit `terraform.tfvars` and set `ssh_cidr` to `YOUR_IP/32` (for example `198.51.100.42/32` as syntax only). Never use `0.0.0.0/0` for SSH. If your home IP changes, update that variable and re-apply. You can use SSM instead if you prefer not to open SSH.

## Step 3: Configure, validate and review

```bash
aws sts get-caller-identity
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
```

**Review the plan** before continuing. Terraform should primarily show new resources in this new project. Stop if it proposes destroying or modifying existing infrastructure you did not intend to change.

## Step 4: Create the infrastructure

```bash
terraform apply tfplan
terraform output
```

You will be charged by AWS for EC2 instances, load balancer time/usage, public IPv4 addresses, EBS storage and other billable services. Set a budget before applying and destroy the lab when it is no longer needed.

## Step 5: Verify the Auto Scaling Group

```bash
aws autoscaling describe-auto-scaling-groups \
  --region eu-west-2 \
  --auto-scaling-group-names "$(terraform output -raw autoscaling_group_name)" \
  --query 'AutoScalingGroups[].Instances[].[InstanceId,LifecycleState,HealthStatus]' \
  --output table
```

List running instances in your project by tag:

```bash
aws ec2 describe-instances \
  --region eu-west-2 \
  --filters 'Name=tag:Project,Values=morays-ha' 'Name=instance-state-name,Values=running' \
  --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress,Placement.AvailabilityZone,Tags[?Key==`Role`].Value|[0]]' \
  --output table
```

Confirm that two running instances exist, usually one per Availability Zone.

## Step 6: What to expect BEFORE Ansible

The ALB is created, but the Terraform project deliberately **does not install Apache or deploy `index.html`**. Therefore the ALB target group will show unhealthy HTTP checks, and the ALB URL may fail or show a service error. **This is expected until the Ansible project is deployed.** Auto Scaling initially checks EC2 instance health, not HTTP application health, to avoid replacing all your instances while the app is still missing.

After Ansible installs Apache and a page that returns HTTP 200 at `/`, targets should become healthy. Then consider changing `health_check_type = "EC2"` to `"ELB"` in `autoscaling.tf` and applying the change. **Before doing that**, ensure replacement instances get the website configuration automatically; otherwise an unhealthy replacement may enter a restart loop.

## Step 7: Later Ansible project

We will build that as a **separate directory**. It can select only this project through tags:

```yaml
plugin: amazon.aws.aws_ec2
regions:
  - eu-west-2
filters:
  tag:Project: morays-ha
  instance-state-name: running
groups:
  webserver: "'webserver' in (tags.Role | default(''))"
compose:
  ansible_host: public_ip_address
```

This is a preview, not part of this Terraform ZIP. Use the correct SSH key and username (`ec2-user` for Amazon Linux 2023). Check your current instance IDs and host fingerprints before accepting SSH keys. Replacement instances will get new IP addresses.

## Important security and availability notes

- ALB receives HTTP/80 from the Internet; EC2 receives HTTP/80 **only from the ALB**.
- SSH/22 is **disabled** unless `ssh_cidr` specifies your public IP address.
- All new EC2 instances have the `Project=morays-ha`, `Role=webserver`, `Environment=dev` and Name tags for dynamic inventory.
- HTTP is not encrypted. Add an ACM certificate and HTTPS listener when you have a domain.
- The application layer will not be truly self-healing after replacement until you automate application installation on new instances.
- No NAT gateways are required in this training architecture because EC2 instances are in public subnets.
- Avoid uploading `.tfstate`, `.tfvars` with secrets or private `.pem` keys to GitHub.
- The default `terraform.tfvars.example` sets SSH to null. Edit it only after checking your actual key name and IP.

## Clean up when finished

Only run inside the **new** `morays-terraform-ha` directory:

```bash
terraform plan -destroy
terraform destroy
```

Review carefully. These commands terminate resources managed by **this Terraform state** and can remove a running website.


## Automatic configuration for NEW Auto Scaling EC2 instances (added)

**This project now contains `site_artifacts.tf`, `ssm_website.tf`, and `scripts/configure_from_s3.sh.tftpl`.**

Terraform creates a PRIVATE, encrypted, versioned S3 bucket for the website, an EC2 read-only IAM policy, and a **Systems Manager State Manager Command association** targeted by `MoraysDeploy=morays-ha-dev-website` (using your configured project/environment). A new EC2 instance automatically receives this tag from the Launch Template/ASG.

**How it works:**

1. The separate `morays-ansible-ha` project publishes the static site to `s3://<bucket>/releases/<sha256>/` and updates `current.txt` LAST. The bucket is private; instances have *read-only* access.
2. On launch, EC2 **user data** runs the shared script and downloads the current version, installs Apache and serves the website. The load balancer checks `/healthz`.
3. AWS **State Manager** applies the same configuration to new managed nodes (tag-based targeting) and rechecks it every **30 minutes**. If initial provisioning failed before the website was published, a later run retries automatically.
4. Ansible still configures the initially running EC2 instances and handles website upgrades with `scripts/deploy.sh`. Replacement instances use the same published release, without a manual Ansible run.

**Critical first-deployment order:**

```bash
# On your WSL Ubuntu machine, from Terraform project:
terraform init
terraform validate
terraform plan
terraform apply
terraform output site_artifact_bucket

# From the separate Ansible project (see its README):
./scripts/deploy.sh

# Once your ALB /healthz is healthy on all intended targets,
# set enable_elb_health_checks = true in terraform.tfvars and then:
cd ../morays-terraform-ha
terraform plan
terraform apply
```

**Why the `enable_elb_health_checks` switch?** The Terraform-only stage has no website release in S3 yet. Leaving it `false` initially avoids Auto Scaling repeatedly replacing otherwise healthy EC2 instances just because Apache hasn't been installed. **Turn it on after the first successful website release** so failed web servers can be replaced based on Application Load Balancer health checks. The grace period is 900 seconds to allow for startup and initial downloads; adjust after observing boot times.

**Troubleshooting:**

```bash
terraform output -raw ssm_association_id
aws ssm describe-association --association-id "$(terraform output -raw ssm_association_id)" --region eu-west-2
aws ssm describe-association-executions --association-id "$(terraform output -raw ssm_association_id)" --region eu-west-2
aws ssm describe-instance-information --region eu-west-2
```

If no instances appear as Systems Manager managed nodes, check SSM Agent, the EC2 instance profile, outbound HTTPS connectivity and `AmazonSSMManagedInstanceCore` attachment.

**Important notes:**
- Your AWS CLI identity used on the Ansible controller must have *S3 PutObject* rights to the artifacts bucket. EC2 instances receive only GetObject and scoped ListBucket.
- After editing Terraform, use the **same existing Terraform state**. Do not delete state or create a duplicate infrastructure project by accident.
- Updating the Launch Template does **not** necessarily reconfigure existing instances. Ansible handles these; new/replacement instances use the latest Launch Template.
- `terraform destroy` will not delete a non-empty versioned S3 bucket by default. This is intentional to protect published website versions; empty the bucket, including versions, only when you explicitly want to remove everything.
- A private S3 bucket, Systems Manager association and storage may generate AWS charges. This is a learning HA design (public EC2 subnets, HTTP only); harden it for production with private web subnets, TLS/HTTPS, restricted administrative access and monitoring.
