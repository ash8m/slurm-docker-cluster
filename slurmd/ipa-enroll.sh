#!/bin/bash
set -e
if [ ! -f /etc/ipa/default.conf ]; then
    ipa-client-install \
        --unattended \
        --mkhomedir \
        --server=server.ipa.local \
        --domain=ipa.local \
        --realm=IPA.LOCAL \
        --no-ntp \
        --no-nisdomain \
        --force-join  \
        -p admin -w password

fi
