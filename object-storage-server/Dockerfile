# Official source release; original Docker Hub/Quay image tags did not resolve.
FROM golang:1.24.8-alpine AS build
ENV CGO_ENABLED=0 GOMAXPROCS=2 GOFLAGS=-p=2
RUN go install -ldflags="-s -w" github.com/minio/minio@RELEASE.2025-10-15T17-29-55Z
# Stamp the source-built binary after the cached compilation with the upstream release metadata.
RUN go install -ldflags="-s -w -X github.com/minio/minio/cmd.Version=2025-10-15T17:29:55Z -X github.com/minio/minio/cmd.ReleaseTag=RELEASE.2025-10-15T17-29-55Z -X github.com/minio/minio/cmd.CopyrightYear=2025 -X github.com/minio/minio/cmd.CommitID=9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a -X github.com/minio/minio/cmd.ShortCommitID=9e49d5e7a648" github.com/minio/minio@RELEASE.2025-10-15T17-29-55Z
RUN go version -m /go/bin/minio > /go/bin/minio-build-info.txt

FROM alpine:3.22
RUN apk add --no-cache ca-certificates curl
COPY --from=build /go/bin/minio /usr/local/bin/minio
COPY --from=build /go/bin/minio-build-info.txt /usr/local/share/minio-build-info.txt
LABEL org.opencontainers.image.source="https://github.com/minio/minio" \
      org.opencontainers.image.version="RELEASE.2025-10-15T17-29-55Z" \
      org.opencontainers.image.revision="9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a" \
      org.opencontainers.image.licenses="AGPL-3.0-only"
EXPOSE 9000 9001
ENTRYPOINT ["minio"]
CMD ["server", "/data", "--console-address", ":9001"]
