FROM alpine:latest

RUN apk add --no-cache nftables catatonit
COPY ./entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
