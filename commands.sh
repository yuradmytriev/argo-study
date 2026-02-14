#!/bin/bash

# =============================================================================
# ARGOCD LEARNING COMMANDS
# =============================================================================
# This file contains useful ArgoCD commands for learning.
# Run these commands one by one to understand what they do.
# =============================================================================


# ----- INSTALL ARGOCD -----

# Create namespace and install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all ArgoCD components to be ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=120s

# Check ArgoCD Pods are running
kubectl get pods -n argocd


# ----- ACCESS THE UI -----

# Port-forward ArgoCD server (UI available at https://localhost:8080)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo


# ----- ARGOCD CLI LOGIN -----

# Install the CLI (macOS)
brew install argocd

# Login to ArgoCD (after port-forwarding)
argocd login localhost:8080 --username admin --password <password> --insecure

# Change the admin password
argocd account update-password


# ----- APPLICATION MANAGEMENT -----

# Create an application from the CLI
argocd app create gitops-demo \
  --repo https://github.com/yuradmytriev/argo-study.git \
  --path k8s \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace gitops-demo

# Or create from a manifest file
kubectl apply -f argocd/application.yaml

# List all applications
argocd app list

# Get detailed info about an app
argocd app get gitops-demo

# View the app's resource tree
argocd app resources gitops-demo


# ----- SYNC OPERATIONS -----

# Sync an app (apply changes from Git to cluster)
argocd app sync gitops-demo

# Sync with prune (delete resources removed from Git)
argocd app sync gitops-demo --prune

# Sync a specific resource only
argocd app sync gitops-demo --resource apps:Deployment:gitops-demo-app

# Dry-run sync (preview changes without applying)
argocd app sync gitops-demo --dry-run

# Force sync (ignore sync waves and hooks)
argocd app sync gitops-demo --force


# ----- DIFF & HISTORY -----

# Show diff between Git and live cluster
argocd app diff gitops-demo

# View sync/deploy history
argocd app history gitops-demo

# Rollback to a previous version (by history ID)
argocd app rollback gitops-demo <history-id>


# ----- HEALTH & STATUS -----

# Check application health
argocd app get gitops-demo -o json | jq '.status.health'

# Check sync status
argocd app get gitops-demo -o json | jq '.status.sync'

# Wait for app to be healthy
argocd app wait gitops-demo --health


# ----- PROJECT MANAGEMENT -----

# List projects
argocd proj list

# Get project details
argocd proj get gitops-demo-project

# Create the demo project from manifest
kubectl apply -f argocd/project.yaml


# ----- APPLICATIONSET -----

# Apply the ApplicationSet (creates apps for dev/staging/prod)
kubectl apply -f argocd/applicationset.yaml

# List all apps (should show gitops-demo-dev, gitops-demo-staging, gitops-demo-prod)
argocd app list


# ----- KUSTOMIZE PREVIEW -----

# Preview what Kustomize generates for each environment
kubectl kustomize environments/base
kubectl kustomize environments/dev
kubectl kustomize environments/staging
kubectl kustomize environments/prod


# ----- BUILD & DEPLOY (for local testing) -----

# Use minikube's Docker daemon
eval $(minikube docker-env)

# Build the app image
docker build -t gitops-demo-app:latest app/

# Apply plain k8s manifests directly (without ArgoCD)
kubectl apply -f k8s/

# Or apply a Kustomize environment directly
kubectl apply -k environments/dev


# ----- DEBUGGING -----

# View ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# View application controller logs
kubectl logs -n argocd deployment/argocd-application-controller

# View repo server logs (handles Git operations)
kubectl logs -n argocd deployment/argocd-repo-server

# Check ArgoCD settings
argocd admin settings resource-overrides list


# ----- CLEANUP -----

# Delete an application (and its resources if finalizer is set)
argocd app delete gitops-demo

# Delete the ApplicationSet
kubectl delete -f argocd/applicationset.yaml

# Uninstall ArgoCD completely
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd
