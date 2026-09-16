# Task: Rotate CLUSTER_SECRETBOX_ENCRYPTION_SECRET
Date: 2026-09-16
Status: [ ] Backlog

## Context

During Talos 1.14 live-vs-rendered machineconfig verification (PR #1719
prep), an ad-hoc diff script's secret-filter matched exact key names
(`crt`/`key`/`token`/`secret`) and missed `secretboxEncryptionSecret` —
the real decrypted value of `CLUSTER_SECRETBOX_ENCRYPTION_SECRET` was
printed in plaintext to the session transcript. Caught and disclosed in
the same message; switched to hash-only comparison for the rest of the
verification (confirmed live vs. rendered values matched via SHA-256,
no other secret printed).

## Scope

Rotate `CLUSTER_SECRETBOX_ENCRYPTION_SECRET` in `secrets.sops.yaml`.
Note: this is etcd's secretbox encryption key (`KubeEtcdEncryptionConfig`,
`key2`) — rotating it requires re-encrypting existing etcd secrets data
under the new key, not just swapping the SOPS field, or existing secrets
become undecryptable. Needs its own careful procedure, not a quick swap.

## Decisions Made

User explicitly deferred rotation: cluster is airgapped in a practical
sense and the session/exposure was local-only, so not urgent. Wants to
rotate eventually anyway given the session's broader secret-hygiene focus
(CLUSTER_SA_KEY corruption incident, argv-exposure fix earlier same day).

## Action Items
- [ ] Design the etcd secretbox key rotation procedure (Talos supports
      multiple encryption keys/providers during transition — check
      `KubeEtcdEncryptionConfig` docs for the recommended rotation flow
      before touching anything live)
- [ ] Rotate `CLUSTER_SECRETBOX_ENCRYPTION_SECRET` in `secrets.sops.yaml`
- [ ] Verify etcd data still decrypts after rotation

## Files Modified
None yet — backlog only.
