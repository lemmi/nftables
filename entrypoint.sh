#!/bin/sh

set -e

nft -f /etc/nftables.nft
sh -c "$*"

exec catatonit -P
