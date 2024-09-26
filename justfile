#!/usr/bin/env -S just --justfile

log := "warn"
export JUST_LOG := log

set shell := ["bash", "-uc"]

[group: 'provision']
controlplane:
    infrastructure/metal/tasks/provision/provision

[group: 'provision']
worker $IS_WORKER="True":
    infrastructure/metal/tasks/provision/provision
