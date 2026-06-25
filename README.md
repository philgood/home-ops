<div align="center">

# home-ops

### 🏠 A GitOps-managed homelab

_Powered by [Talos](https://talos.dev), [Flux](https://fluxcd.io), and [Kubernetes](https://kubernetes.io)_

<br />

[![Talos](https://kromgo.narden.au/badges/talos_version)](https://talos.dev)
[![Kubernetes](https://kromgo.narden.au/badges/kubernetes_version)](https://kubernetes.io)
[![Flux](https://kromgo.narden.au/badges/flux_version)](https://fluxcd.io)

<p align="center">
  <a href="https://github.com/home-operations/kromgo/"><img src="https://kromgo.narden.au/badges/cluster_age_days" alt="Age"></a>
  <a href="https://github.com/home-operations/kromgo/"><img src="https://kromgo.narden.au/badges/cluster_node_count" alt="Nodes"></a>
  <a href="https://github.com/home-operations/kromgo/"><img src="https://kromgo.narden.au/badges/cluster_pod_count" alt="Pods"></a>
  <a href="https://github.com/home-operations/kromgo/"><img src="https://kromgo.narden.au/badges/cluster_alert_count" alt="Alerts"></a>
  <br />
  <a href="https://github.com/home-operations/kromgo/"><img src="https://kromgo.narden.au/badges/cluster_cpu_usage" alt="CPU"></a>
  <a href="https://github.com/home-operations/kromgo/"><img src="https://kromgo.narden.au/badges/cluster_memory_usage" alt="Memory"></a>
</p>

</div>

---

## 📖 Overview

This repository hosts the Infrastructure as Code (IaC) for my Kubernetes homelab. It runs a media server stack, home automation, and observability infrastructure.

The cluster is built on **Talos Linux**, an immutable and minimal OS, and managed via **GitOps** principles using **Flux**. Changes pushed to this repository are automatically reconciled in the cluster.

---

## 🔧 Hardware

### Kubernetes Cluster

| Node | CPU | RAM | OS Disk | Ceph Disk | OS | Purpose |
|------|-----|-----|---------|-----------|-----|---------|
| alpha | i9-12900H (14c/20t) | 64GB | 960GB MICRON M.2 7450 PRO 22110 | 1.92TB Samsung PM982 22110 | Talos | Control + Worker |
| bravo | i9-12900H (14c/20t) | 64GB | 960GB MICRON M.2 7450 PRO 22110 | 1.92TB Samsung PM982 22110 | Talos | Control + Worker |
| charlie | i9-12900H (14c/20t) | 64GB | 960GB MICRON M.2 7450 PRO 22110 | 1.92TB Samsung PM982 22110 | Talos | Control + Worker |

**Totals:** 42 cores / 60 threads | 288GB RAM | ~5.76TB Ceph

### Supporting Infrastructure

| Device | Count | Storage | RAM | OS | Purpose |
|--------|-------|---------|-----|-----|---------|
| Topton N5105 | 1 | 5x 12tb (44tb)  + NVMe cache | 64GB | TrueNAS | NAS/Backup |
| Unifi Dream Machine Pro | 1 | - | - | - | Router/Firewall |
| Unifi US-24-250W | 1 | - | - | - | PoE Switch |
| Unifi US-48 | 1 | - | - | - | Primary Switch |
| Unifi U6 Lite | 2 | - | - | - | WiFi APs |
| Eaton 5S 850 | 1 | - | - | - | UPS |

---

## 🧩 Core Components

| Component                                            | Description                                      | Namespace      |
| :--------------------------------------------------- | :----------------------------------------------- | :------------- |
| **[Cilium](https://cilium.io/)**                     | CNI, Network Policies, and Load Balancing.       | `kube-system`  |
| **[Cert-Manager](https://cert-manager.io/)**         | Automates Let's Encrypt SSL certificates.        | `cert-manager` |
| **[External Secrets](https://external-secrets.io/)** | Syncs secrets from 1Password into the cluster.   | `security`     |
| **[Gateway API](https://gateway-api.sigs.k8s.io/)**  | Modern ingress management via **Envoy Gateway**. | `network`      |

---

## 🚀 Services & Applications

Key user-facing applications running on the cluster.

| Category          | Applications                                                                                                                                                                                                          |
| :---------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Media**         | [Jellyfin](https://jellyfin.org/), [Sonarr](https://sonarr.tv/), [Radarr](https://radarr.video/), [Bazarr](https://www.bazarr.media/), [Prowlarr](https://prowlarr.com), [Seerr](https://github.com/seerr-team/seerr) |
| **Observability** | [Grafana](https://grafana.com/), [Prometheus](https://prometheus.io/), [VictoriaLogs](https://docs.victoriametrics.com/victorialogs/), [Gatus](https://gatus.io)                                                      |
| **IOT**           | [Home Assistant](https://www.home-assistant.io/)                                                                                                                                                                      |

---

Huge thanks to [@onedr0p](https://github.com/onedr0p) and the amazing [Home Operations](https://discord.gg/home-operations) Discord community for their knowledge and support. If you're looking for inspiration, check out [kubesearch.dev](https://kubesearch.dev) to discover how others are deploying applications in their homelabs.</sub>