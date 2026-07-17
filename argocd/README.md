# ArgoCD — GitOps bootstrap

ArgoCD is the reconciler: it watches this repo and makes the cluster match Git.
This repo uses the **app-of-apps** pattern — one root Application points at
`k8s/apps/`, and each file there is a child Application managing one workload.

```
argocd/bootstrap/root-app.yaml   ← applied by hand, once (this doc)
        └── watches k8s/apps/
              ├── monitoring.yaml    → syncs k8s/monitoring/
              ├── uptime-kuma.yaml   → syncs k8s/uptime-kuma/
              └── cloudflared.yaml   → syncs k8s/cloudflared/
```

## Bootstrap (fresh cluster)

```bash
# 1. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Apply the root app-of-apps (points back at this repo)
kubectl apply -f argocd/bootstrap/root-app.yaml

# 3. Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

From here on, deploys are `git push`: merge a change under `k8s/` and the
cluster converges automatically. Manual drift is reverted (`selfHeal: true`);
resources deleted from Git are pruned (`prune: true`).

## Adopting a cluster that's already running (this cluster's story)

These workloads were originally applied imperatively (`kubectl apply -R -f k8s/`)
before the root app existed. Applying the root app does **not** redeploy them:
ArgoCD adopts live resources whose kind/name/namespace already match what Git
renders — a no-op sync, no restarts.

Pre-flight checks before applying the root app to a live cluster:

```bash
# What Application objects already exist? (kubectl apply -R -f k8s/ also
# applied k8s/apps/*.yaml, so the children are probably already there)
kubectl -n argocd get applications

# Repo access: the manifests use the SSH URL, which needs a repo credential
# in ArgoCD even for a public repo. Check it's connected:
argocd repo list
# ...or register it: argocd repo add git@github.com:KarthikHegde91/infra.git \
#      --ssh-private-key-path ~/.ssh/<deploy-key>
```

If the child Applications show `Unknown` / `ComparisonError`, it's almost
always the repo credential missing — fix that before expecting syncs.
