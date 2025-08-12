#!/bin/bash
set -euo pipefail

MUNGE_SOCKET=/var/run/munge/munge.socket.2
SLURMDBD_HOST=slurmdbd   # hostname or service name in your container network
SLURMDBD_PORT=6819

echo "[slurmctld-wrapper] Waiting for MUNGE socket..."
until [ -S "$MUNGE_SOCKET" ]; do
    echo "[slurmctld-wrapper] MUNGE not ready yet..."
    sleep 2
done
echo "[slurmctld-wrapper] MUNGE is ready."

echo "[slurmctld-wrapper] Waiting for slurmdbd at ${SLURMDBD_HOST}:${SLURMDBD_PORT}..."
until (echo > /dev/tcp/${SLURMDBD_HOST}/${SLURMDBD_PORT}) >/dev/null 2>&1; do
    echo "[slurmctld-wrapper] slurmdbd is not available yet..."
    sleep 2
done
echo "[slurmctld-wrapper] slurmdbd is ready."

echo "[slurmctld-wrapper] Starting slurmctld..."
if /usr/sbin/slurmctld -V | grep -q '17.02'; then
    exec /usr/sbin/slurmctld -Dvvv
else
    exec /usr/sbin/slurmctld -i -Dvvv
fi
