# Go — experiments 1-3 (multi-stage builds)

Starter project: <https://github.com/comsys-kpi-ua/deploy.lab-containers-starter-project-golang>

Clone it locally. The `go build ./...` line in our Dockerfiles assumes
the `main` package is somewhere under the project root; tweak the path if
the starter project uses a `./cmd/<name>` layout.

## Experiment 1 — naive single-stage build

```bash
docker pull golang:1.22

cp exp1-naive/Dockerfile ./Dockerfile
time docker build --no-cache --pull=false -t goexp:1 .
docker images goexp:1 --format '{{.Size}}'
```

Now look inside the image to see what's actually in there:

```bash
# quick summary of layers and sizes
docker history goexp:1

# (optional) interactive inspection with dive — install: https://github.com/wagoodman/dive
dive goexp:1
```

You will see the entire Go toolchain, /usr/local/go, the build cache,
the .git directory if it was copied — none of that is needed at runtime.

## Experiment 2 — multi-stage, FROM scratch

```bash
cp exp2-scratch/Dockerfile ./Dockerfile
time docker build --no-cache --pull=false -t goexp:2 .
docker images goexp:2 --format '{{.Size}}'
docker history goexp:2
```

Try to "get into" the running container:

```bash
docker run -d --name goexp2 goexp:2
docker exec -it goexp2 sh           # will fail — no /bin/sh in scratch
docker logs goexp2                   # this is your only way to see output
docker rm -f goexp2
```

If the binary fails with "no such file or directory" — that usually means
it was dynamically linked and missing libc. Re-check `CGO_ENABLED=0` in
the Dockerfile.

## Experiment 3 — multi-stage, distroless

```bash
cp exp3-distroless/Dockerfile ./Dockerfile
time docker build --no-cache --pull=false -t goexp:3 .
docker images goexp:3 --format '{{.Size}}'
docker history goexp:3
```

For the report — compare the three sizes (typically ~800 MB → ~12 MB →
~15 MB) and discuss the trade-offs:

| Aspect | naive | scratch | distroless |
|---|---|---|---|
| Image size | huge | tiny | tiny |
| HTTPS works out of box | yes | no (need ca-certs) | yes |
| Has non-root user | no | no | yes (uid 65532) |
| Can `docker exec sh`? | yes | no | no |
| Attack surface | large | minimal | minimal |
