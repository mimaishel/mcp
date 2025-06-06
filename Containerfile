FROM registry.access.redhat.com/ubi9-minimal:9.6-1747218906
LABEL maintainer="Ryan Edgell" \
      name="mcp/ibmcloud" \
      description="IBM Cloud MCP Server: Model Context Protocol for IBM Cloud"

ARG IBMCLOUD_VERSION=2.35.0
ARG IBMCLOUD_ARCH=amd64
ARG IBMCLOUD_PLUGINS

# Install required system packages
RUN microdnf update -y && \
    microdnf install -y tar gzip && \
    microdnf clean all

# Download, install, and configure IBM Cloud CLI
RUN curl -L "https://download.clis.test.cloud.ibm.com/ibm-cloud-cli/${IBMCLOUD_VERSION}/IBM_Cloud_CLI_${IBMCLOUD_VERSION}_${IBMCLOUD_ARCH}.tar.gz" -o /tmp/ibmcloud.tar.gz && \
    tar -xf /tmp/ibmcloud.tar.gz -C /tmp && \
    mv /tmp/Bluemix_CLI/bin/ibmcloud /usr/local/bin/ && \
    chmod +x /usr/local/bin/ibmcloud && \
    if [ -n "${IBMCLOUD_PLUGINS}" ]; then \
        ibmcloud plugin install ${IBMCLOUD_PLUGINS//,/ } -f -q || :; \
    else \
        echo "No specific plugins specified, installing all..." && \
        ibmcloud plugin install --all -f -q || :; \
    fi && \
    rm -rf /tmp/ibmcloud.tar.gz /tmp/Bluemix_CLI

EXPOSE 4444

COPY ./start.sh /usr/local/start.sh
RUN chmod +x /usr/local/start.sh

# Start the application
CMD ["/usr/local/start.sh"]
