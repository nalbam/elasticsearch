FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY . .
RUN ./gradlew --no-daemon --max-workers=4 -Dorg.gradle.jvmargs="-Xmx3g -XX:MaxMetaspaceSize=1g" :distribution:archives:linux-aarch64-tar:assemble

FROM eclipse-temurin:21-jre
RUN set -eux; \
    if ! getent group 1000 >/dev/null; then groupadd --gid 1000 elasticsearch; fi; \
    if ! getent passwd 1000 >/dev/null; then useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash elasticsearch; fi
COPY --from=build /src/distribution/archives/linux-aarch64-tar/build/distributions/ /tmp/dist/
RUN set -eux; \
    tarball="$(ls /tmp/dist/elasticsearch-*-linux-*.tar.gz | head -n 1)"; \
    tar -xzf "$tarball" -C /opt; \
    dir="$(ls -d /opt/elasticsearch-* | head -n 1)"; \
    mv "$dir" /opt/elasticsearch; \
    rm -rf /tmp/dist; \
    printf '%s\n' \
      'network.host: 0.0.0.0' \
      'http.port: 9200' \
      'discovery.type: single-node' \
      'xpack.security.enabled: false' \
      'xpack.security.http.ssl.enabled: false' \
      'node.store.allow_mmap: false' \
      >> /opt/elasticsearch/config/elasticsearch.yml; \
    grep -q '^network.host: 0.0.0.0$' /opt/elasticsearch/config/elasticsearch.yml; \
    mkdir -p /opt/elasticsearch/data /opt/elasticsearch/logs; \
    chown -R 1000:1000 /opt/elasticsearch
USER 1000
WORKDIR /opt/elasticsearch
ENV ES_PATH_CONF=/opt/elasticsearch/config
ENV ES_JAVA_OPTS="-Xms1g -Xmx1g"
EXPOSE 9200
ENTRYPOINT ["/opt/elasticsearch/bin/elasticsearch"]
