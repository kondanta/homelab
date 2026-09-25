set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just -l infra

[doc('Apply local Flux Kustomization')]
apply-ks ns ks:
    just infra render-local-ks "{{ ns }}" "{{ ks }}" | kubectl apply --server-side --force-conflicts --field-manager=kustomize-controller -f -

[doc('Browse a PVC')]
browse-pvc ns claim:
    kubectl run -n {{ ns }} browse-pvc-{{ claim }} -it --rm --restart=Never \
        --image=mirror.gcr.io/alpine:latest \
        --overrides='{"spec":{"containers":[{"name":"browse-pvc-{{ claim }}","image":"mirror.gcr.io/alpine:latest","stdin":true,"tty":true,"command":["/bin/sh"],"workingDir":"/mnt","volumeMounts":[{"mountPath":"/mnt","name":"data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"{{ claim }}"}}]}}'

[doc('Debug a node')]
debug-node node:
    #!/usr/bin/env bash
    set -euo pipefail
    trap 'kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug --field-selector spec.nodeName={{ node }} --ignore-not-found --wait=false' EXIT
    kubectl debug node/{{ node }} -n default -it --image=mirror.gcr.io/alpine:latest --profile=sysadmin

[doc('Delete local Flux Kustomization')]
delete-ks ns ks:
    just infra render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f -

[doc('Prune pods in Failed, Pending, or Succeeded state')]
prune-pods:
    for phase in Failed Pending Succeeded; do \
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true; \
    done

[arg('resource', pattern='hr|ks|gitrepo|ocirepo|es')]
[doc('Sync a resource')]
sync resource:
    kubectl get {{ resource }} --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite {{ resource }} "$name" \
            "force-sync=$(date +%s)" \
            "reconcile.fluxcd.io/requestedAt=$(date +%s)" \
            "reconcile.fluxcd.io/forceAt=$(date +%s)"; \
    done

[doc('See logs of pods')]
logs namespace resource:
    kubectl stern -n {{ namespace }} {{ resource }}

[doc('View a secret')]
view-secret namespace secret:
    kubectl view-secret -n {{ namespace }} {{ secret }}

[doc('Check release scores for a series in Sonarr')]
check-score series:
    #!/usr/bin/env bash
    set -euo pipefail
    SONARR_API_KEY=$(kubectl get secret -n media-center recyclarr-secret -o jsonpath='{.data.SONARR_API_KEY}' | base64 -d)
    POD=$(kubectl get pods -n media-center -l app.kubernetes.io/name=sonarr -o jsonpath='{.items[0].metadata.name}')
    kubectl port-forward -n media-center "pod/$POD" 8989:80 &>/dev/null &
    PF_PID=$!
    trap "kill $PF_PID 2>/dev/null" EXIT
    sleep 1
    SERIES_ID=$(curl -sf -H "X-Api-Key: ${SONARR_API_KEY}" \
      "http://localhost:8989/api/v3/series" \
      | jq -r --arg name "{{ series }}" '.[] | select(.title | test($name; "i")) | .id' | head -1)
    EPISODE_ID=$(curl -sf -H "X-Api-Key: ${SONARR_API_KEY}" \
      "http://localhost:8989/api/v3/episode?seriesId=${SERIES_ID}&seasonNumber=1" \
      | jq '.[0].id')
    curl -sf -H "X-Api-Key: ${SONARR_API_KEY}" \
      "http://localhost:8989/api/v3/release?episodeId=${EPISODE_ID}" \
      | jq '.[] | {title, quality: .quality.quality.name, customFormatScore, qualityScore, rejected, rejections}'

[arg('apply', pattern='true|false')]
[doc('Re-import episodes Sonarr lost from the library, from the torrent folder (dry-run unless apply=true)')]
sonarr-relink series apply='false' folder='/data/data/torrent/completed/anime-sonarr':
    #!/usr/bin/env bash
    set -euo pipefail
    SONARR_API_KEY=$(kubectl get secret -n media-center recyclarr-secret -o jsonpath='{.data.SONARR_API_KEY}' | base64 -d)
    POD=$(kubectl get pods -n media-center -l app.kubernetes.io/name=sonarr -o jsonpath='{.items[0].metadata.name}')
    kubectl port-forward -n media-center "pod/$POD" 8989:80 &>/dev/null &
    PF_PID=$!
    trap "kill $PF_PID 2>/dev/null" EXIT
    sleep 1
    api() { curl -sf -H "X-Api-Key: ${SONARR_API_KEY}" "$@"; }
    BASE=http://localhost:8989/api/v3

    # "copy" only hardlinks when this is on; otherwise the data is duplicated on the NAS
    api "$BASE/config/mediamanagement" | jq -e '.copyUsingHardlinks' >/dev/null \
      || { echo "Sonarr 'Use Hardlinks instead of Copy' is off, refusing to import" >&2; exit 1; }

    SERIES=$(api "$BASE/series" | jq -c --arg name "{{ series }}" '[.[] | select(.title | test($name; "i"))] | .[0]')
    [ "$SERIES" != "null" ] || { echo "no series matches '{{ series }}'" >&2; exit 1; }
    SID=$(jq -r '.id' <<<"$SERIES")
    echo "series: $(jq -r '.title' <<<"$SERIES") (id ${SID})"

    # Do NOT use GET /manualimport?folder=: it runs MediaInfo on every file and OOMKills Sonarr on a big folder.
    # /parse only reads the filename, so it is cheap. MediaInfo then runs on just the files we import.
    # A folder parse guesses the source from the name (SubsPlease -> HDTV-1080p), so prefer the quality/language
    # Sonarr recorded when it originally imported this exact file (history droppedPath), and fall back to the parse.
    HISTORY=$(api "$BASE/history/series?seriesId=${SID}")
    FILES=$(while IFS= read -r path; do
        name="${path##*/}"
        api -G --data-urlencode "title=${name}" "$BASE/parse" | jq -c --arg path "$path" --arg name "$name" --argjson sid "$SID" --slurpfile hist <(printf '%s' "$HISTORY") '
          select(.series.id == $sid and (.episodes | length) > 0 and all(.episodes[]; .hasFile | not))
          | ([$hist[0][] | select(.eventType == "downloadFolderImported" and ((.data.droppedPath // "") | split("/") | last) == $name)] | sort_by(.date) | .[0]) as $h
          | {path: $path, seriesId: .series.id, episodeIds: [.episodes[].id],
             quality: ($h.quality // .parsedEpisodeInfo.quality), languages: ($h.languages // .languages),
             releaseGroup: .parsedEpisodeInfo.releaseGroup}'
      done < <(kubectl exec -n media-center "$POD" -- find "{{ folder }}" -maxdepth 1 -type f -name '*.mkv') \
      | jq -sc 'unique_by(.episodeIds)')

    jq -r '.[] | "episode ids \(.episodeIds) <- \(.path | split("/") | last)"' <<<"$FILES"
    [ "$(jq length <<<"$FILES")" -gt 0 ] || { echo "nothing to import"; exit 0; }
    [ "{{ apply }}" = "true" ] || { echo "dry-run: re-run with apply=true to import"; exit 0; }

    CMD=$(api -X POST -H 'Content-Type: application/json' "$BASE/command" \
      -d "$(jq -c '{name: "ManualImport", importMode: "copy", files: .}' <<<"$FILES")" | jq -r '.id')
    until STATUS=$(api "$BASE/command/${CMD}" | jq -r '.status') && [[ "$STATUS" =~ ^(completed|failed)$ ]]; do sleep 2; done
    echo "import ${STATUS}"

[doc('Check port forward for qbittorrent')]
check-qb:
    kubectl exec -it -n media-center -c app $(kubectl get pods -n media-center -l  app.kubernetes.io/name=qbittorrent -o jsonpath='{.items[0].metadata.name}') -- wget -qO- ipaddress.ai
    kubectl exec -it -n media-center -c app $(kubectl get pods -n media-center -l  app.kubernetes.io/name=qbittorrent -o jsonpath='{.items[0].metadata.name}') -- wget -qO- http://localhost:8000/v1/portforward

[private]
render-local-ks ns ks:
    flate build ks --namespace "{{ ns }}" --output yaml "{{ ks }}"
