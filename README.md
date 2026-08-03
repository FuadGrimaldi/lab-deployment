# ansible-collection

Project deployment internal berbasis Ansible untuk homelab/infrastruktur magang. Berisi playbook, inventory, dan konfigurasi environment, serta collection `fuad.homelab_stack` (monitoring stack Prometheus/Grafana/Node Exporter) yang dikembangkan dalam repo yang sama (monorepo).

## Struktur Repo

```
ansible-collection/
├── ansible.cfg                    # config Ansible (collections_path, remote_user, dst)
├── environments/
│   └── dev/
│       ├── inventory.yml          # daftar host target
├── collections/                   # symlink lokal ke fuad/ (di-gitignore)
├── monitoring_up.yml               # playbook: deploy monitoring stack
├── ...                             # playbook lain
└── fuad/
    └── homelab_stack/              # Ansible Collection — lihat README di dalamnya
        ├── galaxy.yml
        ├── README.md
        └── roles/
```

> Dokumentasi role, variabel, dan detail collection ada di [`fuad/homelab_stack/README.md`](fuad/homelab_stack/README.md). README ini fokus ke cara menjalankan project secara keseluruhan.

## Requirements

- WSL2 (Ubuntu) atau Linux
- `ansible-core` >= 2.14
- Docker & Docker Compose plugin di target host
- Akses SSH ke host target (key-based, sesuai `ansible.cfg`)

## Setup Awal

1. Clone repo:

   ```bash
   git clone https://github.com/USERNAME_GITHUB/ansible-collection.git
   cd ansible-collection
   ```

2. Daftarkan collection lokal (`fuad/homelab_stack`) supaya dikenali Ansible:

   ```bash
   mkdir -p collections/ansible_collections
   ln -s ../../fuad collections/ansible_collections/fuad
   ```

3. Pastikan `ansible.cfg` memuat:

   ```ini
   [defaults]
   collections_path = ./collections
   remote_user = nzo
   host_key_checking = False
   private_key_file = ~/.ssh/id_ed25519
   ```

4. Verifikasi collection terbaca:

   ```bash
   ansible-galaxy collection list | grep fuad
   ```

5. Cek koneksi ke host target:
   ```bash
   ansible docker_servers -i environments/dev/inventory.yml -m ping
   ```

> **Catatan WSL2:** Jalankan repo ini dari filesystem Linux native (`~/projects/...`), bukan dari `/mnt/c` atau `/mnt/d`. Ansible menolak membaca `ansible.cfg` dari direktori yang di-mount lewat DrvFs (world-writable), sehingga `collections_path` tidak akan terbaca kalau project ada di `/mnt/...`.

## Menjalankan Playbook

```bash
ansible-playbook -i environments/dev/inventory.yml monitoring_up.yml
```

Playbook lain dijalankan dengan pola yang sama:

```bash
ansible-playbook -i environments/dev/inventory.yml <nama_playbook>.yml
```

## Inventory

Host target didaftarkan di `environments/dev/inventory.yml`:

```yaml
all:
  children:
    docker_servers:
      hosts:
        nzo-dev:
          ansible_host: 192.168.56.64
          ansible_user: nzo
```

## Development Collection

Perubahan pada role di `fuad/homelab_stack/roles/` langsung terpakai (karena disymlink), tidak perlu build/reinstall ulang tiap kali edit. Lint sebelum commit:

```bash
ansible-lint fuad/homelab_stack/roles/
```

## Author

Fuad Grimaldi
