# Testing

This document describes the test suite for the Seaweedfs Ansible role.

---

## Quick Start

Install test dependencies:

```bash
pip install ansible-lint yamllint molecule "molecule-plugins[docker]"
```

Run all tests locally:

```bash
# 1. Lint & syntax
yamllint -c .yamllint .
ansible-lint --nocolor
ansible-playbook playbooks/prep.yml --syntax-check
ansible-playbook playbooks/deploy.yml --syntax-check
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook tests/vars_check.yml --syntax-check
ansible-playbook tests/mock_prep.yml --syntax-check
ansible-playbook tests/test.yml --syntax-check

# 2. Variable validation
ansible-playbook tests/vars_check.yml

# 3. Mock prep (offline, no downloads)
ansible-playbook tests/mock_prep.yml

# 4. Molecule integration (requires Docker)
molecule test
```

---

## Test Layers

### Layer 1 — Lint & Syntax Check

**Purpose:** Ensure all YAML and Ansible files follow best practices and parse correctly.

**Tools:**

- `yamllint` — YAML formatting and style checks
- `ansible-lint` — Ansible-specific best-practice rules
- `ansible-playbook --syntax-check` — validates playbook structure

**Config:**

- `.yamllint` — line length 120, 2-space indent, required document start
- `.ansible-lint` — production profile, excludes molecule/ and test inventory

**Run:**

```bash
yamllint -c .yamllint .
ansible-lint --nocolor
```

---

### Layer 2 — Variable Validation

**Purpose:** Verify all role variables resolve correctly with expected types, formats, and values. Catches misconfigured defaults, missing derived variables, and version format issues before deployment.

**File:** `tests/vars_check.yml`

**What it checks:**

| Assertion          | Details                                                                                                                   |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| Required variables | All variables from `defaults/main.yml` are defined; all are also non-empty except `valkey_port`.                          |
| Derived variables  | `valkey_base_image` and `valkey_image` are defined, and `valkey_image` contains both the base image and `valkey_version`. |
| Version format     | `valkey_version` follows the `X.Y.Z` format.                                                                              |
| Port               | `valkey_port` is an integer between 1 and 65535.                                                                          |
| Deploy directory   | `valkey_deploy_dir` is an absolute path and contains `deploy_user`.                                                       |

**Run:**

```bash
ansible-playbook tests/vars_check.yml
```

**Output:** Each assertion prints `PASS: ...` on success or `CRITICAL: ...` on failure.

---

### Layer 3 — Mock Prep Test

**Purpose:** Validate the prep phase staging directory layout without needing internet access. Creates mock source tarballs (empty placeholders) and verifies the expected directory structure.

**File:** `tests/mock_prep.yml`

**What it checks:**

| Step              | Description                                                                                          |
| ----------------- | ---------------------------------------------------------------------------------------------------- |
| Staging directory | `docker_images` is created under `files/test_assets` with mode `0755`, and it exists as a directory. |
| Mock tarball      | An empty `valkey_<valkey_version>.tar` is created in the staging directory and verified to exist.    |
| Cleanup           | `files/test_assets` is removed in `post_tasks`.                                                      |

**Run:**

```bash
ansible-playbook tests/mock_prep.yml
```

---

### Layer 4 — Molecule Integration Test

**Purpose:** Full integration test of the deploy phase inside a Docker container running Ubuntu Noble. Validates the complete deploy pipeline: Docker network setup, docker-cli installation, SeaweedFS container deployment, and S3 API/bucket verification.

**File:** `molecule/default/`

**Scenario files:**

| File           | Role                                                                                                                                                                  |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `molecule.yml` | Docker driver config, Ubuntu noble image, inventory host vars (deploy dir, ports, credentials, network name)                                                          |
| `prepare.yml`  | Prepares the Ubuntu test container and installs the prerequisites required by the integration test                                                                    |
| `converge.yml` | Installs docker-cli (sibling-container pattern), creates/connects the Molecule instance to the CMS Docker network, then runs `tasks/deploy.yml` against the container |
| `verify.yml`   | Asserts: `lab-valkey` container is running                                                                                                                            |
| `cleanup.yml`  | Removes the `lab-valkey` test container, the Molecule test network and the test deployment directory                                                                  |

**Run:**

```bash
molecule test
```

**Notes:**

- Requires Docker daemon access (`/var/run/docker.sock`)
- Downloads packages from the internet during `prepare.yml` (container has network access)
- Runs on `localhost` — controller and target are the same container
- Runtime: ~2-5 minutes

---

## CI Pipeline (Jenkins)

The `Jenkinsfile` defines the pipeline. A `python:3.12` container agent is used with the host Docker socket mounted for molecule.

**Stages:**

```text
Install Dependencies → Lint & Syntax → Variable Validation → Mock Prep → Molecule
```

| Stage               | Condition                                          | Runtime |
| ------------------- | -------------------------------------------------- | ------- |
| Lint & Syntax       | Always                                             | < 30s   |
| Variable Validation | Always                                             | < 5s    |
| Mock Prep           | Always                                             | < 5s    |
| Molecule            | `development` branch only, Docker daemon available | ~5 min  |

---
