# fuad.homelab_stack

Ansible Collection untuk provisioning infrastruktur homelab: monitoring stack (Prometheus, Grafana, Node Exporter) berbasis Docker Compose.

# fuad.homelab_stack

Ansible Collection untuk provisioning infrastruktur homelab/internal: monitoring stack (Prometheus, Grafana, Node Exporter) berbasis Docker Compose.

> Collection ini dikembangkan sebagai bagian dari repo [`ansible-collection`](../../README.md). Lihat README di root repo untuk cara menjalankan playbook deployment sehari-hari. README ini fokus pada isi collection itu sendiri (role, variabel, cara pakai role).

## Requirements

- `ansible-core` >= 2.14
- Docker & Docker Compose plugin sudah terinstall di target host
- Collection dependency: [`community.docker`](https://galaxy.ansible.com/community/docker) >= 3.7.0

## Instalasi

Karena collection ini hidup dalam satu repo yang sama dengan playbook (monorepo), **tidak perlu install lewat `ansible-galaxy collection install` dari sumber eksternal**. Ansible tinggal diarahkan ke folder ini lewat `collections_path`.

Dari root repo (`ansible-collection/`):

```bash
mkdir -p collections/ansible_collections
ln -s ../../fuad collections/ansible_collections/fuad
```

Lalu pastikan `ansible.cfg` di root repo memuat:

```ini
[defaults]
collections_path = ./collections
```

Verifikasi:

```bash
ansible-galaxy collection list | grep fuad
```

### Kalau nanti dipakai di repo lain (dependency antar-project)

Kalau suatu saat collection ini perlu dipakai proyek lain di luar repo ini, build jadi tarball dan distribusikan manual (tanpa perlu pisah repo):

```bash
cd fuad/homelab_stack
ansible-galaxy collection build
# hasil: fuad-homelab_stack-1.0.0.tar.gz
```

Tarball ini bisa diinstall di proyek lain dengan:

```bash
ansible-galaxy collection install fuad-homelab_stack-1.0.0.tar.gz
```

## Struktur Collection

```
fuad/homelab_stack/
├── galaxy.yml
├── README.md
├── plugins/
├── roles/
│   └── monitoring_stack/
└── meta/
    └── runtime.yml
```

## Roles

### `fuad.homelab_stack.monitoring_stack`

Deploy Prometheus, Grafana, dan Node Exporter sekaligus dalam satu Docker Compose stack, terhubung lewat network Docker eksternal (`cms_network`).

**Variabel (`defaults/main.yml`):**

| Variabel                     | Default         | Keterangan                                         |
| ---------------------------- | --------------- | -------------------------------------------------- |
| `prometheus_port`            | `9090`          | Port Prometheus di host                            |
| `grafana_port`               | `3000`          | Port Grafana di host                               |
| `node_exporter_port`         | `9100`          | Port Node Exporter (internal network)              |
| `prometheus_scrape_interval` | `15s`           | Interval scrape Prometheus                         |
| `cms_network_name`           | `cms_network`   | Nama Docker network eksternal yang dipakai bersama |
| `grafana_admin_password`     | _(wajib diisi)_ | Password admin Grafana saat pertama kali dibuat    |

**Contoh pemakaian di playbook:**

```yaml
- hosts: docker_servers
  become: true
  roles:
    - role: fuad.homelab_stack.monitoring_stack
      vars:
        grafana_admin_password: "{{ vault_grafana_password }}"
```

**Setelah deploy:**

1. Buka `http://<ip-host>:3000`, login dengan `admin` / nilai `grafana_admin_password`.
2. Tambahkan data source Prometheus dengan URL `http://prometheus:9090` (pakai nama service, satu Docker network).
3. Import dashboard **1860 (Node Exporter Full)** dari grafana.com.

> Catatan: Node Exporter berjalan sebagai container di dalam `cms_network` yang sama (bukan `network_mode: host`), sehingga hanya memantau resource dari VM tempat stack ini di-deploy.

## Lint

```bash
ansible-lint roles/
```

## License

Internal use.

## Author

Fuad
