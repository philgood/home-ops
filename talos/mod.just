set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

# source_dir() resolves to the talos/ directory where this mod.just lives
talos_dir := source_dir()

[private]
default:
    just --list talos

[doc('Generate Talos machine configs via talhelper')]
generate-config:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    doppler run -p talos -c prd -- talhelper genconfig

[confirm('Apply Talos config to node? [y|N]')]
[doc('Apply Talos config to a node [node=IP] [mode=auto]')]
apply-node node mode="auto":
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    talhelper gencommand apply --node "{{ node }}" --extra-flags "--mode={{ mode }}" | bash

[confirm('Upgrade Talos on node? [y|N]')]
[doc('Upgrade Talos on a single node [node=IP]')]
upgrade-node node:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    talhelper gencommand upgrade --node "{{ node }}" --extra-flags "--timeout=10m" | bash

[doc('Upgrade the Kubernetes version across the cluster')]
upgrade-k8s:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    KUBERNETES_VERSION=$(yq '.kubernetesVersion' talenv.yaml)
    talhelper gencommand upgrade-k8s --extra-flags "--to '${KUBERNETES_VERSION}'" | bash

[confirm('Reboot node? [y|N]')]
[doc('Reboot a node [node=IP]')]
reboot-node node:
    talosctl -n "{{ node }}" reboot -m powercycle

[confirm('Reset ALL nodes to maintenance mode? This destroys the cluster. [y|N]')]
[doc('Reset all nodes back to maintenance mode')]
reset *args:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    talhelper gencommand reset \
        --extra-flags="--reboot --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false --wait=false {{ args }}" \
        | bash
