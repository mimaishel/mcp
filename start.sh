#!/bin/bash
/usr/local/bin/ibmcloud config --check-version=false > /dev/null
/usr/local/bin/ibmcloud login --apikey $IBMCLOUD_API_KEY -r us-south > /dev/null

/usr/local/bin/ibmcloud --mcp-transport stdio --mcp-tools "$IBMCLOUD_MCP_TOOLS"
