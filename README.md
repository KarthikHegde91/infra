# infra — $0/Month Production Platform

Infrastructure-as-code and GitOps manifests for a production-grade platform running **entirely on free-tier services** — total run cost **$0/month**. This is the infrastructure behind [karthikhegde.in](https://karthikhegde.in): a single-node **K3s** cluster on Oracle Cloud's Always-Free ARM tier, fronted by a **Cloudflare Tunnel** (zero-trust, no open ports) and monitored with **Prometheus + VictoriaMetrics + Grafana**.

![Cost](https://img.shields.io/badge/monthly_cost-%240-brightgreen)
![K3s](https://img.shields.io/badge/kubernetes-K3s-blue)
![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-ef7b4d)
![IaC](https://img.shields.io/badge/IaC-Terraform-purple)
![Cloudflare](https://img.shields.io/badge/ingress-Cloudflare_Tunnel-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## Architecture

```mermaid
flowchart TD
    subgraph OCI["Oracle Cloud — Always-Free ARM VM"]
        K3s["K3s (single node)"]
        K3s --> Argo["ArgoCD (GitOps reconciler)"]
        K3s --> Mon["Monitoring: Prometheus → VictoriaMetrics → Grafana"]
        K3s --> Kuma["Uptime Kuma (status page)"]
        K3s --> CFD["cloudflared (tunnel daemon)"]
    end

    subgraph CF["Cloudflare (free)"]
        Tunnel["Zero-Trust Tunnel"]
        DNS["DNS + TLS"]
    end

    Users["Users"] --> DNS --> Tunnel --> CFD
    Terraform["Terraform"] -.provisions.-> OCI
    Terraform -.manages DNS.-> CF
    Repo["This repo (main)"] -.watched by.-> Argo
```

**Ingress is zero-trust:** no inbound ports are open on the VM. `cloudflared` dials out to Cloudflare, and all traffic reaches services through the tunnel — the origin is never directly reachable.

---

## The $0/month stack

| Layer | Tech | Free tier |
|---|---|---|
| Compute | Oracle Cloud Always-Free **ARM (Ampere A1)** | 4 vCPU / 24 GB |
| Kubernetes | **K3s** (single node) | self-hosted |
| GitOps | **ArgoCD** (app-of-apps) | self-hosted |
| IaC | **Terraform** (OCI + Cloudflare providers) | free |
| Ingress / DNS / TLS | **Cloudflare Tunnel** (Zero Trust) | free plan |
| Monitoring | **Prometheus + VictoriaMetrics + Grafana** | self-hosted |
| Status page | **Uptime Kuma** | self-hosted |

---

## Repository layout

```
.
├── bootstrap/
│   └── cloud-init.yaml          # VM first-boot provisioning
├── terraform/                   # Infrastructure as Code
│   ├── compute.tf               #   Oracle Cloud ARM instance
│   ├── networking.tf            #   VCN, subnet, security lists (default-deny)
│   ├── cloudflare.tf            #   DNS records for the tunnel
│   ├── variables.tf / outputs.tf / versions.tf / main.tf
│   └── terraform.tfvars.example #   copy → terraform.tfvars (git-ignored)
├── scripts/
│   └── tunnel-setup.sh          # creates the Cloudflare tunnel + k8s secret
├── argocd/
│   └── bootstrap/
│       └── root-app.yaml        # app-of-apps root (applied by hand, once)
├── .github/workflows/
│   └── validate.yml             # CI: yamllint + kubeconform + terraform fmt
└── k8s/                         # Kubernetes manifests
    ├── apps/                    #   ArgoCD child Applications (watched by root app)
    ├── cloudflared/             #   tunnel daemon (secret created manually)
    ├── monitoring/
    │   ├── prometheus/          #   scrape config + RBAC + storage
    │   ├── victoriametrics/     #   long-term metric storage
    │   └── grafana/             #   dashboards + provisioning
    └── uptime-kuma/             #   status page
```

---

## How to deploy

```bash
# 1. Provision the VM + networking + DNS
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in OCI + Cloudflare values (git-ignored)
terraform init && terraform apply

# 2. K3s is installed via bootstrap/cloud-init.yaml on first boot.
#    Pull the kubeconfig from the VM and point kubectl at it.

# 3. Create the Cloudflare tunnel + its Kubernetes secret
./scripts/tunnel-setup.sh

# 4. Install ArgoCD and hand the cluster over to GitOps
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f argocd/bootstrap/root-app.yaml
```

From here on, deploying = `git push`.

---

## GitOps — how changes reach the cluster

ArgoCD runs in-cluster using the **app-of-apps** pattern: one root Application
([`argocd/bootstrap/root-app.yaml`](argocd/bootstrap/root-app.yaml)) watches
`k8s/apps/`, where each file is a child Application managing one workload.

**Merge to `main` → CI validates → ArgoCD syncs.** Manual `kubectl` edits are
reverted (`selfHeal`), and resources deleted from Git are pruned. Bootstrap
details and how ArgoCD *adopts* an already-running cluster without redeploying
anything: [`argocd/README.md`](argocd/README.md).

---

## Security notes

- **No secrets in git.** `terraform.tfvars`, the cloudflared credentials JSON, and `k8s/cloudflared/secret.yaml` are all git-ignored; only `*.example` templates are committed.
- **Default-deny networking** — the security list opens nothing for apps; ingress is exclusively via the Cloudflare Tunnel.
- **Least-privilege RBAC** for the Prometheus service account (`k8s/monitoring/prometheus/rbac.yaml`).
- **The tunnel UUID in `k8s/cloudflared/configmap.yaml` is an identifier, not a credential.** It already appears in public DNS (`<id>.cfargotunnel.com`); what authenticates the tunnel is the credentials JSON, which never touches git.

## Why I built it

A place to practice real DevOps/SRE — cluster ops, GitOps, IaC, observability, zero-trust networking — on production-grade tooling without a cloud bill. Everything here is reproducible from code.

## License

MIT — see [LICENSE](LICENSE).

---

**Author:** Karthik B Hegde — DevOps / SRE Engineer, Bengaluru
[karthikhegde.in](https://karthikhegde.in) · [LinkedIn](https://www.linkedin.com/in/karthikhegde1) · [GitHub](https://github.com/KarthikHegde91)
