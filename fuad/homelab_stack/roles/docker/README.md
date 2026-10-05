# Ansible Docker Role

An Ansible role for preparing and deploying **Docker** in an offline environment.

This repository is a Galaxy-compatible Ansible role. The role content lives at the repo root so it can be installed directly via `ansible-galaxy role install`. Example playbooks are in `playbooks/`.

---

## Features

- Download pinned Docker `.deb` packages and their system dependencies on the controller
- Sign every package with GPG and verify the signatures on the target
- Install Docker fully offline on target Ubuntu hosts (no internet access needed on the target)
- Modular task structure (prep vs deploy)
- Supported Ubuntu releases: `noble` (24.04), `jammy` (22.04), `focal` (20.04), `bionic` (18.04)

---

## How It Works

```text
Controller (internet)                         Target (offline)
┌──────────────────────────┐                  ┌──────────────────────────────┐
│ prep.yml                 │                  │ deploy.yml                   │
│ 1. Download .deb + deps  │   files/         │ 1. Copy .deb, .asc, key      │
│ 2. Generate GPG key      │ ───────────────► │ 2. Verify GPG signatures     │
│ 3. Sign packages         │  docker_assets   │ 3. Install with dpkg         │
│ 4. Export public key     │                  │ 4. Start Docker, set group   │
└──────────────────────────┘                  └──────────────────────────────┘
```

---

## Repository Structure

```text
roles-docker/                  # Role root (Galaxy-compatible)
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
- **Controller:** Ubuntu/Debian with internet access, `gpg`, and `apt` tools (`apt-cache`, `apt-get download`)
- **Target:** Ubuntu (see supported releases above) with Python 3. No internet access required.

> **Note:** System dependencies are resolved with `apt-cache` on the controller, so the controller should run the **same Ubuntu release** as the target. Otherwise the downloaded dependency versions may not match the target.

---

## Tasks

### Prep phase (`tasks/prep.yml`, controller)

| Phase       | Task                           | Description                                                                           |
| ----------- | ------------------------------ | ------------------------------------------------------------------------------------- |
| 1. Staging  | Create local staging directory | Creates `dest_docker_files` (mode `0755`).                                            |
| 2. Download | Download offline packages      | Downloads the 5 Docker `.deb` files from `docker_repo_base`.                          |
| 2. Download | Resolve full dependency list   | Resolves the recursive dependencies of `docker_system_deps` with `apt-cache depends`. |
| 2. Download | Download system dependencies   | Downloads the resolved packages with `apt-get download`.                              |
| 3. GPG key  | Generate GPG key               | Creates an RSA 4096 signing key for `gpg_key_email` (skipped if it already exists).   |
| 4. Signing  | Sign all staged packages       | Creates a detached, armored `.asc` signature for every `.deb`.                        |
| 5. Export   | Export public key              | Writes `docker-signing-key.gpg` to the staging directory.                             |

### Deploy phase (`tasks/deploy.yml`, targets)

| Phase       | Task                                     | Description                                                 |
| ----------- | ---------------------------------------- | ----------------------------------------------------------- |
| 1. Transfer | Create staging directory                 | Creates `dest_docker_file_tmp` on the target.               |
| 1. Transfer | Transfer `.deb`, `.asc`, and signing key | Copies all staged assets to the target.                     |
| 2. Verify   | Import Docker GPG public key             | Imports `docker-signing-key.gpg` into the target keyring.   |
| 2. Verify   | Verify Docker package signatures         | Runs `gpg --verify` for each package in `docker_deb_files`. |
| 3. Install  | Check installed docker-ce version        | Reads the currently installed `docker-ce` version, if any.  |
| 3. Install  | Install all packages                     | Installs every staged `.deb` with `dpkg -i`.                |
| 3. Install  | Configure pending packages               | Runs `dpkg --configure -a`.                                 |
| 4. Service  | Ensure docker group exists               | Creates the `docker` system group.                          |
| 4. Service  | Start Docker service                     | Starts and enables the `docker` service.                    |
| 4. Service  | Add user to docker group                 | Adds `ansible_user` to the `docker` group.                  |

---

## Role Variables

### Defaults (override in inventory, group_vars, or playbook vars)

| Variable               | Default                                    | Description                                                                                      |
| ---------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| `gpg_key_email`        | `"docker-repo@localhost"`                  | Email identity of the GPG key used to sign the local Docker repository.                          |
| `dest_docker_files`    | `"{{ playbook_dir }}/files/docker_assets"` | Directory on the control node where the downloaded `.deb` packages are stored.                   |
| `dest_docker_file_tmp` | `"/tmp/docker_debs"`                       | Temporary directory on the target host where the `.deb` packages are copied before installation. |

### Vars (derived; do not override)

| Variable             | Default                                                                                      | Description                                                                                                                                                                                           |
| -------------------- | -------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `target_os_release`  | `"jammy"`                                                                                    | Ubuntu codename of the target host (`noble`, `jammy`, `focal`, `bionic`). Used in the download URL and package filenames.                                                                             |
| `target_os_version`  | `"22.04"`                                                                                    | Ubuntu version of the target host (`24.04`, `22.04`, `20.04`, `18.04`). Must match `target_os_release`.                                                                                               |
| `docker_version`     | `"29.2.1-1"`                                                                                 | Version of `docker-ce` and `docker-ce-cli`.                                                                                                                                                           |
| `containerd_version` | `"1.7.27-1"`                                                                                 | Version of `containerd.io`.                                                                                                                                                                           |
| `buildx_version`     | `"0.31.1-1"`                                                                                 | Version of `docker-buildx-plugin`.                                                                                                                                                                    |
| `compose_version`    | `"5.0.2-1"`                                                                                  | Version of `docker-compose-plugin`.                                                                                                                                                                   |
| `docker_repo_base`   | `"https://download.docker.com/linux/ubuntu/dists/{{ target_os_release }}/pool/stable/amd64"` | Base URL of the official Docker package pool that the `.deb` files are downloaded from.                                                                                                               |
| `docker_deb_files`   | _(list of 5 packages)_                                                                       | Filenames of the `.deb` packages to download and install: `containerd.io`, `docker-ce-cli`, `docker-ce`, `docker-buildx-plugin`, and `docker-compose-plugin`, built from the version variables above. |
| `docker_system_deps` | `pigz`, `iptables`, `nftables`, `libnftables1`                                               | System packages required by Docker, installed before the Docker packages.                                                                                                                             |

---

## Verification

After deployment, check the installation on the target:

```bash
docker --version
docker compose version
docker buildx version
systemctl status docker
```

The user in `ansible_user` must log out and back in before the `docker` group membership takes effect.

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
