# DPN Public Repository Security Baseline

**Repository:** DPN-QB-FiveM-Scripts  
**Organization:** DPN Technology  
**Created by:** Diesel, CEO of DPN Technology

This repository is intentionally public. Public means the source can be viewed, cloned, forked, and downloaded by anyone.

The goal of this security baseline is therefore to protect:

- The integrity of the official DPN Technology repository
- Credentials and private configuration
- The GitHub Actions supply chain
- Release-package integrity
- DPN release metadata
- The official main branch
- Contributors from accidentally publishing secrets

It cannot make public source code private.

## Current Repository-Side Controls

The repository contains:

- DPN Quality Gate
- Automated secret-pattern checks
- Blocked credential/private-key filenames
- Immutable SHA pinning for third-party GitHub Actions
- Restricted workflow permissions
- Prohibition on `pull_request_target`
- Prohibition on `permissions: write-all`
- Prohibition on unapproved OIDC token issuance
- Automatic DPN resource metadata validation
- Symlink rejection for release packages
- Versioned release ZIP creation
- SHA-256 checksum generation for release ZIPs
- CODEOWNERS
- Security policy
- Dependabot for GitHub Actions
- Weekly repository validation
- Automatic script indexing

## GitHub Settings That Must Be Enabled Outside the Repository Files

These protections are controlled by GitHub repository settings and cannot be enabled by repository files alone.

### 1. Protect the Default Branch

Create an active branch ruleset for the default branch `main`.

Recommended rules:

- Require a pull request before merging
- Require status checks before merging
- Require **Validate DPN Resource Standards**
- Require conversation resolution
- Block force pushes
- Block branch deletion
- Require branches to be up to date before merging if practical

If Diesel is the only maintainer, requiring one approving review can create an unnecessary lockout. Use zero required approvals until a second trusted maintainer exists, then consider one required approval.

### 2. Enable Repository Push Protection

In GitHub security settings, enable repository-level secret push protection if available.

This adds a GitHub-side block before a detected credential enters repository history.

### 3. Review Secret Scanning Alerts

Public GitHub repositories receive GitHub secret scanning. Treat any alert as urgent:

1. Revoke/rotate the credential.
2. Remove it from the current files.
3. Remove it from Git history when appropriate.
4. Verify no unauthorized use occurred.

Deleting a secret from the latest commit is not enough if the secret remains valid in history.

### 4. Keep Write Access Minimal

Only trusted DPN Technology maintainers should have write/admin access.

Do not grant write permission merely so someone can contribute. External contributors can use forks and pull requests.

### 5. Account Security

Repository security depends on the owner account.

Recommended:

- Enable strong two-factor authentication
- Prefer passkeys/security keys
- Review authorized GitHub Apps
- Remove unused personal access tokens
- Use least-privilege tokens
- Keep recovery methods current

## Public Release Rule

Never publish:

- Discord bot tokens
- Webhook secrets
- API keys
- Database credentials
- FiveM server license keys
- SSH/private keys
- Production `server.cfg`
- Private admin identifiers that should remain confidential
- Paid/private-only DPN source
- Proprietary infrastructure configuration

## Pre-Release Decision

A DPN script is ready for the public repository only when:

- It is intentionally free/source-available
- No secret is required in the committed source
- Any required secret is supplied externally by the server owner
- DPN Quality Gate passes
- The script has DPN metadata and documentation
- Release packaging succeeds
- The release checksum is generated
- The code is safe to be permanently public

Once source has been pushed to a public repository, assume copies may exist permanently even if the file is later deleted.

---

**DPN Technology — Develop Pioneer Navigate**

*We Develop what doesn't exist. We Pioneer what comes next. We Navigate the future.*
