

FROM golang:1.22

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -o /out/server ./...

EXPOSE 8080
CMD ["/out/server"]
