set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just --list volsync

[doc('Suspend or resume VolSync [state=suspend|resume]')]
state state:
    flux -n volsync-system "{{ state }}" kustomization volsync
    flux -n volsync-system "{{ state }}" helmrelease volsync
    kubectl -n volsync-system scale deployment volsync \
        --replicas {{ if state != "suspend" { "1" } else { "0" } }}

[doc('Trigger an immediate snapshot for all ReplicationSources')]
snapshot:
    #!/usr/bin/env bash
    set -euo pipefail
    kubectl get replicationsources --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" patch replicationsources "$name" \
            --type merge -p "{\"spec\":{\"trigger\":{\"manual\":\"$(date +%s)\"}}}"
    done

[doc('Trigger an immediate snapshot for a single app [ns=required] [app=required]')]
snapshot-app ns app:
    #!/usr/bin/env bash
    set -euo pipefail
    kubectl -n "{{ ns }}" patch replicationsources "{{ app }}" \
        --type merge -p "{\"spec\":{\"trigger\":{\"manual\":\"$(date +%s)\"}}}"
    until kubectl -n "{{ ns }}" get job/volsync-src-"{{ app }}" &>/dev/null; do sleep 5; done
    kubectl -n "{{ ns }}" wait job/volsync-src-"{{ app }}" --for=condition=complete --timeout=120m

[confirm('Restore app from VolSync? This will scale the app to 0. [y|N]')]
[doc('Restore an app from its latest VolSync snapshot [ns=required] [app=required] [previous=0]')]
restore ns app previous='0':
    #!/usr/bin/env bash
    set -euo pipefail
    flux -n "{{ ns }}" suspend kustomization "{{ app }}"
    flux -n "{{ ns }}" suspend helmrelease "{{ app }}"
    kubectl -n "{{ ns }}" get deploy,sts -l "app.kubernetes.io/name={{ app }}" -o name \
        | xargs -r -I{} kubectl -n "{{ ns }}" scale {} --replicas=0
    kubectl -n "{{ ns }}" wait pod --for=delete --selector="app.kubernetes.io/name={{ app }}" --timeout=5m
    kubectl -n "{{ ns }}" get replicationdestination "{{ app }}-dst" -o json \
        | jq 'del(.status)
            | .metadata = {name: "{{ app }}-manual", namespace: .metadata.namespace}
            | .spec.kopia.copyMethod = "Direct"
            | .spec.kopia.destinationPVC = "{{ app }}"
            | .spec.kopia.previous = {{ previous }}' \
        | kubectl apply --server-side -f -
    kubectl -n "{{ ns }}" wait job/volsync-dst-"{{ app }}"-manual --for=create --timeout=120s
    kubectl -n "{{ ns }}" wait job/volsync-dst-"{{ app }}"-manual --for=condition=complete --timeout=120m
    kubectl -n "{{ ns }}" delete replicationdestination "{{ app }}-manual"
    flux -n "{{ ns }}" resume kustomization "{{ app }}"
    flux -n "{{ ns }}" resume helmrelease "{{ app }}"
    flux -n "{{ ns }}" reconcile helmrelease "{{ app }}" --force
    kubectl -n "{{ ns }}" wait pod --for=condition=ready --selector="app.kubernetes.io/name={{ app }}" --timeout=5m
