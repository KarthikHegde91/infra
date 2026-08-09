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

# Repo access: the manifests use the public HTTPS URL, so ArgoCD reads the
# repo anonymously and NO repo credential is required. This should be empty,
# and that is fine:
argocd repo list
```

This used to be the SSH URL with a deploy key, which is what made a lapsed
credential able to stop every sync silently. If child Applications show
`Unknown` / `ComparisonError`, confirm the Application still points at
`https://github.com/...` — a stale `git@github.com:...` in the live object is
the thing to look for, since changing it in Git cannot fix it (see below).

### The bootstrap exception

Changing `repoURL` in Git is circular for the root app: ArgoCD can only pick up
the change by reading the repo it cannot read. If root is stuck on an SSH URL
whose key no longer works, repoint the live object by hand, once:

```bash
kubectl -n argocd patch application root --type merge \
  -p '{"spec":{"source":{"repoURL":"https://github.com/KarthikHegde91/infra.git"}}}'
```

Root then syncs `k8s/apps/`, and the child Applications inherit the HTTPS URL
from Git automatically.
