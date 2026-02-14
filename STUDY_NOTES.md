# ArgoCD Study Notes

## What is ArgoCD?

ArgoCD is a declarative, GitOps-based continuous delivery tool for Kubernetes. It monitors Git repositories containing Kubernetes manifests and automatically keeps the cluster state in sync with the desired state defined in Git. Git becomes the single source of truth for what should be running in your cluster.

## What is GitOps?

GitOps is an operational model where:
- **Git is the source of truth** — the desired state of your infrastructure is stored in a Git repo
- **Changes go through Git** — no manual `kubectl apply`, all changes are commits/PRs
- **Automatic reconciliation** — a controller (ArgoCD) continuously compares Git vs cluster and syncs
- **Audit trail for free** — Git history = deployment history

## Core Concepts

### Application
The fundamental ArgoCD resource. It defines:
- **Source**: a Git repo + path containing Kubernetes manifests
- **Destination**: a cluster + namespace where resources should be deployed
- **Sync Policy**: automatic or manual, with self-heal and prune options

### AppProject
A grouping mechanism that provides RBAC boundaries:
- Restricts which repos an app can pull from
- Restricts which clusters/namespaces an app can deploy to
- Restricts which Kubernetes resource types are allowed
- Defines roles and permissions for team members

### ApplicationSet
A template that generates multiple Applications from a single definition. Useful for:
- Deploying the same app across multiple environments (dev/staging/prod)
- Deploying to multiple clusters
- Dynamic app generation based on Git directory structure

### Sync
The process of applying the desired state (Git) to the live state (cluster):
- **Synced**: cluster matches Git
- **OutOfSync**: cluster differs from Git (someone ran `kubectl` manually, or Git was updated)

### Health Status
ArgoCD evaluates resource health beyond just "exists":
- **Healthy**: resource is working as expected
- **Progressing**: resource is being updated (e.g., rolling update in progress)
- **Degraded**: resource has a problem (e.g., CrashLoopBackOff)
- **Missing**: resource exists in Git but not in cluster

## Sync Strategies

### Manual Sync
- You explicitly trigger sync via UI or CLI
- Good for production where you want human approval
- `argocd app sync <app-name>`

### Automatic Sync
- ArgoCD syncs whenever it detects Git changes (polls every 3 minutes by default)
- Good for dev/staging environments
- Configured in the Application's `syncPolicy.automated`

### Self-Heal
- Automatically reverts manual `kubectl` changes to match Git
- Prevents configuration drift from manual interventions
- `syncPolicy.automated.selfHeal: true`

### Prune
- Deletes resources from the cluster that were removed from Git
- Without prune, removing a YAML file from Git leaves the resource running
- `syncPolicy.automated.prune: true`

## Sync Waves and Hooks

### Sync Waves
Control the order resources are applied using annotations:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"   # Lower numbers sync first
```
Use case: create Namespace (wave 0) before Deployment (wave 1).

### Resource Hooks
Run Jobs at specific points in the sync lifecycle:
- **PreSync**: run before sync (e.g., database migrations)
- **Sync**: run during sync
- **PostSync**: run after sync (e.g., integration tests)
- **SyncFail**: run if sync fails (e.g., notifications)

## Multi-Environment Patterns

### Pattern 1: Directory per Environment
```
environments/
├── dev/
├── staging/
└── prod/
```
Each directory has its own manifests. ArgoCD Application points to the right directory.

### Pattern 2: Kustomize Overlays (this project)
```
environments/
├── base/          # Shared manifests
├── dev/           # Patches for dev
├── staging/       # Patches for staging
└── prod/          # Patches for prod
```
Base + overlay = final manifests. Reduces duplication.

### Pattern 3: Helm Values per Environment
```
chart/
├── Chart.yaml
├── values.yaml          # Defaults
├── values-dev.yaml      # Dev overrides
├── values-staging.yaml
└── values-prod.yaml
```

### Environment Promotion Flow
```
Git push → dev auto-syncs → QA verifies → update staging overlay →
staging syncs → verify → update prod overlay → prod syncs
```

## ArgoCD vs Other CD Tools

| Feature          | ArgoCD         | Flux              | Jenkins CD       | Spinnaker        |
|------------------|----------------|-------------------|------------------|------------------|
| Model            | Pull (GitOps)  | Pull (GitOps)     | Push             | Push             |
| K8s native       | Yes (CRDs)     | Yes (CRDs)        | No               | Partial          |
| UI               | Rich web UI    | Minimal (Weave)   | Plugin-based     | Rich UI          |
| Multi-cluster    | Yes            | Yes               | Manual           | Yes              |
| Manifest tools   | Kustomize, Helm, Jsonnet | Kustomize, Helm | Any     | Helm, raw        |
| Sync detection   | 3min poll + webhook | Configurable  | Trigger-based    | Pipeline-based   |
| Rollback         | One-click      | Git revert        | Re-run pipeline  | Built-in         |
| RBAC             | AppProject     | K8s RBAC          | Jenkins roles    | Built-in         |
| Learning curve   | Moderate       | Moderate          | High             | High             |

## Architecture

```
┌─────────────┐         ┌──────────────────────────────────────────┐
│  Git Repo   │◄────────│  Repo Server                             │
│  (source    │  poll/   │  - Clones repos                         │
│   of truth) │  webhook │  - Renders manifests (Kustomize/Helm)   │
└─────────────┘         └──────────────┬───────────────────────────┘
                                       │
                        ┌──────────────▼───────────────────────────┐
                        │  Application Controller                   │
                        │  - Compares desired state vs live state   │
                        │  - Triggers sync when OutOfSync           │
                        │  - Reports health status                  │
                        └──────────────┬───────────────────────────┘
                                       │
                        ┌──────────────▼───────────────────────────┐
                        │  API Server                               │
                        │  - Serves the Web UI and CLI API          │
                        │  - Handles authentication (SSO, RBAC)     │
                        │  - Manages Application CRDs               │
                        └──────────────────────────────────────────┘
```

## Key Annotations

| Annotation | Purpose |
|---|---|
| `argocd.argoproj.io/sync-wave: "N"` | Control sync order |
| `argocd.argoproj.io/hook: PreSync` | Run as a sync hook |
| `argocd.argoproj.io/managed-by: argocd` | Mark as ArgoCD-managed |
| `argocd.argoproj.io/compare-options: IgnoreExtraneous` | Ignore extra fields in diff |
| `argocd.argoproj.io/sync-options: Prune=false` | Prevent pruning this resource |

## Quick Reference

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# CLI login
argocd login localhost:8080 --insecure

# Deploy an app
argocd app create my-app --repo <url> --path <path> --dest-server https://kubernetes.default.svc --dest-namespace default

# Sync
argocd app sync my-app

# Rollback
argocd app rollback my-app <history-id>
```
