# Secure Bastion Gateway: Decision Log

This log records every non-trivial decision made while building the project, along with the reasoning behind it and the options that were rejected. It is written as the work happens rather than reconstructed afterwards, because the reasoning is the part that gets lost first.

The log feeds the final README. Entries here are the raw material; the README is the distilled version.

**Entry format:** what was decided, why, what was rejected, and any caveat worth carrying forward.

---

## Phase 0: Setup and Account Check

### D-001: Sequence the setup tasks around the billing gate

Phase 0 has five tasks. I ordered them as: create the AWS account, set up billing alerts, then install Terraform and create the GitHub repo in parallel with either.

Account creation has to come first because alert thresholds only make sense once the account's pricing model is known. Billing alerts then act as a hard gate, meaning nothing that provisions real AWS resources happens until they are live. Terraform installation and repo creation touch no AWS resources at all, so they carry no dependency and can happen at any point.

**Caveat worth holding onto:** the gate is "alerts confirmed live," not "alerts created." An alert I have not verified is worse than no alert, because I would proceed as though I were covered.

---

### D-002: The free tier cutoff date is not a complete eligibility test

The project blueprint framed free tier eligibility as a binary: accounts created before 15 July 2025 get the legacy model of 750 hours per month for 12 months, accounts created after get the credit pool model.

That binary is incomplete. The legacy 12 month window runs from the account creation date, so an account can sit on the correct side of the cutoff and still have the window expired. "Created before the cutoff" and "currently has an active free tier" are two different claims.

This does not affect the project, since the account was created in September 2026 and lands unambiguously on the credit pool model. I am recording it because it is the kind of distinction AWS SAA tests, and because it will matter if I ever inherit an account someone else created.

---

### D-003: Paid Plan over Free Plan

AWS offers two plans at signup. I chose Paid.

**Free Plan** closes the account automatically 6 months after opening, or once the credits run out, whichever comes first. I know this holds because a previous account of mine was closed by exactly that mechanism. The closure notice also confirmed that the email address on the account can never be used to create another AWS account, so the cost of that closure was permanent.

**Paid Plan** applies credits first, then rolls into standard pay-as-you-go pricing. The account does not close on its own.

Both plans advertise the same "up to $200 in credits," so credits were never the deciding factor. The only meaningful difference is what happens when the balance reaches zero: Free Plan deletes the account, Paid Plan starts charging.

**Trade-off accepted:** the account can now generate real charges. That is exactly why billing alerts are treated as a hard gate rather than a nice-to-have. A chargeable account with working alerts is a better position than a free account that deletes itself and the project with it.

---

### D-004: Credits arrive in two halves, not one

This is an observation rather than a decision, but it changed how I sized the budget thresholds so it belongs here.

The advertised $200 is split. $100 is granted automatically at signup. The remaining $100 has to be earned by completing onboarding activities inside the console.

**Current state:** $100 active, $0 used, expiring 09/03/2027. The expiry sits twelve months out from account creation and well past the project deadline of early October 2026, so it does not constrain anything.

Worth noting: the previously closed account did not block credit eligibility on the new one.

---

### D-005: AWS Budgets over CloudWatch billing alarm

AWS provides two ways to get emailed about spending. I chose AWS Budgets.

Budgets can alert on **forecasted** spend, meaning it reads the current burn rate and warns that I am on track to cross a threshold before I actually cross it. The entire point of these alerts is warning room, so forecasting is the capability that decides it.

**Rejected: CloudWatch billing alarm.** It only fires on spend already incurred, which gives no lead time. It also carries a trap that catches people regularly: the billing metric exists only in us-east-1, so an alarm created in any other region silently monitors nothing while appearing to be configured correctly.

---

### D-006: Two thresholds at $5 and $15

$5 means investigate. $15 means escalate.

With `terraform destroy` run at the end of every session, this project should cost single digit dollars in total. A couple of t3.micro instances running for a few hours at a time comes to a few dollars across the whole build. That cost profile is what makes $5 meaningful: it is not a milestone I am working towards, it is a smoke alarm. If $5 of usage appears, something has been left running.

$15 is not a second milestone either. It means my response to the $5 alert did not happen. The first alert watches the account. The second watches me.

**Rejected: the blueprint's original $20 and $50.** Those numbers were sized against a $200 pool. With $100 in credits and a project that should stay under $5, a $20 alert would let me burn a fifth of the balance before saying anything.

**Standard I am holding myself to:** both alerts firing is a failure. Neither should ever fire. $5 must not quietly become normal.

**Transferable concept:** layered alerting with escalating severity, a warning level and a critical level, is a general monitoring pattern rather than budget housekeeping. The same structure returns in Phase 6 when I set CloudWatch alarms on the bastion.

---

### D-007: The budget has to track usage, not charges

The budget needs to count what I consume and ignore the credits that pay for it. In the AWS console this is configured as a scope filter of `Charge type Includes Usage`.

The reasoning is a failure mode rather than a preference. If the budget tracks what I am actually charged, credits absorb everything and the budget reads $0.00 for as long as credits last. A forgotten instance burning $5 a week would show $0, then $0, then $0, while the balance quietly drains. An alert that stays silent for the entire duration of the project is an alert with the battery removed.

**Console detail:** charge types have moved. They are no longer under Advanced options. The path is now Scope options, then Filter specific AWS cost dimensions, then Dimension set to Charge type, then Values set to Usage.

**Related setting:** I left "Aggregate costs by" on **Unblended costs**. The Net variants, Net unblended and Net amortized, subtract credits and discounts automatically, which is precisely the behaviour this entry exists to avoid.

---

### D-008: Charge type filter deferred until real usage data exists

**Status: deferred, revisit after Phase 2.**

The charge type Values dropdown returns `DataUnavailableException` and lists nothing. I first assumed this was the documented 24 hour delay for a new account and retried after roughly 10 hours, with the same result.

The real cause is not elapsed time. The account has no resources running, so there is no cost data from which AWS can build a list of charge types. Waiting longer changes nothing while the account stays empty. It is a chicken and egg problem: the filter needs usage data, and usage data needs a provisioned resource.

Both budgets were therefore created with scope set to All AWS services and no charge type filter.

**Exposure this leaves.** As configured, both budgets track charges after credits are applied. While the $100 balance lasts they will read $0.00 and stay silent, which is the exact blind spot described in D-007. They are not worthless, since they catch anything credits do not cover and they confirm the notification path works, but they are not yet the alert I intended.

**Why I opened the gate anyway.** Phase 1 provisions VPC layer resources, which are free, so there is nothing for the filter to catch. Maximum exposure is capped at $100 because the account cannot bill past credits until they are exhausted, and $100 buys a very large number of t3.micro hours. The real protection was never the alert, it is the destroy ritual described in D-010. And a manual monitor already exists that I had been overlooking: Billing, then Credits, then "Total amount used." That figure rises whether or not credits absorb the charge, so it reflects genuine burn even while the budgets read zero.

**Action required:** add `Charge type Includes Usage` to both budgets immediately after Phase 2, once the bastion has run long enough to generate usage data.

**Interim habit:** check the Credits page at the end of each session alongside running `terraform destroy`.

---

### D-009: No budget actions attached

Both alerts show "0 actions attached" deliberately.

Budget actions automate a response when a threshold is crossed, such as applying a restrictive IAM policy or stopping instances. I want an email and my own judgement instead. On a learning project with thresholds set deliberately low, an automated action could tear down work mid session over a number I chose to be conservative.

---

### D-010: If it is not in Terraform, it does not exist

No resource gets created by clicking through the console, including throwaway tests.

`terraform destroy` only removes what is recorded in Terraform's state file. It is not a general purpose "delete everything" command, and it walks straight past several things:

- Anything created by hand in the console, because Terraform has no record of it
- Anything orphaned by a lost or corrupted state file, which keeps running while Terraform forgets it exists
- Manually created EBS snapshots, Elastic IPs allocated outside Terraform, and S3 buckets still containing objects, which are the usual zombie chargers

The blueprint already required everything to be reproducible rather than console clicked, framed as a code quality principle. This entry reframes it as cost safety, because console created resources are exactly what the destroy ritual misses.

**Belt and braces:** after `terraform destroy`, check the EC2 console is empty. It takes ten seconds and catches what state drift would hide.

---

### D-011: Region set to ap-south-1 (Mumbai)

Three factors pull on region choice: latency, per hour pricing which varies between regions, and availability of instance types and services.

I weighted latency highest. Phases 2 through 5 involve long SSH sessions into the bastion, and terminal responsiveness over hours of work matters more than a fractional price difference on a t3.micro. Mumbai is the closest region to me in Ghaziabad.

**The complication:** I expect to be in the UK later for interviews and related work, which initially looked like an argument for choosing a European region now.

**Why it is not.** This project destroys everything at the end of each session and redeploys from scratch. There is no long lived data, nothing pinned to a location, and the region will be a Terraform variable rather than a hardcoded string. Changing region later means editing one default value and running apply again.

**Two things that are genuinely region scoped and will break on a move if handled carelessly:**

- **AMI IDs differ per region.** The identifier for a given image in Mumbai is a different string in London. Hardcoding one guarantees a failure after a region change. This gets handled properly in Phase 2.
- **EC2 key pairs are per region.** The key pair exists in one region only, so a move requires creating a new one.

---

### D-012: Terraform installed inside WSL, not on Windows

The laptop runs Windows with WSL 2 and Ubuntu already installed. Terraform went into WSL.

Terraform itself runs equally well on either. The decision is about everything surrounding it. From Phase 2 onward the work involves SSH sessions, bash hardening scripts, WireGuard key generation, Linux config file editing, and the SSH jump host pattern. All of that is native on Linux and awkward on Windows, where bash scripts do not run and SSH key file permissions behave differently enough to cause failures.

WSL also avoids the dual boot problem of rebooting to switch between the AWS console and a terminal, which adds friction to every session.

**Installed via the HashiCorp apt repository rather than a downloaded binary.** Confirmed working: `terraform version` returns v1.16.1 on linux_amd64.

**Working directory note:** project files live in the Linux home directory, not under `/mnt/c/`. Crossing the WSL and Windows filesystem boundary is noticeably slower, and file permissions translate imperfectly, which matters later when SSH refuses to use a key file with permissions it considers too open.

**Package management detail worth understanding rather than pasting.** The install adds HashiCorp's GPG key, then registers their repository with a `signed-by` reference to that key. This tells apt to trust packages from the repository only when signed with that specific key, which is how Linux package management prevents tampering in transit. The same trust model reappears in Phase 3 during bastion hardening.

---

### D-013: Repository public, with a Terraform .gitignore from the start

The repository `secure-bastion-gateway` was created as public with GitHub's Terraform `.gitignore` template applied at creation.

Public because the repository is the portfolio artifact. A private repository proves nothing to anyone reading a CV.

The `.gitignore` matters more than it appears. Terraform generates local files that must never reach a public repository:

- `terraform.tfstate`, which records everything Terraform has provisioned and routinely contains sensitive values in plain text
- `.terraform/`, which holds hundreds of megabytes of downloaded provider binaries
- `*.tfvars`, which is where variable values such as a home IP address or credentials typically live

Applying the template at creation means it is in place before the first `.tf` file exists. Adding it after a state file has already been committed is a considerably worse problem, because git history retains the file even after deletion.

---

## Outstanding items: Phase 0

- [ ] Upload blueprint, execution plan, and this log to the repository under `docs/`
- [ ] Add `Charge type Includes Usage` to both budgets, deferred per D-008 until after Phase 2
- [ ] Confirm budget alert emails arrive, checking spam since AWS budget notifications land there routinely
- [ ] Update `bastion-vpn-blueprint.md`: thresholds are $5 and $15, not $20 and $50
- [ ] Fix stale reference in execution plan: Phase 6 status line still cites an end of November deadline
- [ ] Fix stale reference in execution plan: Phase 5 cost safety still cites the 750 hours per month legacy model, which does not apply to this account

---

## Phase 1: VPC Design

Not started.
