set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just --list kube

[doc('Force Flux to sync all resources of a given type [resource=hr|ks|gitrepo|ocirepo|es]')]
sync resource:
    #!/usr/bin/env bash
    set -euo pipefail
    kubectl get "{{ resource }}" --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite "{{ resource }}" "$name" \
            "reconcile.fluxcd.io/requestedAt=$(date +%s)" \
            "reconcile.fluxcd.io/forceAt=$(date +%s)"
    done

[doc('Sync all ExternalSecrets')]
sync-secrets:
    #!/usr/bin/env bash
    set -euo pipefail
    kubectl get externalsecret --all-namespaces --no-headers \
        --output=jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name}{"\n"}{end}' \
        | while IFS=',' read -r ns name; do
            kubectl --namespace "$ns" annotate externalsecret "$name" \
                force-sync="$(date +%s)" --overwrite
        done

[doc('Mount a PVC in a temporary Alpine container [ns=default] [claim=required]')]
browse-pvc ns claim:
    kubectl run -n "{{ ns }}" "browse-pvc-{{ claim }}" -it --rm --restart=Never \
        --image=docker.io/library/alpine:latest \
        --overrides='{"spec":{"containers":[{"name":"browse","image":"docker.io/library/alpine:latest","stdin":true,"tty":true,"command":["/bin/sh"],"workingDir":"/mnt","volumeMounts":[{"mountPath":"/mnt","name":"data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"{{ claim }}"}}]}}'

[doc('Open a privileged shell on a node [node=required]')]
node-shell node:
    kubectl node-shell -n kube-system -x "{{ node }}"

[doc('Delete pods in Failed, Pending, or Succeeded phase')]
cleanse-pods:
    #!/usr/bin/env bash
    set -euo pipefail
    for phase in Failed Pending Succeeded; do
        kubectl delete pods --all-namespaces --field-selector "status.phase=$phase" --ignore-not-found=true
    done

[doc('View a decoded secret [ns=required] [secret=required]')]
view-secret ns secret:
    kubectl view-secret -n "{{ ns }}" "{{ secret }}"

[doc('Gather common cluster resources (useful for bug reports)')]
resources:
    #!/usr/bin/env bash
    set -euo pipefail
    for resource in nodes gitrepositories kustomizations helmrepositories helmreleases certificates pods; do
        echo "--- $resource ---"
        kubectl get "$resource" -A
    done
