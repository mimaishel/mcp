# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#   🐍 IBMCloud MCP Server - Makefile
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# Author: Chris Mitchell
# Description: Build and serves locally hosted website for IBMCloud MCP Server project.
# Usage: run `make docs` or `make help` to view available targets
#
# help: 🛠️ IBMCloud MCP Server
#
# ──────────────────────────────────────────────────────────────────────────
# Project variables
PROJECT_NAME      = ibmcloud-mcpserver
# =============================================================================
# 📖 DYNAMIC HELP
# =============================================================================
.PHONY: help
help:
	@grep "^# help\:" Makefile | grep -v grep | sed 's/\# help\: //' | sed 's/\# help\://'

.PHONY: docs
docs:
	bash local-init.sh
