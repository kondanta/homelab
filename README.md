# My Homelab Infrastructure 🏡

This repository contains the full infrastructure-as-code and GitOps configuration for my home Kubernetes cluster. It is the single source of truth for the cluster's state, which is automatically managed and reconciled by FluxCD.

---

## ▪️ Architecture

- **Provisioning**: The bare-metal nodes are provisioned using **Talos Linux**, a modern, secure, and minimal OS for Kubernetes. All provisioning configurations are located in the `provision/` directory.
- **Kubernetes**: A 3-node Kubernetes cluster running on Beelink S13 Mini PCs.
- **GitOps**: **FluxCD** is used to continuously reconcile the cluster state from the `cluster/` directory in this repository.
- **CNI**: **Cilium** provides networking, observability, and security using eBPF. It runs in place of `kube-proxy` for maximum efficiency.

---

## ▪️ Repository Structure

- **`/provision/talos`**: Contains Talos machine configurations for provisioning the Kubernetes nodes.
- **`/clusters/homelab/flux-system`**: Holds the core FluxCD manifests that bootstrap the GitOps process.
- **`/infrastructure/apps/core`**: Contains manifests for essential, cluster-wide services like MetalLB, cert-manager, and the observability stack.
- **`/infrastructure/apps/services`**: Includes manifests for all user-facing applications and services running on the cluster.
- **`/infrastructure/sources`**: Defines the sources for Git repositories and Helm charts used in the cluster.

---

## ▪️ Core Platform Services

- **Observability**: A full stack including **VictoriaMetrics** (metrics), **Loki** (logs), and **Tempo** (traces), all visualized in **Grafana**.
- **Identity**: **Authentik** is used as the central OIDC provider for single sign-on (SSO) across services.
- **Load Balancing**: **MetalLB** provides `LoadBalancer` services on the bare-metal cluster.
- **TLS Certificates**: **cert-manager** handles automated TLS certificate provisioning from Let's Encrypt.

---

## ▪️ Usage

To apply any change to the cluster, simply push a commit to the `main` branch. Flux will automatically detect the change and apply the new manifests.

---
_This README is a living document and will be updated as the homelab evolves._