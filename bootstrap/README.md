# Bootstrap Guide

Step-by-step rebuild guide for the 3-node MS-01 cluster. Use this if you need to wipe and start over.

---

## Overview

| Layer | Tool |
|-------|------|
| OS | Talos Linux (managed via `talhelper`) |
| Kubernetes | v1.36 (single control-plane pool, all 3 nodes schedulable) |
| GitOps | Flux (deployed via `flux-operator` + `flux-instance`) |
| Secrets | Doppler → External Secrets Operator |
| CNI | Cilium |

---

## Prerequisites

All tooling is managed by `mise`. From the repo root:

```sh
mise install
doppler login    # authenticate the Doppler CLI
```

You will also need:
- The **Doppler service token** for the `kubernetes/prd` config — stored in your password manager as `dp.st.prd.xxx`
- The `talos/talsecret.yaml` file — this is in the git repo

---

## Step 1 — Flash Talos to each MS-01

Each node needs the factory image baked with the correct schematic (i915, intel-ucode, thunderbolt extensions + `i915.enable_guc=3`). The current installer URL is stored in `talconfig.yaml` as `talosImageURL`:

```
factory.talos.dev/metal-installer/6471689ef9198e2867a84e0dc40552e7c3a94cb5d314985518dee17b6c077f8e
```

**Option A — USB**
1. Go to [factory.talos.dev](https://factory.talos.dev) and enter schematic ID `6471689ef9198e2867a84e0dc40552e7c3a94cb5d314985518dee17b6c077f8e`
2. Download the metal ISO for `v1.13.4`
3. Flash to USB (`dd` or Balena Etcher) and boot each node
4. Nodes will boot into maintenance mode — confirm with `talosctl -n <ip> get members --insecure`

**Node IPs and disk serials** (for reference):

| Node | IP | Disk Serial |
|------|----|-------------|
| alpha | 172.20.24.10 | 22323B87679D |
| bravo | 172.20.24.11 | 22323B87677A |
| charlie | 172.20.24.12 | 22323B876870 |

---

## Step 2 — Generate Talos machine configs

```sh
just talos generate-config
```

Reads `talconfig.yaml` + `talsecret.yaml` and writes per-node configs to `talos/clusterconfig/`.

---

## Step 3 — Bootstrap Talos and Kubernetes

```sh
just bootstrap talos
```

This does three things in sequence:
1. Pushes machine configs to each node over the maintenance API (no auth required)
2. Bootstraps etcd on the first control plane node (retries until the API server responds)
3. Downloads `kubeconfig` to the repo root

Takes ~3–5 minutes. You'll see it polling until the API server is up.

---

## Step 4 — Bootstrap core cluster apps

```sh
just bootstrap apps
```

Runs `scripts/bootstrap-apps.sh` which does the following in order:

1. **Waits** for all nodes to reach `Ready=False` (expected pre-CNI state)
2. **Creates namespaces** for every app directory under `kubernetes/apps/`
3. **Applies CRDs** (Gateway API, ExternalDNS, Prometheus Operator) from upstream URLs
4. **Runs helmfile** installing charts in dependency order:

| Chart | Namespace | Purpose |
|-------|-----------|---------|
| Cilium | kube-system | CNI — nodes become `Ready=True` after this |
| CoreDNS | kube-system | Cluster DNS |
| Spegel | kube-system | In-cluster OCI registry mirror |
| cert-manager | cert-manager | TLS certificate management |
| flux-operator | flux-system | Flux lifecycle manager |
| flux-instance | flux-system | Starts syncing this repo |

After `flux-instance` is installed, Flux begins reconciling `kubernetes/flux/cluster` from GitHub.

---

## Step 5 — Create the Doppler bootstrap secret

This is the only secret Flux cannot self-provision — it's needed for External Secrets Operator to talk to Doppler. Create it immediately after step 4:

```sh
kubectl create secret generic doppler-token-secret \
  --from-literal=serviceToken='dp.st.prd.XXXX' \
  --namespace external-secrets
```

Create a fresh service token at rebuild time (use any name — it won't affect existing tokens):

```sh
doppler configs tokens create eso-token-rebuild --project kubernetes --config prd
```

Copy the printed value and use it in the command above. Clean up old tokens from the Doppler UI afterwards.

> If the `external-secrets` namespace doesn't exist yet, step 4 creates it. If you hit a race, just retry after step 4 finishes.

---

## Step 6 — Wait for Flux to converge

Watch kustomizations come up:

```sh
kubectl get kustomization -A -w
```

Expected progression:
1. `cluster-meta` reconciles — syncs HelmRepository and OCIRepository sources
2. `cluster-apps` reconciles — begins deploying all apps
3. Once `external-secrets` is healthy, the `doppler` ClusterSecretStore becomes valid
4. All ExternalSecrets sync from Doppler, unblocking everything that depends on secrets

Full status overview:

```sh
flux get all -A
```

---

## Verification

```sh
kubectl get nodes                   # all three: Ready
kubectl get hr -A                   # all HelmReleases: Ready
kubectl get externalsecret -A       # all ExternalSecrets: SecretSynced
kubectl get certificate -A          # TLS certs issued
```

---

## Troubleshooting

**Nodes stuck `NotReady` after step 3**
Cilium hasn't been deployed yet — this is normal. Step 4 fixes it.

**`just bootstrap apps` fails on helmfile**
Usually a timeout waiting for a previous chart. Re-run `just bootstrap apps` — the script is idempotent and skips resources that are already up-to-date.

**ESO `ClusterSecretStore` not Ready**
The `doppler-token-secret` is missing or in the wrong namespace. Verify:
```sh
kubectl get secret doppler-token-secret -n external-secrets
```

**ExternalSecrets stuck `SecretSyncedError`**
A Doppler key referenced in a template doesn't exist. Check which secret is failing:
```sh
kubectl get externalsecret -A | grep -v SecretSynced
kubectl describe externalsecret <name> -n <namespace>
```
Add the missing key to Doppler (`kubernetes/prd`) and it will retry automatically.

**Flux not pulling from GitHub**
Check the GitRepository:
```sh
kubectl get gitrepository -n flux-system flux-system
```
The repo is public HTTPS — no deploy key needed. If you see auth errors, check the URL in `kubernetes/apps/flux-system/flux-instance/app/helm/values.yaml`.

---

## Key files

| File | Purpose |
|------|---------|
| `talos/talconfig.yaml` | Node IPs, disk serials, schematic, patches |
| `talos/talsecret.yaml` | Talos cluster PKI — **back this up outside git** |
| `talos/talenv.yaml` | Talos + Kubernetes versions (updated by Renovate) |
| `bootstrap/helmfile.yaml` | Bootstrap chart sequence |
| `scripts/bootstrap-apps.sh` | Orchestration script for `just bootstrap apps` |

---

## Doppler secrets

All app secrets live in the **`kubernetes / prd`** Doppler config. The cluster will not fully converge until they are populated. The Doppler service token is the only credential that lives outside Doppler — but you don't need to store it. Just create a new one at rebuild time as shown in Step 5.

To update a secret:
```sh
doppler secrets set KEY_NAME="value" --project kubernetes --config prd
```

ESO refreshes ExternalSecrets on a 1-hour interval by default. To force immediate sync:
```sh
kubectl annotate externalsecret <name> -n <namespace> \
  force-sync=$(date +%s) --overwrite
```
