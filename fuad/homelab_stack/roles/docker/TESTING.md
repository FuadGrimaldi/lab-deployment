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

| Assertion            | Details                                                                                                      |
| -------------------- | ------------------------------------------------------------------------------------------------------------ |
| Required variables   | All role variables are defined; the path, user, network, email, and OS variables are also non-empty.         |
| OS consistency       | `target_os_release` is `noble`, `jammy`, `focal`, or `bionic` and matches `target_os_version`.               |
| Package versions     | `docker_version`, `containerd_version`, `buildx_version`, and `compose_version` follow the `X.Y.Z-N` format. |
| Repo URL             | `docker_repo_base` is a valid Docker pool URL for the selected release, with no unrendered `{{ }}`.          |
| `docker_deb_files`   | Exactly 5 unique `.deb` entries, each package appears once with its matching version, all rendered.          |
| `docker_system_deps` | Non-empty list with no duplicates and valid package names.                                                   |
| Paths                | `dest_docker_files` and `dest_docker_file_tmp` are absolute and different from each other.                   |
| Identity             | `gpg_key_email`, and `docker_network_name` have a valid format.                                              |

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

| Step               | Description                                                                                                                |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| OS consistency     | `target_os_release` matches `target_os_version`.                                                                           |
| `docker_deb_files` | 5 entries, all `_amd64.deb`, 4 with the correct `~ubuntu.<version>~<release>` suffix, `containerd.io` matches its version. |
| Repo URL           | `docker_repo_base` contains the configured `target_os_release`.                                                            |
| Staging directory  | `dest_docker_files` is created with mode `0755` under a mock root (`/tmp/docker_role_mock`).                               |
| Mock artifacts     | Empty `.deb`, `.asc`, and `docker-signing-key.gpg` files are created for every entry in `docker_deb_files`.                |
| Staged layout      | Each `.deb` has a matching `.asc`, and the signing key exists.                                                             |
| Cleanup            | The mock root is always removed, even if a check fails.                                                                    |

**Run:**

```bash
ansible-playbook tests/mock_prep.yml
```

---

### Layer 4 — Molecule Integration Test

**Purpose:** Full integration test of the deploy phase inside a Docker container running Ubuntu Noble. Validates the complete deploy pipeline: Docker network setup, docker-cli installation, SeaweedFS container deployment, and S3 API/bucket verification.

**File:** `molecule/default/`

**Scenario files:**

| File           | Role                                                                                                                                              |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `molecule.yml` | Docker driver config, Ubuntu noble image, inventory host vars (deploy dir, ports, credentials, network name)                                      |
| `prepare.yml`  | Prepares the Ubuntu test container and installs the prerequisites required by the integration test                                                |
| `converge.yml` | Fixes `/tmp` permissions, overrides the staging paths to `/tmp/docker_assets` and `/tmp/docker_debs`, then runs the role's `tasks/deploy.yml`     |
| `verify.yml`   | Checks that `docker-ce` and `containerd.io` are installed, the Docker CLI, Compose, and Buildx respond, and the CLI plugins directory exists      |
| `cleanup.yml`  | On the control node, removes `/tmp/docker_assets`, the `ubuntu:noble` and `molecule_local/ubuntu:noble` images, and the generated GPG signing key |

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

The `Jenkinsfile` defines the pipeline. A container agent is used with the host Docker socket mounted for molecule.

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
