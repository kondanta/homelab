set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

TALOS_DIR := source_directory()
NODES_DIR := TALOS_DIR / "nodes"

[private]
default:
    just --list --justfile {{ justfile() }}

# Render the legacy (pre-1.14) machineconfig for a node — use for the
# node-rename playbook, which must run before the 1.14 multi-doc migration.
# Requires secrets in environment — call via render-config-legacy-sops in normal use.
[doc("Usage: just talos render-config-legacy k8s-0")]
render-config-legacy NODE:
    #!/usr/bin/env bash
    set -euo pipefail
    type=$(yq --exit-status 'select(documentIndex == 0) | .machine.type' "{{ NODES_DIR }}/{{ NODE }}.yaml.j2")
    base=$(minijinja-cli --env --define "machinetype=${type}" "{{ TALOS_DIR }}/machineconfig.yaml.j2")
    patch=$(minijinja-cli --env --define "machinetype=${type}" "{{ NODES_DIR }}/{{ NODE }}.yaml.j2")
    talosctl machineconfig patch <(echo "${base}") --patch "@"<(echo "${patch}")

# Render the legacy machineconfig for a node, loading secrets from sops
[doc("Usage: just talos render-config-legacy-sops k8s-0")]
render-config-legacy-sops NODE:
    sops exec-env {{ TALOS_DIR }}/secrets.sops.yaml 'just talos render-config-legacy {{ NODE }}'

# Verify every key/cert in secrets.sops.yaml is structurally valid and each
# cert/key pair actually matches. Catches corruption (e.g. a bad RSA key)
# before it reaches a live node, instead of during a control-plane apply.
# Requires secrets in environment — call via verify-secrets-sops in normal use.
[doc("Usage: just talos verify-secrets")]
verify-secrets:
    #!/usr/bin/env bash
    set -uo pipefail
    fail=0

    # Talos emits Ed25519 keys as "-----BEGIN ED25519 PRIVATE KEY-----", which
    # isn't a real OpenSSL PEM type (the standard PKCS8 label is just
    # "PRIVATE KEY") — normalize it so openssl can actually parse the key.
    normalize_pem() {
        sed 's/BEGIN ED25519 PRIVATE KEY/BEGIN PRIVATE KEY/;s/END ED25519 PRIVATE KEY/END PRIVATE KEY/'
    }

    check_key() {
        local name="$1" value="$2"
        [[ -z "$value" ]] && { gum log -t rfc3339 -s -l warn "empty, skipping" field "$name"; return 0; }
        if echo "$value" | base64 -d 2>/dev/null | normalize_pem | openssl pkey -check -noout >/dev/null 2>&1; then
            gum log -t rfc3339 -s -l info "key OK" field "$name"
        else
            gum log -t rfc3339 -s -l error "key INVALID" field "$name"
            fail=1
        fi
    }

    check_cert() {
        local name="$1" value="$2"
        [[ -z "$value" ]] && { gum log -t rfc3339 -s -l warn "empty, skipping" field "$name"; return 0; }
        if echo "$value" | base64 -d 2>/dev/null | openssl x509 -noout -checkend 0 >/dev/null 2>&1; then
            gum log -t rfc3339 -s -l info "cert OK (valid, not expired)" field "$name"
        else
            gum log -t rfc3339 -s -l error "cert INVALID or expired" field "$name"
            fail=1
        fi
    }

    check_pair() {
        local name="$1" crt="$2" key="$3"
        [[ -z "$crt" || -z "$key" ]] && return 0
        local crt_pub key_pub
        crt_pub=$(echo "$crt" | base64 -d 2>/dev/null | openssl x509 -noout -pubkey 2>/dev/null | openssl md5)
        key_pub=$(echo "$key" | base64 -d 2>/dev/null | normalize_pem | openssl pkey -pubout 2>/dev/null | openssl md5)
        if [[ -n "$crt_pub" && "$crt_pub" == "$key_pub" ]]; then
            gum log -t rfc3339 -s -l info "cert/key pair matches" field "$name"
        else
            gum log -t rfc3339 -s -l error "cert/key pair MISMATCH" field "$name"
            fail=1
        fi
    }

    check_key "MACHINE_CA_KEY" "${MACHINE_CA_KEY:-}"
    check_cert "MACHINE_CA_CRT" "${MACHINE_CA_CRT:-}"
    check_pair "MACHINE_CA" "${MACHINE_CA_CRT:-}" "${MACHINE_CA_KEY:-}"

    check_key "CLUSTER_CA_KEY" "${CLUSTER_CA_KEY:-}"
    check_cert "CLUSTER_CA_CRT" "${CLUSTER_CA_CRT:-}"
    check_pair "CLUSTER_CA" "${CLUSTER_CA_CRT:-}" "${CLUSTER_CA_KEY:-}"

    check_key "CLUSTER_AGGREGATOR_CA_KEY" "${CLUSTER_AGGREGATOR_CA_KEY:-}"
    check_cert "CLUSTER_AGGREGATOR_CA_CRT" "${CLUSTER_AGGREGATOR_CA_CRT:-}"
    check_pair "CLUSTER_AGGREGATOR_CA" "${CLUSTER_AGGREGATOR_CA_CRT:-}" "${CLUSTER_AGGREGATOR_CA_KEY:-}"

    check_key "CLUSTER_ETCD_CA_KEY" "${CLUSTER_ETCD_CA_KEY:-}"
    check_cert "CLUSTER_ETCD_CA_CRT" "${CLUSTER_ETCD_CA_CRT:-}"
    check_pair "CLUSTER_ETCD_CA" "${CLUSTER_ETCD_CA_CRT:-}" "${CLUSTER_ETCD_CA_KEY:-}"

    check_key "CLUSTER_SA_KEY" "${CLUSTER_SA_KEY:-}"

    if [[ "$fail" -eq 1 ]]; then
        gum log -t rfc3339 -s -l error "one or more secrets failed validation"
        exit 1
    fi
    gum log -t rfc3339 -s -l info "all secrets valid"

# Verify every key/cert in secrets.sops.yaml, loading secrets from sops
[doc("Usage: just talos verify-secrets-sops")]
verify-secrets-sops:
    sops exec-env {{ TALOS_DIR }}/secrets.sops.yaml 'just talos verify-secrets'

# Render the machineconfig for a node (dry-run, prints to stdout)
# Requires secrets in environment — call via render-config-sops in normal use.
[doc("Usage: just talos render-config k8s-0")]
render-config NODE:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -f "{{ NODES_DIR }}/controlplane/{{ NODE }}.yaml.j2" ]]; then
        role="controlplane"
    elif [[ -f "{{ NODES_DIR }}/workers/{{ NODE }}.yaml.j2" ]]; then
        role="workers"
    else
        echo "error: no config found for '{{ NODE }}' in nodes/controlplane/ or nodes/workers/" >&2
        exit 1
    fi
    node_file="{{ NODES_DIR }}/${role}/{{ NODE }}.yaml.j2"

    cluster=$(minijinja-cli \
        -D MACHINE_CA_CRT="${MACHINE_CA_CRT}" \
        -D MACHINE_TOKEN="${MACHINE_TOKEN}" \
        -D CLUSTER_CA_CRT="${CLUSTER_CA_CRT}" \
        -D CLUSTER_ID="${CLUSTER_ID}" \
        -D CLUSTER_SECRET="${CLUSTER_SECRET}" \
        -D CLUSTER_TOKEN="${CLUSTER_TOKEN}" \
        "{{ TALOS_DIR }}/cluster.yaml.j2")

    role_config=$(minijinja-cli \
        -D MACHINE_CA_CRT="${MACHINE_CA_CRT}" \
        -D MACHINE_CA_KEY="${MACHINE_CA_KEY}" \
        -D CLUSTER_CA_CRT="${CLUSTER_CA_CRT}" \
        -D CLUSTER_CA_KEY="${CLUSTER_CA_KEY}" \
        -D CLUSTER_AGGREGATOR_CA_CRT="${CLUSTER_AGGREGATOR_CA_CRT}" \
        -D CLUSTER_AGGREGATOR_CA_KEY="${CLUSTER_AGGREGATOR_CA_KEY}" \
        -D CLUSTER_SA_KEY="${CLUSTER_SA_KEY}" \
        -D CLUSTER_ETCD_CA_CRT="${CLUSTER_ETCD_CA_CRT}" \
        -D CLUSTER_ETCD_CA_KEY="${CLUSTER_ETCD_CA_KEY}" \
        -D CLUSTER_SECRETBOX_ENCRYPTION_SECRET="${CLUSTER_SECRETBOX_ENCRYPTION_SECRET}" \
        "{{ TALOS_DIR }}/${role}.yaml.j2")

    node_config=$(minijinja-cli "${node_file}")

    talosctl machineconfig patch <(echo "${cluster}") \
        --patch "@"<(echo "${role_config}") \
        --patch "@"<(echo "${node_config}")

# Render the machineconfig for a node, loading secrets from sops
[doc("Usage: just talos render-config-sops k8s-0")]
render-config-sops NODE:
    sops exec-env {{ TALOS_DIR }}/secrets.sops.yaml 'just talos render-config {{ NODE }}'

# Apply the rendered machineconfig to a node, loading secrets from sops
[doc("Usage: just talos apply-node-sops k8s-0")]
apply-node-sops NODE:
    sops exec-env {{ TALOS_DIR }}/secrets.sops.yaml 'just talos apply-node {{ NODE }}'

# Apply config to all nodes, loading secrets from sops
[doc("Applies machineconfig to all nodes defined in talosconfig")]
apply-all-sops:
    sops exec-env {{ TALOS_DIR }}/secrets.sops.yaml 'just talos apply-all'

# Apply the rendered machineconfig to a node
[doc("Usage: just talos apply-node k8s-0")]
apply-node NODE:
    #!/usr/bin/env bash
    set -euo pipefail
    config=$(just talos render-config {{ NODE }})
    if [[ -z "${config}" ]]; then
        gum log -t rfc3339 -s -l error "Failed to render config for node" node="{{ NODE }}"
        exit 1
    fi
    echo "${config}" | talosctl --nodes {{ NODE }} apply-config --file /dev/stdin
    gum log -t rfc3339 -s -l info "Config applied" node="{{ NODE }}"

# Apply config to all nodes
[doc("Applies machineconfig to all nodes defined in talosconfig")]
apply-all:
    #!/usr/bin/env bash
    set -euo pipefail
    nodes=$(talosctl config info --output yaml | yq --exit-status '.nodes | join(" ")')
    for node in ${nodes}; do
        just talos apply-node "${node}"
    done

# Bootstrap Kubernetes on the first control plane
bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail
    controller=$(talosctl config info --output yaml | yq --exit-status '.endpoints[0]')
    until output=$(talosctl --nodes "${controller}" bootstrap 2>&1 || true) && [[ "${output}" == *"AlreadyExists"* ]]; do
        gum log -t rfc3339 -s -l info "Bootstrap in progress, retrying in 5s..." controller="${controller}"
        sleep 5
    done
    gum log -t rfc3339 -s -l info "Kubernetes bootstrapped" controller="${controller}"

# Fetch kubeconfig from the cluster
kubeconfig:
    #!/usr/bin/env bash
    set -euo pipefail
    controller=$(talosctl config info --output yaml | yq --exit-status '.endpoints[0]')
    talosctl kubeconfig --nodes "${controller}" --force --force-context-name main "${KUBECONFIG}"
    gum log -t rfc3339 -s -l info "kubeconfig written" path="${KUBECONFIG}"

# Upgrade Talos on a node
[doc("Usage: just talos upgrade-node k8s-0 <schematic-id> <talos-version>")]
upgrade-node NODE SCHEMATIC VERSION:
    talosctl --nodes {{ NODE }} upgrade \
        --image="factory.talos.dev/installer/{{ SCHEMATIC }}:{{ VERSION }}" \
        --wait=true --timeout=10m
    gum log -t rfc3339 -s -l info "Upgrade complete" node="{{ NODE }}" version="{{ VERSION }}"

# Upgrade Kubernetes on a node
[doc("Usage: just talos upgrade-k8s k8s-0 v1.35.2")]
upgrade-k8s NODE VERSION:
    talosctl --nodes {{ NODE }} upgrade-k8s --to {{ VERSION }}
    gum log -t rfc3339 -s -l info "Kubernetes upgraded" node="{{ NODE }}" version="{{ VERSION }}"

# Reboot a node
[doc("Usage: just talos reboot-node k8s-0")]
reboot-node NODE:
    talosctl --nodes {{ NODE }} reboot
    gum log -t rfc3339 -s -l info "Reboot triggered" node="{{ NODE }}"

# Shutdown a node
[doc("Usage: just talos shutdown-node k8s-0")]
shutdown-node NODE:
    talosctl --nodes {{ NODE }} shutdown
    gum log -t rfc3339 -s -l info "Shutdown triggered" node="{{ NODE }}"

# Reset a node (wipes state — use with caution)
[doc("Usage: just talos reset-node k8s-0")]
[confirm("This will wipe all state on {{ NODE }}. Are you sure?")]
reset-node NODE:
    talosctl --nodes {{ NODE }} reset --graceful=false --reboot
    gum log -t rfc3339 -s -l warn "Node reset triggered" node="{{ NODE }}"

# Print talosctl dashboard for a node
[doc("Usage: just talos dashboard k8s-0")]
dashboard NODE:
    talosctl --nodes {{ NODE }} dashboard

# Generate a schematic ID from schematic.yaml
gen-schematic-id:
    curl -s -X POST --data-binary @{{ TALOS_DIR }}/schematic.yaml \
        https://factory.talos.dev/schematics \
        | jq -r '.id'
