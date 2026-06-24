set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

scripts_dir := justfile_dir() / "scripts"
talos_dir   := justfile_dir() / "talos"

[private]
default:
    just --list bootstrap

[confirm('Bootstrap the Talos cluster? [y|N]')]
[doc('Bootstrap Talos and Kubernetes end-to-end')]
talos:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    [ -f talsecret.sops.yaml ] || \
        talhelper gensecret | sops --filename-override talos/talsecret.sops.yaml --encrypt /dev/stdin > talsecret.sops.yaml
    talhelper genconfig
    talhelper gencommand apply --extra-flags="--insecure" | bash
    until talhelper gencommand bootstrap | bash; do sleep 10; done
    until talhelper gencommand kubeconfig --extra-flags="{{ justfile_dir() }} --force" | bash; do sleep 10; done

[doc('Bootstrap core apps into the cluster (Cilium, Flux, etc.)')]
apps:
    bash "{{ scripts_dir }}/bootstrap-apps.sh"
