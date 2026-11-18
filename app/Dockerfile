# Build stage
FROM golang:1.23-alpine AS build

ARG VERSION=dev
ARG TARGETARCH
WORKDIR /src

COPY go.mod ./
COPY main.go ./

RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} go build \
    -trimpath \
    -ldflags="-s -w -X main.version=${VERSION}" \
    -o /out/platform-api .

# Runtime stage — no shell, no package manager, non-root
FROM scratch

COPY --from=build /out/platform-api /platform-api

USER 65532:65532
EXPOSE 8080

ENTRYPOINT ["/platform-api"]
