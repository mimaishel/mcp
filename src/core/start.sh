#!/bin/bash
/app/ibmcloud config --check-version=false > /dev/null
/app/ibmcloud login --apikey $IBMCLOUD_API_KEY -r us-south -g default > /dev/null

case "$IBMCLOUD_MCP_TRANSPORT" in
    sse)
        transport_mode="http://0.0.0.0:4141"
        ;;
    *)
        transport_mode="stdio"
        ;;
esac

args="--mcp-transport $transport_mode"
[ -n "$IBMCLOUD_MCP_TOOLS" ] && args+=" --mcp-tools $IBMCLOUD_MCP_TOOLS"

/app/ibmcloud $args
