# Secure Bastion Gateway: Phased Execution Plan

Companion to `bastion-vpn-blueprint.md`, which holds the architecture reasoning and cost model. This document breaks the build into phases, each scoped so it can be carried into a fresh session without losing context.

Decisions made during any phase go into `bastion-decision-log.md` as they happen.

## How to use this document

Each phase is self-contained. Update the status line as work completes so this reflects real progress rather than the original plan.

**Working method, applies to every phase:**

- The next task is posed as a question before any solution is shown
- I attempt first; code and output get reacted to rather than written for me
- Boilerplate with no learning value can be given directly
- Every non-trivial decision gets logged as it happens
- Cost safety is checked at every phase that touches real AWS resources

---

## Phase 0: Setup and Account Check

**Status:** Complete except for the repository upload.

**Goal:** Confirm environment and account state before building anything.

**Tasks:**

1. Create the AWS account. Paid Plan, not Free Plan. See D-003.
2. Set up billing alerts at $5 and $15, forecasted. This is a hard gate.
3. Install Terraform and confirm `terraform version` works.
4. Create the GitHub repository with a Terraform `.gitignore` applied at creation.
5. Decide the region.

**Sequence:** Account creation must precede billing alerts, because thresholds depend on knowing the account's pricing model. Terraform installation and repository creation depend on neither and can happen at any point.

**Outcome:** Account on Paid Plan with $100 credits. Both budgets live. Terraform v1.16.1 running in WSL. Repository created and public. Region set to ap-south-1.

**Carried forward:** The charge type budget filter could not be applied because a new account has no cost data to populate it. Deferred until after Phase 2. See D-008.

---

## Phase 1: VPC Design

**Status:** Not started.

**Goal:** Build the network foundation. Every later decision, including where the bastion sits and what is exposed, depends on this.

**Concepts:**

- What a VPC is and why it is the outer container
- CIDR blocks and how to size a VPC and its subnets
- The mechanical difference between a public and private subnet, which is whether the route table points at an Internet Gateway
- Route tables and how they control what a subnet can reach
- Internet Gateway versus NAT instance, and when each is needed

**Cost safety:** The VPC itself is free. The only risk is accidentally provisioning a managed NAT Gateway instead of a NAT instance. Check the Terraform resource type before applying.


**Open question to settle this phase:** where Terraform state lives. State starts local by default, which is fine for a single operator but breaks as soon as a second person runs apply, because there is nothing preventing two people writing state at the same time. The alternative is a remote backend, typically S3 with a DynamoDB table for locking. Decide which this project uses and record why, since the trade-off is a standard interview question.

**Deliverable:** Terraform code provisioning a VPC with at least one public and one private subnet, correctly routed. Nothing running inside it yet.

---

## Phase 2: Bastion Host Provisioning

**Status:** Not started.

**Goal:** Launch the bastion EC2 instance into the public subnet.

**Concepts:**

- EC2 instance types and why t3.micro
- Security groups, and how they differ from subnet level controls
- SSH key pairs, generated and used from the start, with no password auth
- Auto-assign public IP, enabled for the bastion only
- AMI IDs are region specific, so they must not be hardcoded. See D-011.

**Cost safety:** Confirm the instance type before applying. Run `terraform destroy` at the end of the session once the instance is confirmed reachable.

**Deliverable:** A reachable EC2 instance in the public subnet with SSH key-only access confirmed working.

**Follow-up due this phase:** Once the bastion has generated usage data, add the `Charge type Includes Usage` filter to both budgets. This closes D-008.

---

## Phase 3: Bastion Hardening

**Status:** Not started.

**Goal:** Turn a reachable EC2 box into a hardened entry point. This is the heaviest Linux phase.

**Concepts:**

- SELinux: enforcing versus permissive versus disabled, and configuring it properly rather than switching it off
- firewalld: rules scoped to exactly what is needed
- SSH hardening: password auth disabled, root login disabled, port change considered with trade-offs discussed, fail2ban or equivalent
- systemd: starting, enabling, and checking service status and logs

**Cost safety:** No new resources, only configuration on the existing instance. The destroy habit still applies.

**Deliverable:** A bastion with SELinux enforcing, firewalld scoped tightly, and SSH hardened, with the reasoning behind each rule logged.

---

## Phase 4: VPN Layer (WireGuard)

**Status:** Not started.

**Goal:** Install WireGuard on the bastion so access runs through an encrypted tunnel rather than raw SSH exposure.

**Concepts:**

- How WireGuard works: keys, peers, tunnel interface
- Installing and configuring it on the bastion
- Client side configuration, connecting from the laptop
- How this interacts with the Phase 3 firewalld rules, which will need adjusting rather than replacing

**Cost safety:** No additional AWS cost. WireGuard is software on an instance that is already running.

**Deliverable:** A working tunnel. Connect from the laptop via WireGuard and reach the bastion through it.

---

## Phase 5: Private Target Server

**Status:** Not started.

**Goal:** Provision a second EC2 instance in the private subnet, reachable only through the bastion. This is what proves the architecture works end to end rather than just at the entry point.

**Concepts:**

- Provisioning an instance with no public IP
- The SSH jump host pattern, connecting to a private instance via the bastion
- Confirming the private instance is genuinely unreachable from the internet

- **NAT instance.** The private instance needs outbound internet for package updates while remaining unreachable from outside. This is where the NAT instance from the cost-safe architecture table gets built, since this is the first phase where anything actually needs it.
- **Source and destination check.** Every EC2 instance drops packets that are not addressed to it. A NAT instance exists to forward packets addressed elsewhere, so it fails silently until this check is disabled. Expect to hit this.

**Cost safety:** Two instances now run at once, so the burn rate roughly doubles. On a $100 credit balance the constraint is total spend rather than a monthly hours quota, since this account is not on the legacy free tier model. Both instances get destroyed at the end of the session.

**Deliverable:** A private instance reachable only via the bastion and confirmed unreachable directly.

---

## Phase 6: CloudWatch Monitoring

**Status:** Not started. Optional stretch goal, attempted only if time allows before the early October target.

**Goal:** Add basic observability. Alarms for bastion health, failed SSH attempts, and VPN connection drops.

**Concepts:**

- CloudWatch metrics and alarms, and what falls inside the free allowance
- What is worth alerting on for a security focused system
- Layered alerting with escalating severity, the same warning and critical structure used for the billing alerts in D-006

**Deliverable:** At least one working CloudWatch alarm on the bastion.

---

## Phase 7: Documentation and Architecture Diagram

**Status:** Not started. Not optional, unlike Phase 6.

**Goal:** Turn the accumulated decision log into the artifact an interviewer actually reads.

**Tasks:**

- Architecture diagram showing how the VPC, subnets, bastion, VPN, and private instance connect
- README explaining every major decision, distilled from the decision log: NAT instance versus NAT Gateway, SELinux choices, security group scoping, bastion plus VPN versus Session Manager, and the single point of failure discussion
- Clean repository structure with no leftover scratch files
- Final `terraform destroy` confirmation, plus README instructions for redeploying from scratch to prove reproducibility

**Deliverable:** The portfolio piece. Repository, diagram, and README, ready to link on a CV or walk through in an interview.

---

## Status tracker

| Phase | Status |
|---|---|
| 0. Setup and Account Check | Complete, repository upload pending |
| 1. VPC Design | Not started |
| 2. Bastion Host Provisioning | Not started |
| 3. Bastion Hardening | Not started |
| 4. VPN Layer (WireGuard) | Not started |
| 5. Private Target Server | Not started |
| 6. CloudWatch (stretch) | Not started |
| 7. Documentation and Diagram | Not started |

**Deadline:** Phases 0 and 1 by 25 September, at light pace around SAA preparation. Phases 2 through 7 by the first week of October, at full focus. Phase 6 optional.
