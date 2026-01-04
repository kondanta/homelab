<div align=center>

### My Homelab Infrastructure 🏡
_... powered by Talos, Kubernetes and GitHub Actions_
</div>

<div align=center>

[![Endpoint Badge](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.taylan.dev%2Ftalos_version&style=for-the-badge&logo=Talos&logoColor=white&label=%20&color=%235548bf)
](https://talos.dev)
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.taylan.dev%2Fkubernetes_version&style=for-the-badge&logo=Kubernetes&logoColor=white&label=%20&color=%235548bf)](https://kubernetes.io)
[![Flux](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.taylan.dev%2Fflux_version&style=for-the-badge&logo=Flux&logoColor=white&label=%20&color=%235548bf)](https://flux.io)
[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/kondanta/homelab/renovate.yaml?branch=main&style=for-the-badge&logo=Renovate&label=%20&color=%235548bf)](https://github.com/renovatebot/renovate)

</div>

<div align=center>

![Age](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.taylan.dev%2Fcluster_age_days&style=for-the-badge&logoColor=white&labelColor=%239386ff&color=%235548bf)
![Uptime](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.taylan.dev%2Fcluster_uptime_days&style=for-the-badge&logoColor=white&labelColor=%239386ff&color=%235548bf)
![Pods](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.taylan.dev%2Fcluster_pod_count&style=for-the-badge&logoColor=white&labelColor=%239386ff&color=%235548bf)
![Nodes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.taylan.dev%2Fcluster_node_count&style=for-the-badge&logoColor=white&labelColor=%239386ff&color=%235548bf)
![Memory Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.taylan.dev%2Fcluster_memory_usage&style=for-the-badge&logoColor=white&labelColor=%239386ff&color=%235548bf)
![CPU Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.taylan.dev%2Fcluster_cpu_usage&style=for-the-badge&logoColor=white&labelColor=%239386ff&color=%235548bf)


</div>

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f680/512.gif" alt="🚀" width="20" height="20"> Overview
This repository contains the full infrastructure-as-code and GitOps configuration for my home Kubernetes cluster. It is the single source of truth for the cluster's state, which is automatically managed and reconciled by FluxCD.

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f340/512.gif" alt="🍀" width="20" height="20"> Kubernetes

My Kubernetes cluster is deployed with [Talos Linux](https://www.talos.dev), a Linux distribution build spefically for running Kubernetes. I run a three bare-metal node cluster on Intel 12th gen N95's and using [Longhorn](https://github.com/longhorn/longhorn) for cluster persistence block, object, and file storage.

---

### Core Components

- **Networking & Service Mesh**: [cilium](https://github.com/cilium/cilium) provides eBPF-based networking, [cloudflared](https://github.com/cloudflare/cloudflared) secures ingress traffic via Cloudflare, and [external-dns](https://github.com/kubernetes-sigs/external-dns) keeps DNS records in sync automatically.
- **Security & Secrets**: [cert-manager](https://github.com/cert-manager/cert-manager) automates SSL/TLS certificate management. For secrets, I use [sops](https://github.com/getsops/sops) to store and manage encrypted secrets in Git.
- **Storage & Data Protection**: [Longhorn](https://github.com/longhorn/longhorn) provides distributed storage for persistent volumes.
- **Automation & CI/CD**: [actions-runner-controller](https://github.com/actions/actions-runner-controller) runs self-hosted GitHub Actions runners directly in the cluster for continuous integration workflows.

### GitOps

[Flux](https://github.com/fluxcd/flux2) watches the clusters in my [kubernetes](./kubernetes/) folder (see Directories below) and makes the changes to my clusters based on the state of my Git repository.

The way Flux works for me here is it will recursively search the `Infrastructure/apps` folder until it finds the most top level `kustomization.yaml` per directory and then apply all the resources listed in it. That aforementioned `kustomization.yaml` will generally only have a namespace resource and one or many Flux kustomizations (`ks.yaml`). Under the control of those Flux kustomizations there will be a `HelmRelease` or other resources related to the application which will be applied.

[Renovate](https://github.com/renovatebot/renovate) watches my **entire** repository looking for dependency updates, when they are found a PR is automatically created. When some PRs are merged Flux applies the changes to my cluster.

### Directories

This Git repository contains the following directories under [Infrastructure](./infrastructure/).

```sh
📁 infrastructure
├── 📁 apps       # applications
├── 📁 components # re-useable kustomize components
├── 📁 sources    # source of the commonly used apps(deprecated)
└── 📁 flux       # flux system configuration

```

---
_This README is a living document and will be updated as the homelab evolves._

---

## <img src="https://fonts.gstatic.com/s/e/notoemoji/latest/1f64f/512.gif" alt="🙏" width="20" height="20"> Thanks

Thanks to all the people who donate their time to the [Home Operations](https://discord.gg/home-operations) Discord community. Be sure to check out [kubesearch.dev](https://kubesearch.dev/) for ideas on how to deploy applications or get ideas on what you could deploy.
