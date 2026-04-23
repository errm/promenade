GO_IMAGE := golang:1.26.2-trixie

# Run the full test suite inside a Linux container.
# This is the canonical way to run tests on non-Linux hosts (e.g. macOS),
# since the tcpconnections tests require Linux kernel interfaces.
# Build and module caches are persisted in named Docker volumes so
# subsequent runs don't re-download dependencies or recompile from scratch.
.PHONY: test
test:
	docker run --rm \
		-v "$(CURDIR):/src" \
		-v "promenade-go-build-cache:/root/.cache/go-build" \
		-v "promenade-go-mod-cache:/go/pkg/mod" \
		-w /src \
		$(GO_IMAGE) \
		go test -v ./...
