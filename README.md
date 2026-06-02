# **🚀 Raspberry Pi HA K3s Cluster Image Builder**

<div align="center">

_An automated, zero-touch provisioning pipeline for building immutable,
production-ready Kubernetes edge nodes on Raspberry Pi hardware._

</div>

## 🛠️ Built with

![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![K3S](https://img.shields.io/badge/-K3s-FFC61C?style=for-the-badge&logo=k3s&logoColor=white)
![argo_cd](https://img.shields.io/badge/-Argo-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Kubernetes](https://img.shields.io/badge/-Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Helm](https://img.shields.io/badge/-Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white)
![RPI](https://img.shields.io/badge/-RaspberryPi-A22846?style=for-the-badge&logo=raspberrypi&logoColor=white)

## **📖 Overview**

This repository contains the Infrastructure-as-Code (IaC) and CI/CD pipelines
required to automatically bake custom Ubuntu 24.04 LTS OS images for a Raspberry
Pi 4/5 cluster.

Instead of manually flashing SD cards, SSH-ing into nodes, and running bash
scripts, this project utilizes **Cloud-Init** and **GitHub Actions** to inject
networking, secrets, and GitOps manifests directly into the OS image block
device.

**Plug in the Pi, turn it on, and it autonomously joins a Highly Available K3s
cluster.**

## **✨ Core Features**

- **Zero-Touch Provisioning:** Bakes cloud-init directly into the boot
  partition.
- **Hardware Optimized (SSD Native):** Automatically patches the Ubuntu kernel
  to enable cgroups (required for K3s on RPi). Designed for native USB 3.0 SSD
  booting—Ubuntu automatically expands the root partition on first boot to
  utilize the full drive.
- **Offline Bootstrapping:** Injects the `K3S_TOKEN` directly at build time,
  eliminating external dependencies during the initial boot. Nodes can securely
  form the cluster completely offline.
- **High Availability (HA):** Deploys `kube-vip` (with leader election) to
  provide a resilient, floating Control Plane IP address via ARP broadcast.
- **GitOps Native:** Pre-loads ArgoCD manifests so the cluster immediately
  begins syncing Day-2 workloads (like Vault External Secrets and Ingress) from
  your Git repository the moment the API server goes live.

## **🧰 Tech Stack**

| Component       | Technology         | Description                                          |
| :-------------- | :----------------- | :--------------------------------------------------- |
| **Base OS**     | Ubuntu 26.04 LTS   | Preinstalled ARM64 Server Image for Raspberry Pi     |
| **Kubernetes**  | K3s                | Lightweight, edge-optimized Kubernetes               |
| **Secrets**     | Build-Time Env     | Direct `K3S_TOKEN` injection for offline clustering  |
| **GitOps**      | ArgoCD             | App-of-Apps cluster workload bootstrapping           |
| **Networking**  | kube-vip & Netplan | Static IP injection and HA Floating Control Plane IP |
| **Task Runner** | Just               | Modern command runner for local builds and linting   |

## **📂 Repository Structure**

```text
├── .github/workflows/
│ └── build-image.yaml               # CI/CD pipeline for generating .img artifacts
├── cloud-init/
│ ├── network-config.yaml.tftpl      # Netplan static IP configuration template
│ └── user-data.yaml.tftpl           # Core bootstrapping & HA cluster joining logic
├── manifests/
│ ├── argocd-app.yaml.tftpl          # GitOps Root Application
│ ├── argocd-helm.yaml               # ArgoCD K3s HelmChart CRD
│ └── kube-vip-daemonset.yaml.tftpl  # HA Floating IP configuration
├── scripts/
│ └── build-image.sh                 # Loopback mounting and OS injection script
├── .pre-commit-config.yaml          # Git hook configurations (yamllint, etc.)
├── justfile                         # Local developer commands
└── README.md
```

## **🚀 Getting Started (Local Development)**

We use just as our modern command runner. To build and test images locally (even
on macOS), you will need Docker installed.

### **1\. Prerequisites**

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or
  OrbStack/Colima)
- [Just](https://github.com/casey/just) (brew install just)
- [Pre-commit](https://pre-commit.com/) (brew install pre-commit)

### **2\. Configure Local Environment**

Create a .env file in the root of the repository (this is .gitignore'd for
security) to simulate the GitHub Actions inputs:

```
NODE_ROLE=worker
NODE_HOSTNAME=node4
NODE_IP=192.168.0.24
VIP_IP=192.168.0.20
ROUTER_GATEWAY_IP=192.168.0.1
K3S_TOKEN=your-secure-k3s-cluster-token
SSH_PUBLIC_KEY=ssh-ed25519 AAAAC3... user@local
TF_REPO_URL=https://github.com/your-org/your-gitops-repo.git
```

### **3\. Available Commands**

Run `just` in your terminal to see the available commands:

```
# Lint all YAML and scripts before committing
just lint

# Build the custom OS image locally on a Mac (uses privileged Docker
container)
just build-locally

# Clean up generated artifacts and loopback mounts
just clean
```

## **☁️ CI/CD Pipeline (GitHub Actions)**

This repository includes a `workflow_dispatch` GitHub Action. You can trigger
image builds directly from the GitHub UI.

### Required GitHub Secrets

Ensure the following repository secrets are configured before running the
pipeline:

- `K3S_TOKEN`
- `SSH_PUBLIC_KEY`
- `TF_REPO_URL`

### Triggering a Build

1. Go to the Actions tab in GitHub.
2. Select Build K3s RPi Image.
3. Click Run workflow.
4. Input the node's specific variables:
   - Node Role: `master-init` (first node), `master-join` (additional masters),
     or `worker`.
   - Node Hostname: e.g., `k3s-worker-01`.
   - Node IP: The static IP for this specific hardware.
   - VIP IP: The kube-vip floating IP for the control plane.

5. Once the build completes, download the generated .img.xz artifact.

## 💾 Flashing & Booting Note: This setup is designed to boot natively from an SSD

_No MicroSD card is required. If using older Raspberry Pi 4 models, ensure you
have updated the EEPROM to enable USB boot first._

1. Download the generated `.img.xz` artifact from your GitHub Action run (or
   your local `workspace/` folder).
2. Flash the image directly to your USB 3.0 SATA SSD using the
   [Raspberry Pi Imager](https://www.raspberrypi.com/software/). The setup for
   which this repo is built uses this
   [adapter](https://www.amazon.de/dp/B00XLAZODE).
3. Ensure no SD card is in the Pi, and plug the SSD into the blue USB 3.0 port.
4. Plug in the Ethernet cable, and power on the Pi.
5. The Pi will automatically:
   - Expand the root filesystem to utilize the entire SSD.
   - Set its static IP.
   - Install K3s (adding `--tls-san` for HA).
   - Deploy `kube-vip` for the floating IP.
   - Install ArgoCD and join the GitOps cluster.

## **📄 License**

This project is licensed under the MIT License. See the [LICENSE](./LICENSE)
file for details.
