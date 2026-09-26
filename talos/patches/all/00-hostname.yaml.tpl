---
# topf uses nodes[].host only for display and selection, so without this Talos
# falls back to auto: stable and the node comes up as talos-xxx-xxx. Renaming
# the nodes would re-register them in Kubernetes under new names and break
# Ceph's OSD host placement, node labels and every node-local PV binding.
#
# This is a .tpl so {{ .Node.Host }} resolves per node; plain .yaml patches are
# not templated.
apiVersion: v1alpha1
kind: HostnameConfig
auto: "off"
hostname: {{ .Node.Host }}
