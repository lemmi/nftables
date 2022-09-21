# nftables

This is a container image to setup firewall rules with `nftables`. By default
the standard stateful firewall rules shipped with alpine are loaded. Custom
rules can be added by bind mounting files into `/etc/nftables.d/*.nft`, or by
running extra commands.

## Intended use-case

With `ipvlan`/`macvlan`, containers can be exposed directly to the internet
with their own address. This allows to make full use of available IPv6
addresses (on servers you are often provided with a full `/64`) without NAT,
proxy ndp or complicated firewall rules on the container host.

It also leaves the container fully open to the internet and depending on your
image of choice, the container might unintentionally expose ports.

By setting up the network with the `nftables` container and reusing its network
namespace in other containers, containers can still be directly reachable, but
only on allowed ports.

- `podman run --network container:nftables...`
- docker-compose: `network_mode: service:nftables`

### Example: firewalled service with caddy reverse-proxy

Web services can easily have their own address without complicated reverse proxy
setups needed to route to the traffic to containers and manage TLS certificates. 

1. service `nftables` will setup the network namespace and firewall
2. service `caddy` will run as reverse-proxy and manage certificates
3. service `service` is a webapplication that listens on port `:3000`
    - `service` might be bound to a wildcard address and can't be configured to
      only listen on localhost
    - it might listen on other ports as well

This setup mimics the usual container behaviour. Containers will have outgoing
access to the internet, while only selected ports are exposed. 

```yaml
---
services:
  nftables:
    image: ghcr.io/lemmi/nftables
    command:
      - nft add rule inet filter input meta nfproto ipv6 tcp dport {80, 443} counter accept;
      - nft add rule inet filter input meta nfproto ipv6 udp dport 443 counter accept;
    networks:
      ipvlan:
        ipv6_address: 2001:db8::
    cap_add:
      - CAP_NET_ADMIN

  caddy:
    image: caddy:alpine
    command: caddy reverse-proxy --from example.com --to 'http://localhost:3000'
    restart: always
    network_mode: service:nftables
    volumes:
      - caddy:/data

  service:
    image: ...
    network_mode: service:nftables

volumes:
  caddy:

networks:
  ipvlan:
    enable_ipv6: true
    external: true
```

## Adding rules with volumes or bind mounts

In case more complicated rules are necessary, it's possible to provide them as
a file to be included after the main rules:

`allow-web.nft`:
```nftables
add rule inet filter input tcp dport {80, 443} counter accept;
```

```shell
podman run \
    -v /path/to/allow-web.nft:/etc/nftables.d/allow-web.nft \
    --cap-add CAP_NET_ADMIN \
    ghcr.io/lemmi/nftables
```

## Adding rules with args

For very few rules, it's possible to provide them as command to the image.
Arguments are passed to `sh -c`.

```shell
podman run \
    --cap-add CAP_NET_ADMIN \
    ghcr.io/lemmi/nftables \
    nft add rule inet filter input tcp dport "{80, 443}" counter accept
```

## docker-compose

### single rule

```yaml
services:
  nftables:
    image: ghcr.io/lemmi/nftables
    command: nft add rule inet filter input tcp dport {80, 443} counter accept
```

### multiple rules
```yaml
services:
  nftables:
    image: ghcr.io/lemmi/nftables
    command: 
      - nft add rule inet filter input tcp dport {80, 443} counter accept; # the ; is important
      - nft list ruleset
```

This can also be used to discard the default rules by running `nft flush ruleset`
before the custom rules:

```yaml
services:
  nftables:
    image: ghcr.io/lemmi/nftables
    command:
      - nft flush ruleset;
      - nft add table inet filter;
      - nft add chain inet filter input "{ type filter hook input priority filter; policy accept;}";
      - nft add rule inet filter input counter;
      - nft list ruleset;
    cap_add:
      - CAP_NET_ADMIN
```
