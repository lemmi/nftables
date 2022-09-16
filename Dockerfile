FROM alpine:latest

RUN apk add --no-cache nftables catatonit

ENTRYPOINT nft -f /etc/nftables.nft && exec catatonit -P
