# Ansible Docker Role

An Ansible role for preparing and deploying **Docker** in an offline environment.

This repository is a Galaxy-compatible Ansible role. The role content lives at the repo root so it can be installed directly via `ansible-galaxy role install`. Example playbooks are in `playbooks/`.

---

## Features

- Prepare Docker installation assets
- Deploy Docker to target Ubuntu 24.04 hosts
- Support fully offline installation
- Modular task structure (prep vs deploy)

---

## Repository Structure

```text
roles-seaweedfs/               # Role root (Galaxy-compatible)
├── tasks/                     # Role tasks
│   ├── main.yml               #   Entry point (prep + deploy)
│   ├── prep.yml               #   Prep phase (controller)
│   └── deploy.yml             #   Deploy phase (target hosts)
├── defaults/
│   └── main.yml               #   Default variables
├── vars/
│   └── main.yml               #   Derived/internal variables
├── handlers/
│   └── main.yml               #   Handlers
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

## Installation

### Provision a Fresh VM with Vagrant

Provision and start a fresh VM before configuring the deploy user:

```bash
vagrant up
vagrant status
```

After provisioning completes, continue with the post-setup steps below.

### Post-Setup: Create Deploy User

If using Vagrant, create the deploy user that Ansible will use to connect:

```bash
# SSH into the VM
vagrant ssh <vm_name>

# Create user and grant sudo
sudo useradd -m -s /bin/bash <username>
sudo passwd <username>
echo "<username> ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/<username>
exit

# Inject your SSH public key from the host (will prompt for password)
ssh-copy-id -i ~/.ssh/<your_key> <username>@<vm_ip>
```

### Connetion for target

Update environments/dev/inventory.yml to match your VM:

```
all:
  children:
    docker_servers:
      hosts:
        <vm_name>:
          ansible_host: <vm_ip>
          ansible_user: <username>
```

Update ansible.cfg:

```
[defaults]
remote_user = <username>
host_key_checking = False
private_key_file = ~/.ssh/<your_key>
roles_path = ./roles
```

### Via Ansible Galaxy (stable release)

​`
ansible-galaxy role install git+https://gitea.len-iot.id/ansible/roles-docker.git,[version]
​`

### Via requirements.yml (stable release)

```
roles:
  - name: roles-docker
    src: https://gitea.len-iot.id/ansible/roles-docker.git
    scm: git
    version: [version]
```

```
ansible-galaxy install -r requirements.yml -p roles/ --force
```

Then in your playbook / site.yml:

```
---
- name: Prep Docker assets
  hosts: localhost
  connection: local
  tasks:
    - name: Run prep tasks
      ansible.builtin.import_role:
        name: roles-docker
        tasks_from: prep

- name: Deploy Docker to targets
  hosts: all
  become: true
  tasks:
    - name: Run deploy tasks
      ansible.builtin.import_role:
        name: roles-docker
        tasks_from: deploy
```

### Tracking development branch (unstable, for testing)

```
roles:

- name: roles-docker
  src: https://gitea.len-iot.id/ansible/roles-docker.git
  version: development
```

### Local Development

```bash
git clone https://gitea.len-iot.id/ansible/roles-docker.git
cd roles-docker
```

Run directly using the bundled playbooks:

```bash
# Preparation (runs on localhost)
ansible-playbook playbooks/prep.yml

# Deployment (targets your inventory)
ansible-playbook -i environments/dev/inventory.yml playbooks/deploy.yml

# Both
ansible-playbook -i environments/dev/inventory.yml playbooks/site.yml
```

---

## Requirements

- Ansible 2.15 or later
- Controller: internet access
- Target: Ubuntu 24.04 (noble), Python 3

---

## Role Variables

### Defaults (override in inventory, group_vars, or playbook vars)

| Variable               | Default                                    | Description                                                                                      |
| ---------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| `docker_network_name`  | `"cms_network"`                            | Name of the Docker network created for the stack.                                                |
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

## Configuration

- Inventory: `environments/dev/inventory.yml`
- Extra vars: `environments/dev/manifest.yml` (optional)

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

**DevOps Team**  
PT Len IOT
