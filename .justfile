#!/usr/bin/env -S just --justfile

set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

export KUBECONFIG     := justfile_dir() / "kubeconfig"
export SOPS_AGE_KEY_FILE := justfile_dir() / "age.key"
export TALOSCONFIG    := justfile_dir() / "talos/clusterconfig/talosconfig"

[group: 'Bootstrap']
mod bootstrap "bootstrap"

[group: 'Kube']
mod kube "kubernetes"

[group: 'Talos']
mod talos "talos"

[group: 'VolSync']
mod volsync "volsync"

[private]
default:
    just --list

[doc('Force Flux to pull changes from your Git repository')]
reconcile:
    flux --namespace flux-system reconcile kustomization flux-system --with-source

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}
