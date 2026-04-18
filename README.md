

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

## Configuratie-overzicht

- **main.yml** is het main-entrypoint en definieert alle rollen en taken voor het opzetten en beheren van het cluster.
- Secrets worden opgeslagen in `ansible/secrets` en beheerd met Ansible Vault:

```sh
ansible-vault edit ansible/secrets
```

De configuratie is onderverdeeld in:
- Clusterbeheer
- Creatie
- Inventory management
- Vernietiging

## Docker Subdirectory

De `docker/` directory bevat documentatie en voorbeelden voor Docker-containers en -netwerken. De directory is opgedeeld per opdracht, voor (bijna) alle opdrachten is een README aanwezig die dient als leeswijzer voor de betreffende opdracht.
- [tutorial README](./docker/tutorial/README.md)
- [lesson9 README](./docker/lesson9/README.md)
- [lesson10 OUTPUT](./docker/lesson10/DOCKER_NETWORKING_SCRIPT_OUTPUT.png)
- [opdracht2.2 README](./docker/opdracht2.2/README.md)
- [opdracht2.3 README](./docker/opdracht2.3/README.md)


Gebruikt voor docker tutorial: [Docker Networking Documentation](https://docs.docker.com/engine/install/ubuntu/)

---

## Requirements

| Requirement | Beschrijving | playbook(s) | 
|-----------|------|-----------------------|
| R1 | Inrichting Proxmox cluster / updates via orchestration / enterprise repository / monitoring | ansible/plays/cluster_management/* |
| R2 | HA met shared storage | ansible/plays/creation/clone_vm.yml |
| R3 | Orchestration script (Bash/Python) | scripts/* |
| R4 | Orchestration tool (Ansible/Terraform/etc) | ansible/plays/cluster_management/*, ansible/plays/creation/*, ansible/plays/inventory_management/* |
| R5 | 6x WordPress server (30GB disk / 1 CPU / 1GB RAM / 50MB/s netwerk limit + firewall + SSH keys) | ansible/plays/creation/clone_vm.yml, ansible/plays/creation/create_lxc.yml |
| R6 | HA voor WordPress servers | ansible/plays/creation/clone_vm.yml |
| R7 | Unieke gebruikers per server met SSH key access | ansible/plays/creation/create_vm_template.yml, ansible/plays/creation/clone_vm.yml, ansible/plays/creation/create_lxc.yml, ansible/plays/inventory_management/add_client_ssh.yml |
| R8 | Servers automatisch toegevoegd aan monitoring | ansible/plays/creation/provision_monitoring_vm.yml, ansible/plays/creation/clone_vm.yml |

---

## Playbooks & Gebruik

### Video bewijs
Alle scripts worden uitgevoerd en gedemonstreerd in de volgende video, waarin het volledige proces van clusterbeheer, VM- en containercreatie, inventory management, en opschonen/vernietigen wordt getoond:
- https://youtu.be/LcWnaCYMCiE

### Clusterbeheer

**Onboard Nodes** 
Maakt Ansible-gebruikers aan en configureert SSH-sleutels op alle nodes voor cluster-level orchestration.

```sh
ansible-playbook ansible/plays/cluster_management/onboard_nodes.yml --user=root --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

**Install Dependencies** 
Installeert benodigde software (Ansible, proxmoxer, git, pve-exporter, etc.) op alle nodes en configureert enterprise repository en monitoring.

```sh
ansible-playbook ansible/plays/cluster_management/install_dependencies.yml --user=ansible --ask-vault-pass --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

### VM- & Containercreatie

**Create VM Template**
Maakt een golden VM-template aan (30GB disk, 1 CPU, 1GB RAM) met SSH-key ondersteuning voor unieke gebruikers.

```sh
ansible-playbook ansible/plays/creation/create_vm_template.yml --user=ansible --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

**Provision Monitoring VM** 
Maakt een monitoring-VM aan (Prometheus, Grafana, pve-exporter) en configureert automatische server discovery.
Dashboard: [https://grafana.com/grafana/dashboards/10347-proxmox-via-prometheus/]

```sh
ansible-playbook ansible/plays/creation/provision_monitoring_vm.yml --user=ansible --ask-vault-pass --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

**Clone VM** 
Kloont 6 WordPress VM's (30GB disk, 1 CPU, 1GB RAM, 50MB/s netwerk limit), configureert HA, unieke SSH-keys per klant, en voegt toe aan monitoring.

```sh
ansible-playbook ansible/plays/creation/clone_vm.yml --user=ansible --ask-vault-pass --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

**Create LXC Container**
Maakt LXC-containers aan voor WordPress (30GB disk, 1 CPU, 1GB RAM) met unieke SSH-keys per klant.

```sh
ansible-playbook ansible/plays/creation/create_lxc.yml --user=ansible --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

**Setup SSH for LXC**
Configureert SSH-toegang voor LXC-containers met unieke client SSH-keys.

```sh
ansible-playbook ansible/plays/inventory_management/add_client_ssh.yml --user=ansible --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

### Inventory Management

**Setup Firewall**
Configureert UFW firewallregels op WordPress servers, zodat alleen noodzakelijke diensten bereikbaar zijn (SSH, HTTP, HTTPS).

```sh
ansible-playbook ansible/plays/inventory_management/setup_firewall.yml --user=ansible --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

**Add WordPress**
Installeert en configureert WordPress op alle 6 servers (inclusief Apache, MySQL, PHP) en registreert ze in monitoring.

```sh
ansible-playbook ansible/plays/inventory_management/add_wordpress.yml --user=ansible --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

**Setup Docker Swarm**
Installeert Docker en configureert Docker Swarm-cluster voor potentiële containerisatie van services.

```sh
ansible-playbook ansible/plays/inventory_management/setup_docker_swarm.yml --user=ansible --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

### Opschonen / Vernietigen

Maak het cluster eenvoudig schoon door VM's, LXC-containers en monitoring-setup te verwijderen:

```sh
ansible-playbook ansible/plays/destruction/DESTROY_VM.yml --user=ansible --ask-vault-pass --private-key /mnt/pve/cephfs/.ssh/id_ed25519
ansible-playbook ansible/plays/destruction/DESTROY_LXC.yml --user=ansible --ask-vault-pass --private-key /mnt/pve/cephfs/.ssh/id_ed25519
ansible-playbook ansible/plays/destruction/DESTROY_MONITORING.yml --user=ansible --ask-vault-pass --private-key /mnt/pve/cephfs/.ssh/id_ed25519
```

---
