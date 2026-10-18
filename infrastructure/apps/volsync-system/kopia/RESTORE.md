# Restoring an app from the Kopia repository

Use this when an app's PVC is lost or corrupted. It restores **directly from the Kopia
repository**, not through VolSync's `ReplicationDestination` (`<app>-dst`).

> **Why not `<app>-dst`?** It restores fine, but then stores the result as a Longhorn
> `type: snap` VolumeSnapshot taken *inside* a temporary volume that VolSync deletes
> right afterwards. The snapshot object stays `readyToUse`, but creating a PVC from it
> fails (`failed to verify data source: volume pvc-… not found`). Seen on koito and on
> the June silverbullet snapshot, 2026-10-18. Follow-up: try `copyMethod: Direct`.

**Drill status (koito, 2026-10-18):** steps 1-4 tested end to end (2,946 files / 503 MB,
SQLite integrity ok). Step 5 is the same `tar | kubectl exec` streaming used to seed the
koito and scrobbler PVCs, but has not been drilled as a *recovery* yet.

Every `kubectl` below needs `--kubeconfig ~/.kube/homelab-config`. Set `APP` and `NS`
(e.g. `APP=koito`, `NS=selfhosted`); the Kopia source is `APP@NS:/data`.

## 1. Start a throwaway Kopia pod

It must run in `volsync-system`: `kopia-secret` only exists there (same pattern as
`cronjob-policy-enforce.yaml`).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kopia-restore
  namespace: volsync-system
spec:
  restartPolicy: Never
  securityContext: {runAsNonRoot: true, runAsUser: 1000, runAsGroup: 1000, fsGroup: 1000, seccompProfile: {type: RuntimeDefault}}
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms: [{matchExpressions: [{key: node-role.kubernetes.io/control-plane, operator: DoesNotExist}]}]
  containers:
    - name: kopia
      image: ghcr.io/home-operations/kopia:0.23.1@sha256:27da0a33b44e1b902150a6c963514237217464bb13118a95bb056667be93cda5  # keep in sync with cronjob-policy-enforce.yaml
      command: [sleep, "3600"]
      envFrom: [{secretRef: {name: kopia-secret}}]
      securityContext: {allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: {drop: [ALL]}}
      resources: {requests: {cpu: 10m, memory: 64Mi}, limits: {memory: 512Mi}}
      volumeMounts:
        - {name: config, mountPath: /config}
        - {name: config-file, mountPath: /config/repository.config, subPath: repository.config}
        - {name: tmp, mountPath: /tmp}
  volumes:
    - {name: config, emptyDir: {}}
    - {name: config-file, secret: {secretName: kopia-secret}}
    - {name: tmp, emptyDir: {sizeLimit: 5Gi}}   # must fit the whole restore
```

## 2. Find the snapshot

```sh
K="kubectl exec -n volsync-system kopia-restore -- kopia --config-file /config/repository.config"
$K snapshot list "$APP@$NS:/data" --json | jq -r '.[] | "\(.id)  \(.startTime)"' | tail -10
```

Plain `snapshot list` printed "No snapshots found" for the same source; `--json` (or `--all`)
showed them. Snapshots are daily or hourly per app; the retention is in `configmap-policies.yaml`.

## 3. Restore into the pod

```sh
$K restore <snapshot-id> /tmp/restore
```

Restoring a live SQLite database brings its `-wal`/`-shm` files too; keep the three together.

## 4. Verify before touching anything

For SQLite apps, stream the files out and check locally:

```sh
kubectl exec -n volsync-system kopia-restore -- tar -C /tmp/restore -cf - koito.db koito.db-wal koito.db-shm | tar -xf - -C <empty-dir>
sqlite3 <empty-dir>/koito.db 'PRAGMA integrity_check;'   # expect: ok
```

Compare a row count with what you expect.

## 5. Put it back into the app's PVC (not yet drilled as a recovery)

1. Stop the app so nothing writes: set `replicas: 0` in its HelmRelease via a PR, or `flux suspend hr <app> -n <NS>` and `kubectl scale deploy/<app> -n <NS> --replicas=0`.
2. Make sure the PVC exists and is empty or expendable (recreate it if lost; Flux will recreate it from the app's `pvc.yaml`).
3. Start a small pod **in `$NS`** that mounts the PVC, running as the app's uid (e.g. 1000), same shape as the one used to seed koito.
4. Stream the restored tree across namespaces:
   ```sh
   kubectl exec -n volsync-system kopia-restore -- tar -C /tmp/restore -cf - . \
     | kubectl exec -i -n $NS <seed-pod> -- tar -xf - -C <mountpoint>
   ```
5. Verify file counts/hashes, delete the helper pod, bring the app back (`replicas` back to 1 or `flux resume`).

## 6. Clean up

```sh
kubectl delete pod -n volsync-system kopia-restore
```

Delete any helper pod in `$NS` and any local copy of restored data.
