set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just -l talos
