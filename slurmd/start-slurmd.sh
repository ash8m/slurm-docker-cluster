#!/bin/bash
set -euo pipefail


MUNGE_SOCKET=/var/run/munge/munge.socket.2
SLURMCTLD_HOST=slurmctld   # hostname or service name in your container network
SLURMCTLD_PORT=6817

echo "[slurmd-wrapper] Waiting for MUNGE socket..."
until [ -S "$MUNGE_SOCKET" ]; do
    echo "[slurmd-wrapper] MUNGE not ready yet..."
    sleep 2
done
echo "[slurmd-wrapper] MUNGE is ready."

echo "[slurmd-wrapper] Waiting for slurmctld to become active before starting slurmd..."

while ! timeout 1 bash -c ">/dev/tcp/${SLURMCTLD_HOST}/${SLURMCTLD_PORT}" 2>/dev/null; do
    echo "[slurmd-wrapper] slurmctld is not available. Sleeping ..."
    sleep 2
done

echo "[slurmd-wrapper] slurmctld is now active ..."
echo "[slurmd-wrapper] starting slurmd ..."
exec /usr/sbin/slurmd -Dvvv
