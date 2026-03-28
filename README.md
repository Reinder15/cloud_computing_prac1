

# Proxmox Cluster Automatisering met Ansible

Deze repository bevat een Ansible-configuratie voor het geautomatiseerd opzetten en beheren van een Proxmox-cluster voor twee soorten klanten:

**Klant 1: WordPress voor Training**
- Meerdere WordPress-sites voor trainingsdoeleinden
- Focus op kostenbesparing: applicaties worden aangeboden in containers (LXC)

**Klant 2: High-Availability & Beveiligde WordPress Server**
- CRM-applicatie met hoge eisen aan beveiliging en beschikbaarheid
- Oplossing: Dedicated VM met Proxmox HA

---

## Vereisten

- Proxmox VE-cluster met minimaal 3 nodes
- Ansible geïnstalleerd op een beheermachine
- SSH-toegang tot de Proxmox-nodes
- Proxmox API-toegang voor Ansible
- Proxmox API-toegang voor monitoring (pve-exporter)

## Clusterinformatie

- **Subnet:** 10.24.38.x/24
- **VLAN:** 2438
- **Default Gateway:** 10.24.38.1/24
- **Tailscale entry:** [https://10.24.38.2:8006/#v1:0:18:4:::::::](https://10.24.38.2:8006/#v1:0:18:4:::::::)

| Node         | Hostname                    | IP-adres       |
|--------------|-----------------------------|---------------|
| 35448901     | node1.klein-mkb-host.nl     | 10.24.38.2     |
| 35448902     | node2.klein-mkb-host.nl     | 10.24.38.3     |
| 35448903     | node3.klein-mkb-host.nl     | 10.24.38.4     |

## SSH-setup

```sh
pvesm add cephfs cephfs --path /mnt/pve/cephfs --content backup,vztmpl,iso,snippets --nodes node1,node2,node3
ceph mds stat
ceph fs ls
ls -la /mnt/pve/cephfs
cd /mnt/pve/cephfs
git clone https://github.com/Reinder15/cloud_computing_prac1.git
```

## Configuratie-overzicht

- **main.yml** is het hoofd-entrypoint en definieert alle rollen en taken voor het opzetten en beheren van het cluster.
- Geheime gegevens worden opgeslagen in `ansible/secrets` en beheerd met Ansible Vault:

```sh
ansible-vault edit ansible/secrets
```

De configuratie is onderverdeeld in:
- Clusterbeheer
- Creatie
- Inventory management
- Vernietiging

---

## Playbooks & Gebruik

### Clusterbeheer

**Onboard Nodes**
Maakt Ansible-gebruikers aan en configureert SSH-sleutels op alle nodes.

```sh
ansible-playbook ansible/plays/cluster_management/onboard_nodes.yml --user=root --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

**Install Dependencies**
Installeert benodigde software (Ansible, proxmoxer, git, pve-exporter, etc.) op alle nodes.

```sh
ansible-playbook ansible/plays/cluster_management/install_dependencies.yml --user=ansible --ask-vault-pass --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

### VM- & Containercreatie

**Create VM Template**
Maakt een golden VM-template aan op basis van een ISO-image.

```sh
ansible-playbook ansible/plays/creation/create_vm_template.yml --user=ansible --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

**Provision Monitoring VM**
Maakt een monitoring-VM aan (Prometheus, Grafana, pve-exporter, etc.).
dashboard url: [https://grafana.com/grafana/dashboards/10347-proxmox-via-prometheus/]

```sh
ansible-playbook ansible/plays/creation/provision_monitoring_vm.yml --user=ansible --ask-vault-pass --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

**Clone VM**
Kloont nieuwe VM's vanaf de template, configureert netwerk, opslag en software.

```sh
ansible-playbook ansible/plays/creation/clone_vm.yml --user=ansible --ask-vault-pass --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

**Create LXC Container**
Maakt nieuwe LXC-containers aan vanaf een template, configureert netwerk, opslag en software.

```sh
ansible-playbook ansible/plays/creation/create_lxc.yml --user=ansible --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

**Setup SSH for LXC**
Configureert SSH-toegang voor LXC-containers.

```sh
ansible-playbook ansible/plays/inventory_management/setup_ssh_lxc.yml --user=ansible --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

### Inventory Management

**Setup Firewall**
Configureert firewallregels op de clusternodes.

```sh
ansible-playbook ansible/plays/inventory_management/setup_firewall.yml --user=ansible --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

**Add WordPress**
Installeert en configureert WordPress (inclusief database- en webserverconfiguratie).

```sh
ansible-playbook ansible/plays/inventory_management/add_wordpress.yml --user=ansible --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

### Opschonen / Vernietigen

Maak het cluster eenvoudig schoon door VM's, LXC-containers en monitoring-setup te verwijderen:

```sh
ansible-playbook ansible/plays/destruction/DESTROY_VM.yml --user=ansible --ask-vault-pass --private-key /mnt/pve/cephfs/.ssh/id_ed25519
ansible-playbook ansible/plays/destruction/DESTROY_LXC.yml --user=ansible --ask-vault-pass --private-key /mnt/pve/cephfs/.ssh/id_ed25519
ansible-playbook ansible/plays/destruction/DESTROY_MONITORING.yml --user=ansible --ask-vault-pass --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

---

## Notities

- Alle playbooks zijn modulair opgezet en kunnen onafhankelijk worden uitgevoerd.
- Gebruik voor gevoelige data altijd Ansible Vault.