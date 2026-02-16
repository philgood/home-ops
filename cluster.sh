#!/bin/bash

echo "=== Fixing VolSync across entire cluster ==="
echo ""

# 1. Remove privileged-movers from all namespaces
echo "Step 1: Removing privileged-movers annotation from all namespaces..."
for ns in $(kubectl get ns -o json | jq -r '.items[] | select(.metadata.annotations["volsync.backube/privileged-movers"] == "true") | .metadata.name'); do
    echo "  Removing from namespace: $ns"
    kubectl annotate namespace $ns volsync.backube/privileged-movers- --overwrite
done

echo ""
echo "Step 2: Deleting all volsync cache PVCs (will be recreated with correct ownership)..."

# 2. Delete all volsync cache PVCs
kubectl get pvc -A -o json | jq -r '.items[] | select(.metadata.name | contains("volsync-src-") and contains("-cache")) | "\(.metadata.namespace) \(.metadata.name)"' | while read ns name; do
    echo "  Deleting: $ns/$name"
    kubectl delete pvc -n $ns $name --wait=false
done

echo ""
echo "Step 3: Waiting 10 seconds for resources to clean up..."
sleep 10

echo ""
echo "Step 4: Triggering test backups in each namespace..."

# 3. Trigger a backup in each namespace (optional - they'll run on schedule anyway)
for ns in $(kubectl get replicationsource -A -o json | jq -r '.items[].metadata.namespace' | sort -u); do
    echo "  Namespace: $ns"
    for rs in $(kubectl get replicationsource -n $ns -o json | jq -r '.items[].metadata.name'); do
        echo "    Triggering backup for: $rs"
        kubectl patch replicationsource $rs -n $ns --type=merge \
            -p '{"spec":{"trigger":{"manual":"fix-'$(date +%s)'"}}}' 2>/dev/null || true
    done
done

echo ""
echo "=== Done! ==="
echo ""
echo "Monitor backup status with:"
echo "  kubectl get jobs -A | grep volsync"
echo "  kubectl get replicationsource -A"
