FROM registry.access.redhat.com/ubi9-minimal:9.6-1747218906
LABEL maintainer="Chris Mitchell" \
      name="mcp/ibmcloud" \
      description="IBM Cloud MCP Server: Model Context Protocol for IBM Cloud"

RUN mkdir -p /home/ibmcloud
ENV IBMCLOUD_HOME=/home/ibmcloud
WORKDIR /home/ibmcloud

ADD ./ibmcloud /usr/local/bin/ibmcloud
RUN chmod +x /usr/local/bin/ibmcloud
RUN /usr/local/bin/ibmcloud config --check-version=false
#RUN /usr/local/bin/ibmcloud login --apikey $IBMCLOUD_API_KEY
# Start the application using run-gunicorn.sh
CMD ["/usr/local/bin/ibmcloud", "--mcp-transport", "stdio"]
