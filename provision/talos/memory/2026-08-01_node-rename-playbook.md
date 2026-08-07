# Task: Talos Node Rename (stableHostname → HostnameConfig)
Date: 2026-08-01
Status: [ ] In Progress

## Context

The cluster has been running with `machine.features.stableHostname: true` which causes Talos to generate random hostnames (`talos-udu-bcv`, `talos-bdf-jh3`, `talos-qku-4wz`). The node patches also declare `HostnameConfig` documents with the intended names (`k8s-0`, `k8s-1`, `k8s-2`). These two mechanisms are mutually exclusive — the current config fails Talos validation and has been unapplicable for ~6 months.

This playbook resolves the conflict by removing `stableHostname` and letting `HostnameConfig` take effect, renaming nodes to their intended names. It must be completed before the Talos 1.14 multi-document migration.

## Node Map

| IP | Current hostname | Target hostname | Role |
|----|-----------------|-----------------|------|
| 10.1.20.11 | `talos-udu-bcv` | `k8s-0` | control-plane |
| 10.1.20.12 | `talos-bdf-jh3` | `k8s-1` | worker |
| 10.1.20.13 | `talos-qku-4wz` | `k8s-2` | worker |

## Scope

**In scope:**
- Remove `stableHostname: true` from base config template
- Rename all three nodes to their `HostnameConfig` target names
- Patch PersistentVolume node affinity after each rename
- Verify Longhorn health between each node rename

**Explicitly out of scope:**
- Talos 1.14 multi-document migration (separate task, stacked after this)
- Topology zone label changes (all nodes are `zone: m`; no change needed now)
- Renovate Talos/K8s version updates (hold merges until this is complete)

## Decisions Made

### Order: workers first, control plane last
k8s-1 → k8s-2 → k8s-0. Workers can be safely drained without apiserver impact. The control plane reboot causes a brief apiserver outage (~1–3 min); doing it last means workers are already stable with correct hostnames.

### PV node affinity: patch in-place, one node at a time
9 PVs have `spec.nodeAffinity` referencing `talos-*` hostnames. After each rename, patch those PVs to replace the old hostname with the new one. This is done with `kubectl replace` after a jq transformation — not `kubectl apply` (PVs created by Longhorn lack the last-applied annotation).

### Longhorn: delete stale node object, let Longhorn rebuild replicas
After each rename, the old Longhorn `nodes.longhorn.io` object (e.g. `talos-bdf-jh3`) will be Down. Delete it explicitly so Longhorn stops tracking it. Longhorn will rebuild the 3rd replica on the new node. Wait for all volumes to return to 3 healthy replicas before proceeding to the next node. Never rename two nodes simultaneously.

---

## Pre-flight Checklist

Run these before touching anything. Do not proceed if any check fails.

```bash
# 1. Cluster health
kubectl --kubeconfig ~/.kube/homelab-config get nodes -o wide

# 2. All pods running (no crash loops or pending)
kubectl --kubeconfig ~/.kube/homelab-config get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded | grep -v Completed

# 3. Longhorn all volumes healthy
kubectl --kubeconfig ~/.kube/homelab-config -n longhorn-system get volumes.longhorn.io \
  -o custom-columns='NAME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness'
# Expected: all rows show state=attached or detached, robustness=healthy

# 4. Talos health on all nodes
talosctl --talosconfig ~/.config/homelab/talosconfig health --wait-timeout 2m

# 5. Confirm no Renovate Talos/K8s PRs are in flight that you haven't reviewed
# (check your repo's open PRs manually — don't merge any Talos version bumps until this is done)
```

---

## Step 1: Template Fix (do once, before any node work)

Edit `provision/talos/machineconfig.yaml.j2`. Remove the single line:

```yaml
    stableHostname: true
```

That line is at `machine.features.stableHostname`. The `features` block will remain; only this one key is removed.

After editing, verify the render works and dry-run against all three nodes:

```bash
# Render to stdout — must produce valid YAML with no errors
just talos render-config-sops k8s-0
just talos render-config-sops k8s-1
just talos render-config-sops k8s-2

# Dry-run each node — must succeed with no validation errors
# (expect diffs: hostname will change, stableHostname removed)
sops exec-env provision/talos/secrets.sops.yaml \
  'config=$(just talos render-config k8s-1) && \
   echo "$config" | talosctl --talosconfig ~/.config/homelab/talosconfig \
   --nodes 10.1.20.12 apply-config --file /dev/stdin --dry-run'

sops exec-env provision/talos/secrets.sops.yaml \
  'config=$(just talos render-config k8s-2) && \
   echo "$config" | talosctl --talosconfig ~/.config/homelab/talosconfig \
   --nodes 10.1.20.13 apply-config --file /dev/stdin --dry-run'

sops exec-env provision/talos/secrets.sops.yaml \
  'config=$(just talos render-config k8s-0) && \
   echo "$config" | talosctl --talosconfig ~/.config/homelab/talosconfig \
   --nodes 10.1.20.11 apply-config --file /dev/stdin --dry-run'
```

The dry-run output should show the removal of `stableHostname` and the hostname change. No other diffs expected. If you see unexpected diffs (image versions, extra fields), investigate before proceeding.

---

## PV Patch Script

Save this as a reusable function — you'll call it after each node rename. It replaces `OLD` with `NEW` in the `kubernetes.io/hostname` values of every affected PV's node affinity.

```bash
patch_pv_node_affinity() {
  local OLD="$1"
  local NEW="$2"

  echo "Patching PVs: replacing '${OLD}' → '${NEW}'"

  local pvs
  pvs=$(kubectl --kubeconfig ~/.kube/homelab-config get pv -o json | \
    jq -r --arg old "$OLD" '
      .items[] |
      select(
        .spec.nodeAffinity.required.nodeSelectorTerms[]?.matchExpressions[]? |
        select(.key == "kubernetes.io/hostname") |
        .values[] == $old
      ) |
      .metadata.name
    ' | sort -u)

  if [[ -z "$pvs" ]]; then
    echo "No PVs reference '${OLD}' — nothing to patch."
    return 0
  fi

  echo "PVs to patch: ${pvs}"

  for pv in $pvs; do
    echo "  Patching PV: ${pv}"
    kubectl --kubeconfig ~/.kube/homelab-config get pv "$pv" -o json | \
      jq --arg old "$OLD" --arg new "$NEW" '
        .spec.nodeAffinity.required.nodeSelectorTerms |= map(
          .matchExpressions |= map(
            if .key == "kubernetes.io/hostname" then
              .values |= map(if . == $old then $new else . end)
            else . end
          )
        )
      ' | \
      kubectl --kubeconfig ~/.kube/homelab-config replace -f -
    echo "  Done: ${pv}"
  done

  echo "PV patching complete for '${OLD}' → '${NEW}'"
}
```

---

## Rename Procedure (repeat for each node in order)

### Node k8s-1 (10.1.20.12 · talos-bdf-jh3 → k8s-1)

```bash
# --- 1. Drain the node ---
kubectl --kubeconfig ~/.kube/homelab-config drain talos-bdf-jh3 \
  --ignore-daemonsets --delete-emptydir-data --timeout=5m
# Wait until drain completes. DaemonSet pods are evicted implicitly.

# --- 2. Apply config ---
just talos apply-node-sops k8s-1
# Expected output: "Config applied node=k8s-1"
# No reboot is triggered by apply alone — hostname changes require reboot.

# --- 3. Reboot the node ---
just talos reboot-node k8s-1
# This reboots 10.1.20.12. The node will come up with hostname k8s-1.

# --- 4. Wait for the new node to appear ---
# Poll until k8s-1 is Ready. The old talos-bdf-jh3 Node object will disappear.
watch kubectl --kubeconfig ~/.kube/homelab-config get nodes -o wide
# Expected: talos-bdf-jh3 gone; k8s-1 appears as Ready (may take 2–4 min)

# --- 5. Verify Talos reports new hostname ---
talosctl --talosconfig ~/.config/homelab/talosconfig -n 10.1.20.12 get nodename
# Expected: NODENAME = k8s-1

# --- 6. Clean up stale Longhorn node ---
kubectl --kubeconfig ~/.kube/homelab-config -n longhorn-system \
  delete node.longhorn.io talos-bdf-jh3 --ignore-not-found
# This removes the "Down" Longhorn node object for the old hostname.
# Longhorn will create a new nodes.longhorn.io/k8s-1 automatically.

# --- 7. Patch PV node affinity ---
patch_pv_node_affinity "talos-bdf-jh3" "k8s-1"

# --- 8. Uncordon the new node ---
kubectl --kubeconfig ~/.kube/homelab-config uncordon k8s-1

# --- 9. Verify Longhorn replica rebuild ---
# Longhorn will rebuild the replica that was on talos-bdf-jh3 onto k8s-1.
# Wait until all volumes return to robustness=healthy (3/3 replicas).
watch kubectl --kubeconfig ~/.kube/homelab-config -n longhorn-system get volumes.longhorn.io \
  -o custom-columns='NAME:.metadata.name,ROBUSTNESS:.status.robustness'
# Do NOT proceed to k8s-2 until all volumes show robustness=healthy.
# Rebuild may take several minutes per volume depending on size.

# --- 10. Spot-check Longhorn node state ---
kubectl --kubeconfig ~/.kube/homelab-config -n longhorn-system get nodes.longhorn.io
# Expected: k8s-1, talos-qku-4wz, talos-udu-bcv — all Ready
```

---

### Node k8s-2 (10.1.20.13 · talos-qku-4wz → k8s-2)

Repeat the same procedure with substitutions:

| Variable | Value |
|----------|-------|
| `kubectl drain` target | `talos-qku-4wz` |
| `just talos apply-node-sops` arg | `k8s-2` |
| `just talos reboot-node` arg | `k8s-2` |
| Talosctl `-n` target | `10.1.20.13` |
| Expected new nodename | `k8s-2` |
| Longhorn node to delete | `talos-qku-4wz` |
| `patch_pv_node_affinity` args | `"talos-qku-4wz" "k8s-2"` |
| Uncordon target | `k8s-2` |

Same gate: do not proceed to k8s-0 until all volumes are `robustness=healthy`.

---

### Node k8s-0 (10.1.20.11 · talos-udu-bcv → k8s-0, CONTROL PLANE)

**Warning:** k8s-0 is the only control plane node. When it reboots, etcd and kube-apiserver go down. `kubectl` will be unavailable for ~1–3 minutes. Workers continue running existing pods but cannot call the API during that window. This is expected.

```bash
# --- 1. Drain the control plane node ---
# allowSchedulingOnControlPlanes is true, so pods may run here.
kubectl --kubeconfig ~/.kube/homelab-config drain talos-udu-bcv \
  --ignore-daemonsets --delete-emptydir-data --timeout=5m

# --- 2. Apply config ---
just talos apply-node-sops k8s-0

# --- 3. Reboot the node ---
just talos reboot-node k8s-0
# kubectl commands will fail during the reboot window — this is expected.

# --- 4. Wait for the control plane to come back ---
# Poll talosctl directly (doesn't need kube-apiserver).
until talosctl --talosconfig ~/.config/homelab/talosconfig -n 10.1.20.11 get nodename 2>/dev/null | grep -q k8s-0; do
  echo "Waiting for k8s-0..."; sleep 5
done
echo "k8s-0 hostname confirmed"

# Wait for kube-apiserver to become available
until kubectl --kubeconfig ~/.kube/homelab-config get nodes &>/dev/null; do
  echo "Waiting for apiserver..."; sleep 5
done
echo "API server available"

# --- 5. Verify all nodes are Ready ---
kubectl --kubeconfig ~/.kube/homelab-config get nodes -o wide
# Expected: k8s-0 (cp), k8s-1 (worker), k8s-2 (worker) — all Ready

# --- 6. Clean up stale Longhorn node ---
kubectl --kubeconfig ~/.kube/homelab-config -n longhorn-system \
  delete node.longhorn.io talos-udu-bcv --ignore-not-found

# --- 7. Patch PV node affinity ---
patch_pv_node_affinity "talos-udu-bcv" "k8s-0"

# --- 8. Uncordon ---
kubectl --kubeconfig ~/.kube/homelab-config uncordon k8s-0

# --- 9. Verify Longhorn replica rebuild ---
watch kubectl --kubeconfig ~/.kube/homelab-config -n longhorn-system get volumes.longhorn.io \
  -o custom-columns='NAME:.metadata.name,ROBUSTNESS:.status.robustness'
# Wait for all volumes: robustness=healthy
```

---

## Post-Completion Verification

Run all of these. Every check must pass before declaring done.

```bash
# 1. All nodes Ready with correct names
kubectl --kubeconfig ~/.kube/homelab-config get nodes -o wide
# Expected: k8s-0 (control-plane), k8s-1, k8s-2 — all Ready

# 2. No stale talos-* node objects remain
kubectl --kubeconfig ~/.kube/homelab-config get nodes | grep talos
# Expected: no output

# 3. No stale Longhorn node objects
kubectl --kubeconfig ~/.kube/homelab-config -n longhorn-system get nodes.longhorn.io
# Expected: k8s-0, k8s-1, k8s-2 — all Ready, ALLOWSCHEDULING=true

# 4. All Longhorn volumes healthy
kubectl --kubeconfig ~/.kube/homelab-config -n longhorn-system get volumes.longhorn.io \
  -o custom-columns='NAME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness'
# Expected: all robustness=healthy

# 5. PV node affinity references no talos-* names
kubectl --kubeconfig ~/.kube/homelab-config get pv -o json | \
  jq -r '[.items[].spec.nodeAffinity.required.nodeSelectorTerms[]?.matchExpressions[]? |
    select(.key == "kubernetes.io/hostname") | .values[]] | unique[]' | grep talos
# Expected: no output

# 6. Talos health check
talosctl --talosconfig ~/.config/homelab/talosconfig health --wait-timeout 2m

# 7. All pods running
kubectl --kubeconfig ~/.kube/homelab-config get pods -A | grep -v Running | grep -v Completed
# Expected: only header line
```

---

## Rollback

### If a node doesn't come back after reboot

```bash
# Check Talos boot status via talosctl (works even before k8s joins)
talosctl --talosconfig ~/.config/homelab/talosconfig -n <node-ip> dmesg | tail -50
talosctl --talosconfig ~/.config/homelab/talosconfig -n <node-ip> logs machined
```

If the config was rejected and the node is stuck, Talos may have reverted to the previous config (it does this on apply failure if `--mode=reboot` is not forced). In that case the node comes back with the old hostname. Re-evaluate the rendered config for errors.

### If Longhorn volumes degrade below 1 replica

Do not proceed. Stop all rename operations. Let Longhorn attempt to rebuild on available nodes. Only continue once robustness is back to `healthy` or `degraded` (not `faulted`). A faulted volume requires Longhorn recovery procedures outside the scope of this playbook.

### If PV patching breaks a PVC binding

Check which pods reference the affected PVC:
```bash
kubectl --kubeconfig ~/.kube/homelab-config get pods -A -o json | \
  jq -r --arg pv "<pv-name>" '.items[] | select(
    .spec.volumes[]?.persistentVolumeClaim.claimName? != null
  ) | .metadata.namespace + "/" + .metadata.name'
```

Re-patch the PV with the correct new hostname. A pod will need to be deleted and rescheduled to re-attach.

---

## Side Issues Found

- **Topology region/zone labels absent from live nodes**: `topology.kubernetes.io/region` and `topology.kubernetes.io/zone` have never been applied. All three node patches set `zone: m` (identical, no differentiation). No workloads currently reference these labels. Defer to the 1.14 migration task — decide zone strategy then.
- **GPU label source ambiguous**: `intel.feature.node.kubernetes.io/gpu: "true"` is on live nodes but unclear whether it came from the Talos config or from the Intel GPU device plugin / NFD controller. If NFD sets it, the Talos config copy is redundant. Audit after rename is stable.

## Files Modified

- `provision/talos/machineconfig.yaml.j2` — remove `stableHostname: true`

## Action Items

- [ ] Run pre-flight checks
- [ ] Remove `stableHostname: true` from `machineconfig.yaml.j2`
- [ ] Dry-run all three nodes, verify no unexpected diffs
- [ ] Rename k8s-1 (talos-bdf-jh3 → k8s-1)
- [ ] Rename k8s-2 (talos-qku-4wz → k8s-2)
- [ ] Rename k8s-0 (talos-udu-bcv → k8s-0)
- [ ] Run post-completion verification
- [ ] Update this memory entry: mark done, record any deviations
- [ ] Resume Renovate Talos/K8s update PRs
- [ ] Open new task: Talos 1.14 multi-document migration
