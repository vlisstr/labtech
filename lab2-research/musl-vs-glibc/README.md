# musl vs glibc — DNS resolution

The point of this experiment is that two C standard libraries — glibc on
Ubuntu/Debian, musl on Alpine — implement DNS lookups differently. The
same setup produces different results.

## Setup

Create a dedicated Docker network for the test (so DNS queries don't
escape into the host's resolver):

```bash
docker network create dns-lab
```

## Step 1 — start a tiny DNS server

In **terminal A**, run a dnsmasq container that knows one record:

```bash
docker run --rm -it --name dns-server --network dns-lab \
  alpine sh -c "apk add dnsmasq && \
    echo 'address=/myservice.internal.corp/10.0.0.50' > /etc/dnsmasq.conf && \
    dnsmasq -k --log-queries --log-facility=-"
```

Leave this running — it will print every DNS query it receives.

## Step 2 — query from Ubuntu (glibc)

In **terminal B**:

```bash
DNS_IP=$(docker inspect -f \
  '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server)

docker run --rm --network dns-lab \
  --dns="$DNS_IP" --dns-search="corp" \
  ubuntu:latest getent hosts myservice.internal
```

Record what `getent` outputs **and** what queries appear in terminal A's
dnsmasq log.

## Step 3 — query from Alpine (musl)

```bash
docker run --rm --network dns-lab \
  --dns="$DNS_IP" --dns-search="corp" \
  alpine:latest getent hosts myservice.internal
```

Same thing: record both the `getent` output and the dnsmasq log lines.

## What to look for in the report

Compare:
1. **getent output** — did each variant return `10.0.0.50`? Did one return
   nothing while the other succeeded?
2. **dnsmasq log** — for each container, which queries did the resolver
   send? Did it append the search suffix (`.corp`)? In which order?

Possible findings (verify on your own setup):
- glibc applies the search suffix and queries `myservice.internal.corp`.
- musl historically had a simpler resolver that handles search domains
  more conservatively, sometimes leading to different lookup patterns or
  to no resolution at all in this exact scenario.

## Why it matters (for the conclusions section)

This is the kind of bug that bites you in production: same code, same
config, but the result depends on whether your runtime image is built on
Alpine or Debian. If your service relies on short hostnames + a search
domain (very common in Kubernetes — `myservice.mynamespace`), switching
the base image from `python:3.13-slim` to `python:3.13-alpine` can break
service discovery in subtle ways. Pin your base image and **test name
resolution in your CI**.
