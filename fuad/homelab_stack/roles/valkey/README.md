# Ansible Valkey Role

An Ansible role for preparing and deploying **Valkey** in an offline environment.

This repository is a Galaxy-compatible Ansible role. The role content lives at the repo root so it can be installed directly via `ansible-galaxy role install`. Example playbooks are in `playbooks/`.

---

## Features

- Pull the pinned Valkey image (`linux/amd64`) and save it as a tar archive on the controller
- Sign the image archive with GPG and verify the signature on the target
- Load the image and start Valkey with Docker Compose, fully offline (no internet access needed on the target)
- Create the Docker network and deploy directory on the target
- Modular task structure (prep vs deploy)

---

## How It Works

```text
Controller (internet)                         Target (offline)
┌──────────────────────────┐                  ┌──────────────────────────────┐
│ prep.yml                 │                  │ deploy.yml                   │
│ 1. Pull Valkey image     │   files/         │ 1. Create network + dirs     │
│ 2. Save image to .tar    │ ───────────────► │ 2. Copy .tar, .asc, key      │
│ 3. Generate GPG key,     │  valkey_assets   │ 3. Verify GPG signature      │
│    sign the .tar         │                  │ 4. Load image from .tar      │
│ 4. Export public key     │                  │ 5. docker compose up -d      │
└──────────────────────────┘                  └──────────────────────────────┘
```

---

## Repository Structure

```text
roles-valkey/                  # Role root (Galaxy-compatible)
├── tasks/                     # Role tasks
│   ├── main.yml               #   Entry point (prep + deploy)
│   ├── prep.yml               #   Prep phase (controller)
│   └── deploy.yml             #   Deploy phase (target hosts)
├── defaults/
│   └── main.yml               #   Default variables
├── vars/
│   └── main.yml               #   Derived/internal variables
├── meta/
│   └── main.yml               #   Galaxy metadata
├── templates/
│   └── valkey-compose.yaml.j2 #   Docker Compose template for Valkey
│
├── molecule/                  # Integration tests
│   └── default/
│       ├── Dockerfile
│       ├── molecule.yml
│       ├── cleanup.yml
│       ├── prepare.yml
│       ├── converge.yml
│       └── verify.yml
├── tests/                     # Validation & mock tests
│   ├── inventory
│   ├── test.yml
│   ├── vars_check.yml         #   Variable validation
│   └── mock_prep.yml          #   Offline prep test
├── playbooks/                 # Example playbooks
│   ├── prep.yml
│   ├── deploy.yml
│   └── site.yml
├── environments/              # User-created (gitignored)
├── files/                     # Staging assets (gitignored)
├── Jenkinsfile                # CI pipeline definition
├── TESTING.md                 # Test suite documentation
├── .ansible-lint
├── .yamllint
├── .gitignore
└── README.md
```

---

## Requirements

- Ansible 2.15 or later
- **Controller:** internet access, Docker Engine (for `docker pull` and `docker save`), and `gpg`
- **Target:** Ubuntu 24.04 (noble) with Python 3, `gpg`, **Docker Engine and the Docker Compose plugin already installed**. No internet access required.

> **Note:** The target needs Docker before this role runs. In an offline environment, install it first with the [`roles-docker`](https://gitea.len-iot.id/ansible/roles-docker) role.

---

## Tasks

### Prep phase (`tasks/prep.yml`, controller)

| Phase     | Task                      | Description                                                                         |
| --------- | ------------------------- | ----------------------------------------------------------------------------------- |
| 1. Pull   | Create staging directory  | Creates `valkey_files_dir` (mode `0755`).                                           |
| 1. Pull   | Pull Valkey images        | Runs `docker pull --platform linux/amd64` for `valkey_image`.                       |
| 2. Save   | Save Valkey images to tar | Writes `valkey-<valkey_version>.tar` (skipped if it already exists).                |
| 3. Sign   | Generate GPG key          | Creates an RSA 4096 signing key for `gpg_key_email` (skipped if it already exists). |
| 3. Sign   | Sign Valkey image tar     | Creates a detached, armored `valkey-<valkey_version>.tar.asc` signature.            |
| 4. Export | Export GPG public key     | Writes `valkey-signing-key.gpg` to the staging directory.                           |

### Deploy phase (`tasks/deploy.yml`, targets)

| Phase            | Task                               | Description                                                                     |
| ---------------- | ---------------------------------- | ------------------------------------------------------------------------------- |
| 1. Prerequisites | Check or create Docker network     | Inspects `docker_network_name` and creates it if missing.                       |
| 1. Prerequisites | Create Valkey deploy directory     | Creates `valkey_deploy_dir`, owned by `ansible_user`.                           |
| 1. Prerequisites | Ensure staging directory exists    | Creates `dest_valkey_files` on the target.                                      |
| 2. Load image    | Check if Valkey tar already exists | Checks whether the tar is already on the target (for example a Molecule mount). |
| 2. Load image    | Copy Valkey assets                 | Copies the `.tar`, `.asc`, and `valkey-signing-key.gpg` to `dest_valkey_files`. |
| 2. Load image    | Import Valkey GPG public key       | Imports `valkey-signing-key.gpg` into the target keyring.                       |
| 2. Load image    | Verify Valkey image tar signature  | Runs `gpg --verify` on the `.tar` with its `.asc`.                              |
| 2. Load image    | Check whether the image is loaded  | Runs `docker image inspect` for `valkey_image`.                                 |
| 2. Load image    | Load Valkey image from tar         | Runs `docker load` only if the image is not loaded yet.                         |
| 3. Deploy        | Copy docker-compose file           | Renders `valkey-compose.yaml.j2` to `valkey_deploy_dir/docker-compose.yaml`.    |
| 3. Deploy        | Start Valkey container             | Runs `docker compose up -d` in `valkey_deploy_dir`.                             |

---

## Role Variables

### Defaults (override in inventory, group_vars, or playbook vars)

| Variable                | Default                                             | Description                                                         |
| ----------------------- | --------------------------------------------------- | ------------------------------------------------------------------- |
| `deploy_user`           | `"nzo"`                                             | User whose home directory holds the Valkey deploy directory.        |
| `valkey_container_name` | `"lab-valkey"`                                      | Name of the Valkey container.                                       |
| `valkey_deploy_dir`     | `"/home/{{ deploy_user }}/valkey"`                  | Deploy directory on the target host.                                |
| `dest_valkey_files`     | `"/tmp/valkey_assets/docker_images"`                | Temporary directory on the target where the image files are copied. |
| `valkey_files_dir`      | `"{{ playbook_dir }}/files/valkey_assets"`          | Directory on the control node where the image assets are staged.    |
| `valkey_templates_dir`  | `"{{ playbook_dir }}/roles/roles-valkey/templates"` | Directory containing the role templates.                            |
| `docker_network_name`   | `"fuad_network"`                                    | Docker network the container is attached to.                        |
| `valkey_port`           | `6379`                                              | Port exposed by Valkey.                                             |
| `gpg_key_email`         | `"valkey-repo@localhost"`                           | Email identity of the GPG key used for signing.                     |

### Vars (derived; do not override)

| Variable            | Default                                          | Description                                                  |
| ------------------- | ------------------------------------------------ | ------------------------------------------------------------ |
| `valkey_version`    | `"9.1.2"`                                        | Valkey image version.                                        |
| `valkey_base_image` | `"valkey/valkey"`                                | Base image name.                                             |
| `valkey_image`      | `"{{ valkey_base_image }}:{{ valkey_version }}"` | Full image reference, built from the base image and version. |

---

## Configuration

- Inventory: `environments/dev/inventory.yml`
- Extra vars: `environments/dev/manifest.yml` (optional)

---

## Verification

After deployment, check the container on the target:

```bash
docker ps --filter name=cms-valkey
docker exec cms-valkey valkey-cli ping   # expected: PONG
```

---

## Version

| Version | Description                                |
| ------- | ------------------------------------------ |
| v1.0.0  | Initial release. Galaxy-compatible layout. |

---

## Testing

See [TESTING.md](TESTING.md) for the full test suite documentation.

**Quick run:**

```bash
pip install ansible-lint yamllint
ansible-lint --nocolor
yamllint -c .yamllint .
ansible-playbook tests/vars_check.yml
ansible-playbook tests/mock_prep.yml
```

**Test layers:**

| Layer     | Command                                 | What it verifies                |
| --------- | --------------------------------------- | ------------------------------- |
| Lint      | `ansible-lint --nocolor`                | Code quality, best practices    |
| Variables | `ansible-playbook tests/vars_check.yml` | All vars resolve, correct types |
| Mock Prep | `ansible-playbook tests/mock_prep.yml`  | Staging layout (offline)        |
| Molecule  | `molecule test`                         | Full deploy in Docker container |

**CI:** Jenkins pipeline defined in `Jenkinsfile`.

---

## License

GPL-3.0-only — see `meta/main.yml`.

---

## Author

**Fuad Grimaldi**
