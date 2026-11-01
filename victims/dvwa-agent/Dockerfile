FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl procps \
    && curl -fsSL -o /tmp/wazuh-agent.deb \
       https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.14.9-1_amd64.deb \
    && apt-get install -y /tmp/wazuh-agent.deb \
    && rm -f /tmp/wazuh-agent.deb \
    && rm -rf /var/lib/apt/lists/*

COPY ossec.conf /var/ossec/etc/ossec.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
