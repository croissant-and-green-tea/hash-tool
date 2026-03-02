FROM alpine:3.19

LABEL maintainer="hash_tool" \
      description="Vérification d'intégrité BLAKE3 - integrity.sh + runner.sh"

RUN apk add --no-cache \
      bash \
      jq \
      b3sum \
      coreutils \
      findutils \
      grep \
    && rm -rf /var/cache/apk/*

WORKDIR /app

COPY src/ ./src/
COPY runner.sh ./runner.sh

# On rend tout le dossier /app exécutable et on crée les points de montage
RUN chmod -R +x /app && \
    mkdir -p /data /bases /pipelines /resultats && \
    chmod 777 /resultats

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/data", "/bases", "/pipelines", "/resultats"]
ENV RESULTATS_DIR=/resultats

ENTRYPOINT ["/entrypoint.sh"]
CMD ["help"]