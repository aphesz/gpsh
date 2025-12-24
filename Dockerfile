# Step 1: Build the frontend (minified JS/CSS)
FROM node:18-alpine AS build-js
WORKDIR /build
COPY package*.json ./
RUN npm install
COPY . .
RUN npx gulp

# Step 2: Build the Golang binary
FROM golang:1.24-bookworm AS build-golang
RUN apt-get update && apt-get install -y git gcc libc6-dev
WORKDIR /go/src/github.com/gophish/gophish
COPY . .
RUN go mod download
RUN go build -v -o gophish

# Step 3: Runtime container
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y jq ca-certificates mailcap bash && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -m -d /opt/gophish -s /bin/bash app

WORKDIR /opt/gophish
COPY --from=build-golang /go/src/github.com/gophish/gophish/gophish ./
COPY --from=build-golang /go/src/github.com/gophish/gophish/config.json ./
COPY --from=build-golang /go/src/github.com/gophish/gophish/VERSION ./
COPY --from=build-golang /go/src/github.com/gophish/gophish/db/ ./db/
COPY --from=build-golang /go/src/github.com/gophish/gophish/static/ ./static/
COPY --from=build-js /build/static/js/dist/ ./static/js/dist/
COPY --from=build-js /build/static/css/dist/ ./static/css/dist/
COPY --from=build-golang /go/src/github.com/gophish/gophish/templates/ ./templates/
COPY --from=build-golang /go/src/github.com/gophish/gophish/docker/ ./docker/

RUN chown -R app:app /opt/gophish && \
    chmod +x /opt/gophish/docker/run.sh
USER app

# Default config points to 127.0.0.1, we need it to listen on all interfaces in Docker
RUN sed -i 's/127.0.0.1/0.0.0.0/g' config.json

EXPOSE 3333 8080 8443 80

ENTRYPOINT ["./docker/run.sh"]
