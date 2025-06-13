#!/bin/bash
/usr/local/bin/ibmcloud config --check-version=false > /dev/null
/usr/local/bin/ibmcloud login --apikey $IBMCLOUD_API_KEY -r us-south > /dev/null

case "$IBMCLOUD_MCP_TRANSPORT" in
    sse)
        transport_mode="http://0.0.0.0:4141"
        ;;
    *)
        transport_mode="stdio"
        ;;
esac

/usr/local/bin/ibmcloud --mcp-transport $transport_mode --mcp-tools $IBMCLOUD_MCP_TOOLS
