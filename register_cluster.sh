#!/bin/bash
set -e

podman exec slurmctld bash -c "/usr/bin/sacctmgr --immediate add cluster name=linux" && \
podman-compose restart slurmdbd slurmctld
