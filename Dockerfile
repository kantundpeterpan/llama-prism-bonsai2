FROM ubuntu:24.04

ARG PRISM_TAG=prism-b10743-adfffbe
ARG PRISM_RELEASE_BASE=https://github.com/PrismML-Eng/llama.cpp/releases/download/${PRISM_TAG}

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libssl3t64 libgomp1 \
    && rm -rf /var/lib/apt/lists/*

ADD ${PRISM_RELEASE_BASE}/llama-${PRISM_TAG}-bin-ubuntu-x64.tar.gz /tmp/llama.tar.gz

RUN mkdir -p /opt/llama \
    && tar -xzf /tmp/llama.tar.gz -C /opt/llama --strip-components=1 \
    && rm -f /tmp/llama.tar.gz \
    && if ldd /opt/llama/llama-server | grep -q 'not found'; then \
         echo 'ERROR: unresolved shared libraries:'; ldd /opt/llama/llama-server | grep 'not found'; exit 1; \
       fi \
    && /opt/llama/llama-server --version

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV LD_LIBRARY_PATH=/opt/llama

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
