# Task: Design node affinity/taint strategy for heterogeneous hardware
Date: 2026-09-17
Status: [ ] Backlog

## Context

The cluster is no longer a uniform 3x Intel N100 fleet. As of 2026-09-16/17:
- `k8s-0/1/2`: Intel N100, iGPU (i915), advertise `gpu.intel.com/i915` via the
  Intel GPU device-plugin (`infrastructure/apps/kube-system/intel-device-plugin/`).
- `k8s-3` (SER5 Pro): AMD, Radeon Vega iGPU (amdgpu extension loaded), no
  device-plugin exposing it yet — currently just a plain schedulable worker.
- A laptop (Acer, Intel i7-4720HQ) is planned to join later for ARC runners +
  koito/multi-scrobbler — another distinct hardware profile.

Right now, workload placement onto the "correct" hardware is mostly
**accidental**, not deliberate:
- Jellyfin currently avoids SER5 only as a side effect of requesting
  `gpu.intel.com/i915` as an extended resource — that resource simply isn't
  advertised on SER5, so the scheduler can't place it there. This works, but
  it's implicit; there's no explicit node affinity/taint expressing "this
  workload wants Intel iGPU hardware."
- Nothing currently stops general-purpose workloads (unrelated to
  transcoding) from landing on SER5 or, later, the laptop, or vice versa —
  no vendor/arch-based labels or taints exist at all.
- If AMD GPU transcoding is ever wired up for SER5 (separate backlog item,
  raised during SER5 onboarding — no `amd.com/gpu`-style device-plugin
  exists in this repo yet), the same accidental-affinity-via-resource-request
  pattern would apply there too, but two different GPU vendors both doing
  implicit affinity via resource requests gets fragile fast (e.g., nothing
  stops Jellyfin from being modified to request both, or a new workload
  forgetting to request either and landing anywhere).

## Scope

**In scope (when this is picked up):**
- Explicit node labels for hardware class (e.g. `hardware.homelab/vendor:
  intel|amd`, or reuse/extend the existing `topology.kubernetes.io/zone`
  convention — check what's already used before inventing a new label).
- Decide whether general-purpose workloads should be taint-restricted away
  from GPU-bearing nodes (SER5, N100s) by default, or left open with
  affinity `preferred` (not `required`) rules so the scheduler still uses
  spare capacity there when idle.
- Decide the affinity/taint story for the laptop once it joins (no-battery,
  CI-only intent per [[2026-09-16_ser5-node-onboarding]] discussion) —
  should probably be tainted `NoSchedule` for anything except ARC runner
  pods and koito/multi-scrobbler, tolerated explicitly by those workloads.
- Revisit Jellyfin's placement once/if AMD GPU transcoding is added — decide
  whether it becomes two workloads (one per GPU vendor) or a single
  deployment with node affinity choosing the right hardware.

**Explicitly out of scope for this note:** actually implementing any of the
above. This is a design/backlog item raised during the SER5 onboarding +
Longhorn migration session, not started.

## Action Items

- [ ] Inventory current implicit affinities (grep all `nodeSelector`,
      `affinity`, and extended-resource `requests` across `infrastructure/`
      and `infrastructure/apps/media-center` — Jellyfin's `gpu.intel.com/i915`
      is the only one found so far, may be others)
- [ ] Decide labeling scheme for hardware class (vendor, arch, GPU presence)
- [ ] Decide taint policy for SER5 and the future laptop
- [ ] Apply labels/taints via `cluster.yaml.j2` per-node overrides (same
      pattern as `k8s-3.yaml.j2`'s `KubeNodeConfig` labels)
- [ ] Update Jellyfin (and any future AMD-transcode workload) to use
      explicit affinity/nodeSelector rather than relying solely on
      extended-resource requests for placement

## Side Issues Found

- No AMD GPU device-plugin exists in this repo — SER5's amdgpu hardware is
  not currently exposed as a schedulable resource to anything. Related but
  separate from this affinity-design task; noted during SER5 onboarding
  ([[2026-09-16_ser5-node-onboarding]]).

## Files Modified

None yet — backlog only.
