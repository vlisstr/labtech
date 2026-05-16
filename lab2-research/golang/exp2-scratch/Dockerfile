FROM golang:1.22 AS builder

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux \
    go build -ldflags='-s -w' -o /out/server ./...


FROM scratch

# Uncomment if the app makes outbound HTTPS calls:
# COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=builder /out/server /server

EXPOSE 8080
ENTRYPOINT ["/server"]
