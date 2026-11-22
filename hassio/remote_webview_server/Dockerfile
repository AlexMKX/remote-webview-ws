# Upstream's published image lacks the fork's auto-login feature; the fork
# builds its own from the root dockerfile (.github/workflows/fork-image.yml).
ARG SERVER_IMAGE=ghcr.io/alexmkx/remote-webview-ws:latest
FROM ${SERVER_IMAGE}

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends jq socat ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 8081 18080 9221

CMD ["/run.sh"]
