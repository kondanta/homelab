set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

TALOS_DIR := source_directory()
NODES_DIR := TALOS_DIR / "nodes"

[private]
default:
    just --list --justfile {{ justfile() }}

# Render the machineconfig for a node (dry-run, prints to stdout)
[doc("Usage: just talos render-config k8s-0")]
render-config NODE:
    #!/usr/bin/env bash
    set -euo pipefail
    type=$(yq --exit-status 'select(documentIndex == 0) | .machine.type' "{{ NODES_DIR }}/{{ NODE }}.yaml.j2")
    base=$(minijinja-cli --env --define "machinetype=${type}" "{{ TALOS_DIR }}/machineconfig.yaml.j2")
    patch=$(minijinja-cli --env --define "machinetype=${type}" "{{ NODES_DIR }}/{{ NODE }}.yaml.j2")
    talosctl machineconfig patch <(echo "${base}") --patch "@"<(echo "${patch}")

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
