# Secure Bastion Gateway

A hardened, VPN-gated entry point for private AWS infrastructure. Nothing inside the network is directly reachable from the internet.

## The problem

When every server accepts SSH from the internet, each one becomes an independent attack surface, and that surface grows with every server added. This project builds a single hardened entry point and puts everything else behind it. Only the bastion is internet-facing, and access to it runs through an encrypted VPN tunnel rather than raw SSH exposure.

The pattern is standard rather than invented. AWS's own architecture guidance recommends it.

## Why this project

It forces real networking decisions. Public and private subnet split, route tables, security groups scoped to specific sources rather than `0.0.0.0/0`.

It makes Linux administration unavoidable. SELinux stays in enforcing mode, firewalld rules are scoped to exactly what is needed, SSH runs key-only, services are managed through systemd. This is applied Linux work rather than exam preparation, since RHCSA is not currently on my certification roadmap.

It is correctly sized. Four distinct skill areas, VPC design, Linux hardening, VPN configuration, and Terraform, in a project small enough to finish in a few weeks.

## What separates this from a tutorial clone

- SELinux stays enforcing. Disabling it is the standard beginner shortcut and this project explicitly avoids it.
- Every security group rule is scoped deliberately and explained, not copied from a guide.
- The README documents what was rejected and why, including bastion plus VPN versus AWS Systems Manager Session Manager.
- The single point of failure question is addressed directly rather than ignored.
- A real architecture diagram, not a description of one.

## Stack

| Component | Purpose |
|---|---|
| **Terraform** | VPC, subnets, security groups, EC2, IAM. All reproducible, nothing console clicked. |
| **Bash** | Hardening scripts and service configuration |
| **WireGuard** | The VPN layer, installed directly on the bastion |
| **Linux admin** | SELinux, firewalld, SSH key-only auth, systemd |
| **CloudWatch** | Stretch goal. Alarms for bastion health, failed SSH attempts, VPN drops. |
| **GitHub** | Version control from the first commit |

## Cost-safe architecture

Three choices avoid charges without weakening the architecture. In each case the cheaper option is also the more instructive one.

| Standard paid pattern | Used here instead | Reason |
|---|---|---|
| Managed NAT Gateway, around £32 per month | **NAT instance** on a t3.micro | Configuring the routing manually is the part worth demonstrating. Clicking "create NAT Gateway" demonstrates nothing. |
| Managed VPN Gateway, paid | **WireGuard on the bastion** | Software on a box that is already running, so it adds no AWS cost. |
| Public IPv4 on every instance, around £3 per month each | **Auto-assign public IP off** everywhere except the bastion | AWS now charges per public IPv4 address. Only the bastion needs to be reachable, so this is both the correct security architecture and the cheaper one. |

### Account and billing model

The account runs on the **Paid Plan** with $100 in credits, expiring 09/03/2027. The Paid Plan was chosen because Free Plan accounts close automatically after 6 months, which would delete the project. Full reasoning is in the decision log, entry D-003.

Billing alerts are set at **$5 to investigate** and **$15 to escalate**, sized against a project that should cost single digit dollars in total. Both use forecasted spend rather than actual, so they warn before the threshold is crossed rather than after. See decision log D-005 and D-006.

Billing alerts are a **hard gate**. Nothing that provisions real AWS resources happens until they are confirmed live. Local-only work such as installing Terraform and creating the repository is not gated.

### The closing ritual

Run `terraform destroy` at the end of every session, not just at the end of the project. This is the single largest guard against a forgotten instance generating charges, and it matters more on a credit balance that only decreases.

`terraform destroy` only removes what is in Terraform's state file, which is why nothing in this project gets created by clicking through the console. Anything created by hand is invisible to the destroy command and keeps running. See decision log D-010.

## Out of scope

- **CI/CD.** A bastion host is not something you continuously build and deploy. This belongs on a different project.
- **Docker and Kubernetes.** Parked until the CKA timeline in Q2 2027.

## Timeline

**Now to 25 September.** Light pace around AWS SAA exam preparation, which takes priority. Target is Phase 0 complete and Phase 1 started or complete.

**After 25 September.** Full focus once SAA is sat. Target is the project substantially complete by the first week of October 2026.

Polishing, meaning README depth, diagram quality, and the CloudWatch stretch goal, can continue past that date without pressure.

## Certification context

RHCSA has been scoped out. The Linux content here is real applied administration work, not exam preparation. Current roadmap: AWS SAA on 25 September 2026, then Terraform in December 2026, then CKA in Q2 2027.

## Working method

- Problem first. Each concept is posed as a question before any solution is shown.
- I attempt first. Code and output get reacted to rather than handed over.
- Boilerplate with no learning value, such as provider block syntax, can be given directly.
- Every non-trivial decision gets logged as it happens, in `bastion-decision-log.md`. That log feeds this project's final README.
- The bar for "learned enough" is being able to explain what a component does and why it was chosen, not full mastery.

## Repository

`secure-bastion-gateway`. Public, because the repository is the portfolio artifact.
