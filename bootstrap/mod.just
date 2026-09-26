set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

scripts_dir := justfile_dir() / "scripts"
talos_dir   := justfile_dir() / "talos"

# The cluster PKI lives in Doppler and reaches topf as vals references in
# talos/talsecret.yaml.
doppler := "doppler run -p talos -c prd --"

[private]
default:
    just --list bootstrap

[confirm('Bootstrap the Talos cluster? [y|N]')]
[doc('Bootstrap Talos and Kubernetes end-to-end')]
talos:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    # No secret generation here on purpose. The cluster PKI already exists in
    # Doppler (project talos, config prd); minting a new bundle would orphan
    # every existing node, certificate and kubeconfig. To stand up a genuinely
    # new cluster, create the bundle deliberately with `topf secrets` and store
    # it in Doppler first.
    {{ doppler }} topf apply --auto-bootstrap
    {{ doppler }} topf talosconfig > talosconfig
    {{ doppler }} topf kubeconfig > "{{ justfile_dir() }}/kubeconfig"

[doc('Bootstrap core apps into the cluster (Cilium, Flux, etc.)')]
apps:
    bash "{{ scripts_dir }}/bootstrap-apps.sh"
