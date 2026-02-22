FROM golang:1.26.0-trixie AS builder

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download
COPY . ./
RUN --mount=type=cache,target=/root/.cache/go-build CGO_ENABLED=1 go build -buildmode=pie -tags 'osusergo,netgo,static,' -ldflags '-linkmode=external -extldflags "-static-pie"' -o /bin/promenade

FROM scratch
COPY --from=builder /bin/promenade /bin/promenade
ENTRYPOINT ["/bin/promenade"]
