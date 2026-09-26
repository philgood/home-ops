set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

# source_dir() resolves to the talos/ directory where this mod.just lives
talos_dir := source_dir()

# Every recipe that renders config needs the cluster PKI, which lives in
# Doppler and reaches topf as vals ${VAR} references in talsecret.yaml.
doppler := "doppler run -p talos -c prd --"

[private]
default:
    just --list talos

[doc('Render machine configs to talos/output (gitignored -- they hold the PKI)')]
render:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    {{ doppler }} topf render

[doc('Show what would change on every node without applying anything')]
diff:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    {{ doppler }} topf apply --dry-run

[confirm('Apply Talos machine config to every node? [y|N]')]
[doc('Apply machine config to all nodes')]
apply:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    {{ doppler }} topf apply

[confirm('Apply Talos machine config to this node? [y|N]')]
[doc('Apply machine config to a single node [node=hostname]')]
apply-node node:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    # --nodes-filter takes a regex, so anchor it or a name can match its
    # neighbours. Control-plane nodes are applied one at a time regardless.
    {{ doppler }} topf apply --nodes-filter "^{{ node }}$"

[doc('Write talos/talosconfig for talosctl from the secrets bundle')]
talosconfig:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    {{ doppler }} topf talosconfig > talosconfig

[confirm('Upgrade Talos out of band? tuppr normally drives this. [y|N]')]
[doc('Upgrade Talos on all nodes -- tuppr TalosUpgrade normally does this')]
upgrade-talos:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    {{ doppler }} topf upgrade

[confirm('Upgrade Kubernetes out of band? tuppr normally drives this. [y|N]')]
[doc('Upgrade Kubernetes across the cluster -- tuppr KubernetesUpgrade normally does this')]
upgrade-k8s:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    version=$(yq '.kubernetesVersion' topf.yaml)
    talosctl upgrade-k8s --to "${version}"

[confirm('Reboot node? [y|N]')]
[doc('Reboot a node [node=IP]')]
reboot-node node:
    talosctl -n "{{ node }}" reboot -m powercycle

[confirm('Reset ALL nodes to maintenance mode? This destroys the cluster. [y|N]')]
[doc('Reset all nodes back to maintenance mode')]
reset:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ talos_dir }}"
    {{ doppler }} topf reset --full=false --graceful=false
