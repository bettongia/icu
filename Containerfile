# Stage 1: build addlicense (Go tool used by the license_check target)
FROM golang:latest AS addlicense-builder
RUN CGO_ENABLED=0 go install github.com/google/addlicense@latest

# Stage 2: Dart runtime with ICU and tooling
FROM dart:stable

COPY --from=addlicense-builder /go/bin/addlicense /usr/local/bin/addlicense

RUN apt-get update && apt-get install -y --no-install-recommends \
    make \
    lcov \
    libicu-dev \
    && rm -rf /var/lib/apt/lists/*

# dart pub global activate installs binaries here (e.g. coverage's format_coverage)
ENV PATH="/root/.pub-cache/bin:${PATH}"

WORKDIR /app

COPY . .

CMD ["make", "cicd"]
