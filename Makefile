# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#   🐍 IBMCloud MCP Server - Makefile
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# Author: Chris Mitchell
# Description: Build & automation helpers for the IBMCloud MCP Server project.
# Usage: run `make` or `make help` to view available targets
#
# help: 🛠️ IBMCloud MCP Server (Model Context Protocol Gateway for IBM Cloud)
#
# ──────────────────────────────────────────────────────────────────────────
# Project variables
PROJECT_NAME      = ibmcloud-mcpserver

# -----------------------------------------------------------------------------
# Container resource configuration
CONTAINER_MEMORY = 2048m
CONTAINER_CPUS   = 1

# =============================================================================
# 📖 DYNAMIC HELP
# =============================================================================
.PHONY: help
help:
	@grep "^# help\:" Makefile | grep -v grep | sed 's/\# help\: //' | sed 's/\# help\://'

# =============================================================================
# 🛡️  SECURITY & PACKAGE SCANNING
# =============================================================================
# help: 🛡️ SECURITY & PACKAGE SCANNING
# help: trivy                - Scan container image for CVEs (HIGH/CRIT). Needs podman socket enabled
.PHONY: trivy
trivy:
	@systemctl --user enable --now podman.socket
	@echo "🔎  trivy vulnerability scan…"
	@trivy --format table --severity HIGH,CRITICAL image localhost/$(PROJECT_NAME)/$(PROJECT_NAME)

# help: dockle               - Lint the built container image via tarball (no daemon/socket needed)
.PHONY: dockle
DOCKLE_IMAGE ?= $(IMG):latest         # mcpgateway/mcpgateway:latest from your build
dockle:
	@echo "🔎  dockle scan (tar mode) on $(DOCKLE_IMAGE)…"
	@command -v dockle >/dev/null || { \
		echo '❌  Dockle not installed. See https://github.com/goodwithtech/dockle'; exit 1; }

	# Pick docker or podman—whichever is on PATH
	@CONTAINER_CLI=$$(command -v docker || command -v podman) ; \
	[ -n "$$CONTAINER_CLI" ] || { echo '❌  docker/podman not found.'; exit 1; }; \
	TARBALL=$$(mktemp /tmp/$(PROJECT_NAME)-dockle-XXXXXX.tar) ; \
	echo "📦  Saving image to $$TARBALL…" ; \
	"$$CONTAINER_CLI" save $(DOCKLE_IMAGE) -o "$$TARBALL" || { rm -f "$$TARBALL"; exit 1; }; \
	echo "🧪  Running Dockle…" ; \
	dockle --no-color --exit-code 1 --exit-level warn --input "$$TARBALL" ; \
	rm -f "$$TARBALL"

# help: hadolint             - Lint Containerfile/Dockerfile(s) with hadolint
.PHONY: hadolint
HADOFILES := Containerfile Dockerfile Dockerfile.*

# Which files to check (edit as you like)
HADOFILES := Containerfile Containerfile.* Dockerfile Dockerfile.*

hadolint:
	@echo "🔎  hadolint scan…"

	# ─── Ensure hadolint is installed ──────────────────────────────────────
	@if ! command -v hadolint >/dev/null 2>&1; then \
		echo "❌  hadolint not found."; \
		case "$$(uname -s)" in \
			Linux*)  echo "💡  Install with:"; \
			         echo "    sudo wget -O /usr/local/bin/hadolint \\"; \
			         echo "      https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64"; \
			         echo "    sudo chmod +x /usr/local/bin/hadolint";; \
			Darwin*) echo "💡  Install with Homebrew: brew install hadolint";; \
			*)       echo "💡  See other binaries: https://github.com/hadolint/hadolint/releases";; \
		esac; \
		exit 1; \
	fi

	# ─── Run hadolint on each existing file ───────────────────────────────
	@found=0; \
	for f in $(HADOFILES); do \
		if [ -f "$$f" ]; then \
			echo "📝  Scanning $$f"; \
			hadolint "$$f" || true; \
			found=1; \
		fi; \
	done; \
	if [ "$$found" -eq 0 ]; then \
		echo "ℹ️  No Containerfile/Dockerfile found – nothing to scan."; \
	fi

# =============================================================================
# 📦 DEPENDENCY MANAGEMENT
# =============================================================================
# help: 📦 DEPENDENCY MANAGEMENT
# help: containerfile-update - Update base image in Containerfile to latest tag

.PHONY: containerfile-update

containerfile-update:
	@echo "⬆️  Updating base image in Containerfile to :latest tag…"
	@test -f Containerfile || { echo "❌ Containerfile not found."; exit 1; }
	@sed -i.bak -E 's|^(FROM\s+\S+):[^\s]+|\1:latest|' Containerfile && rm -f Containerfile.bak
	@echo "✅ Base image updated to latest."

# =============================================================================
# 🦭 PODMAN CONTAINER BUILD & RUN
# =============================================================================
# help: 🦭 PODMAN CONTAINER BUILD & RUN
# help: podman-dev           - Build development container image
# help: podman               - Build production container image
# help: podman-run           - Run the container on HTTP  (port 4444)
# help: podman-run-shell     - Run the container on HTTP  (port 4444) and start a shell
# help: podman-run-ssl       - Run the container on HTTPS (port 4444, self-signed)
# help: podman-stop          - Stop & remove the container
# help: podman-test          - Quick curl smoke-test against the container
# help: podman-logs          - Follow container logs (⌃C to quit)

.PHONY: podman-dev podman podman-run podman-run-shell podman-run-ssl podman-stop podman-test

IMG               ?= $(PROJECT_NAME)/$(PROJECT_NAME)
IMG_DEV            = $(IMG)-dev
IMG_PROD           = $(IMG)

podman-dev:
	@echo "🦭  Building dev container…"
	podman build --ssh default --build-arg IBMCLOUD_PLUGINS=$(IBMCLOUD_PLUGINS) --platform=linux/amd64 --squash \
	             -t $(IMG_DEV) .

podman:
	@echo "🦭  Building container using ubi9-minimal…"
	podman build --ssh default --build-arg IBMCLOUD_PLUGINS=$(IBMCLOUD_PLUGINS) --platform=linux/amd64 --squash \
	             -t $(IMG_PROD) .
	podman images $(IMG_PROD)

## --------------------  R U N   (HTTP)  ---------------------------------------
podman-run:
	@echo "🚀  Starting podman container (HTTP)…"
	-podman stop $(PROJECT_NAME) 2>/dev/null || true
	-podman rm   $(PROJECT_NAME) 2>/dev/null || true
	podman run --name $(PROJECT_NAME) \
		--env-file=.env \
		-p 4444:4444 \
		--restart=always --memory=$(CONTAINER_MEMORY) --cpus=$(CONTAINER_CPUS) \
		--health-cmd="curl --fail http://localhost:4444/health || exit 1" \
		--health-interval=1m --health-retries=3 \
		--health-start-period=30s --health-timeout=10s \
		-d $(IMG_PROD)
	@sleep 2 && podman logs $(PROJECT_NAME) | tail -n +1

podman-run-shell:
	@echo "🚀  Starting podman container shell…"
	podman run --name $(PROJECT_NAME)-shell \
		--env-file=.env \
		-p 4444:4444 \
		--memory=$(CONTAINER_MEMORY) --cpus=$(CONTAINER_CPUS) \
		-it --rm $(IMG_PROD) \
		sh -c 'env; exec sh'

## --------------------  R U N   (HTTPS)  --------------------------------------
podman-run-ssl: certs
	@echo "🚀  Starting podman container (TLS)…"
	-podman stop $(PROJECT_NAME) 2>/dev/null || true
	-podman rm   $(PROJECT_NAME) 2>/dev/null || true
	podman run --name $(PROJECT_NAME) \
		--env-file=.env \
		-e SSL=true \
		-e CERT_FILE=certs/cert.pem \
		-e KEY_FILE=certs/key.pem \
		-v $(PWD)/certs:/app/certs:ro,Z \
		-p 4444:4444 \
		--restart=always --memory=$(CONTAINER_MEMORY) --cpus=$(CONTAINER_CPUS) \
		--health-cmd="curl -k --fail https://localhost:4444/health || exit 1" \
		--health-interval=1m --health-retries=3 \
		--health-start-period=30s --health-timeout=10s \
		-d $(IMG_PROD)
	@sleep 2 && podman logs $(PROJECT_NAME) | tail -n +1

podman-stop:
	@echo "🛑  Stopping podman container…"
	-podman stop $(PROJECT_NAME) && podman rm $(PROJECT_NAME) || true

podman-test:
	@echo "🔬  Testing podman endpoint…"
	@echo "• HTTP  -> curl  http://localhost:4444/system/test"
	@echo "• HTTPS -> curl -k https://localhost:4444/system/test"

podman-logs:
	@echo "📜  Streaming podman logs (press Ctrl+C to exit)…"
	@podman logs -f $(PROJECT_NAME)

# help: podman-stats         - Show container resource stats (if supported)
.PHONY: podman-stats
podman-stats:
	@echo "📊  Showing Podman container stats…"
	@if podman info --format '{{.Host.CgroupManager}}' | grep -q 'cgroupfs'; then \
		echo "⚠️  podman stats not supported in rootless mode without cgroups v2 (e.g., WSL2)"; \
		echo "👉  Falling back to 'podman top'"; \
		podman top $(PROJECT_NAME); \
	else \
		podman stats --no-stream; \
	fi

# help: podman-top           - Show live top-level process info in container
.PHONY: podman-top
podman-top:
	@echo "🧠  Showing top-level processes in the Podman container…"
	podman top $(PROJECT_NAME)

# help: podman-shell         - Open an interactive shell inside the Podman container
.PHONY: podman-shell
podman-shell:
	@echo "🔧  Opening shell in Podman container…"
	@podman exec -it $(PROJECT_NAME) bash || podman exec -it $(PROJECT_NAME) /bin/sh

# =============================================================================
# 🐋 DOCKER BUILD & RUN
# =============================================================================
# help: 🐋 DOCKER BUILD & RUN
# help: docker-dev           - Build development Docker image
# help: docker               - Build production Docker image
# help: docker-run           - Run the container on HTTP  (port 4444)
# help: docker-run-ssl       - Run the container on HTTPS (port 4444, self-signed)
# help: docker-stop          - Stop & remove the container
# help: docker-test          - Quick curl smoke-test against the container
# help: docker-logs          - Follow container logs (⌃C to quit)

.PHONY: docker-dev docker docker-run docker-run-ssl docker-stop docker-test

IMG_DOCKER_DEV  = $(IMG)-dev:latest
IMG_DOCKER_PROD = $(IMG):latest

docker-dev:
	@echo "🐋  Building dev Docker image…"
	docker build --build-arg IBMCLOUD_PLUGINS=$(IBMCLOUD_PLUGINS) --platform=linux/amd64 -t $(IMG_DOCKER_DEV) .

docker:
	@echo "🐋  Building production Docker image…"
	docker build --build-arg IBMCLOUD_PLUGINS=$(IBMCLOUD_PLUGINS) --platform=linux/amd64 -t $(IMG_DOCKER_PROD) -f Containerfile .

## --------------------  R U N   (HTTP)  ---------------------------------------
docker-run:
	@echo "🚀  Starting Docker container (HTTP)…"
	-docker stop $(PROJECT_NAME) 2>/dev/null || true
	-docker rm   $(PROJECT_NAME) 2>/dev/null || true
	docker run --name $(PROJECT_NAME) \
		--env-file=.env \
		-p 4444:4444 \
		--restart=always --memory=$(CONTAINER_MEMORY) --cpus=$(CONTAINER_CPUS) \
		--health-cmd="curl --fail http://localhost:4444/health || exit 1" \
		--health-interval=1m --health-retries=3 \
		--health-start-period=30s --health-timeout=10s \
		-d $(IMG_DOCKER_PROD)
	@sleep 2 && docker logs $(PROJECT_NAME) | tail -n +1

## --------------------  R U N   (HTTPS)  --------------------------------------
docker-run-ssl: certs
	@echo "🚀  Starting Docker container (TLS)…"
	-docker stop $(PROJECT_NAME) 2>/dev/null || true
	-docker rm   $(PROJECT_NAME) 2>/dev/null || true
	docker run --name $(PROJECT_NAME) \
		--env-file=.env \
		-e SSL=true \
		-e CERT_FILE=certs/cert.pem \
		-e KEY_FILE=certs/key.pem \
		-v $(PWD)/certs:/app/certs:ro \
		-p 4444:4444 \
		--restart=always --memory=$(CONTAINER_MEMORY) --cpus=$(CONTAINER_CPUS) \
		--health-cmd="curl -k --fail https://localhost:4444/health || exit 1" \
		--health-interval=1m --health-retries=3 \
		--health-start-period=30s --health-timeout=10s \
		-d $(IMG_DOCKER_PROD)
	@sleep 2 && docker logs $(PROJECT_NAME) | tail -n +1

docker-stop:
	@echo "🛑  Stopping Docker container…"
	-docker stop $(PROJECT_NAME) && docker rm $(PROJECT_NAME) || true

docker-test:
	@echo "🔬  Testing Docker endpoint…"
	@echo "• HTTP  -> curl  http://localhost:4444/system/test"
	@echo "• HTTPS -> curl -k https://localhost:4444/system/test"


docker-logs:
	@echo "📜  Streaming Docker logs (press Ctrl+C to exit)…"
	@docker logs -f $(PROJECT_NAME)

# help: docker-stats         - Show container resource usage stats (non-streaming)
.PHONY: docker-stats
docker-stats:
	@echo "📊  Showing Docker container stats…"
	@docker stats --no-stream || { echo "⚠️  Failed to fetch docker stats. Falling back to 'docker top'…"; docker top $(PROJECT_NAME); }

# help: docker-top           - Show top-level process info in Docker container
.PHONY: docker-top
docker-top:
	@echo "🧠  Showing top-level processes in the Docker container…"
	docker top $(PROJECT_NAME)

# help: docker-shell         - Open an interactive shell inside the Docker container
.PHONY: docker-shell
docker-shell:
	@echo "🔧  Opening shell in Docker container…"
	@docker exec -it $(PROJECT_NAME) bash || docker exec -it $(PROJECT_NAME) /bin/sh

# =============================================================================
# ☁️ IBM CLOUD CODE ENGINE
# =============================================================================
# help: ☁️ IBM CLOUD CODE ENGINE
# help: ibmcloud-check-env          - Verify all required IBM Cloud env vars are set
# help: ibmcloud-cli-install        - Auto-install IBM Cloud CLI + required plugins (OS auto-detected)
# help: ibmcloud-login              - Login to IBM Cloud CLI using IBMCLOUD_API_KEY (--sso)
# help: ibmcloud-ce-login           - Set Code Engine target project and region
# help: ibmcloud-list-containers    - List deployed Code Engine apps
# help: ibmcloud-tag                - Tag container image for IBM Container Registry
# help: ibmcloud-push               - Push image to IBM Container Registry
# help: ibmcloud-deploy             - Deploy (or update) container image in Code Engine
# help: ibmcloud-ce-logs            - Stream logs for the deployed application
# help: ibmcloud-ce-status          - Get deployment status
# help: ibmcloud-ce-rm              - Delete the Code Engine application

.PHONY: ibmcloud-check-env ibmcloud-cli-install ibmcloud-login ibmcloud-ce-login \
        ibmcloud-list-containers ibmcloud-tag ibmcloud-push ibmcloud-deploy \
        ibmcloud-ce-logs ibmcloud-ce-status ibmcloud-ce-rm

# ─────────────────────────────────────────────────────────────────────────────
# 📦  Load environment file with IBM Cloud Code Engine configuration
#     • .env.ce   – IBM Cloud / Code Engine deployment vars
# ─────────────────────────────────────────────────────────────────────────────
-include .env.ce

# Export only the IBM-specific variables (those starting with IBMCLOUD_)
export $(shell grep -E '^IBMCLOUD_' .env.ce 2>/dev/null | sed -E 's/^\s*([^=]+)=.*/\1/')

## Optional / defaulted ENV variables:
IBMCLOUD_CPU            ?= 1      # vCPU allocation for Code Engine app
IBMCLOUD_MEMORY         ?= 4G     # Memory allocation for Code Engine app
IBMCLOUD_REGISTRY_SECRET ?= $(IBMCLOUD_PROJECT)-registry-secret

## Required ENV variables:
# IBMCLOUD_REGION              = IBM Cloud region (e.g. us-south)
# IBMCLOUD_PROJECT             = Code Engine project name
# IBMCLOUD_RESOURCE_GROUP      = IBM Cloud resource group name (e.g. default)
# IBMCLOUD_CODE_ENGINE_APP     = Code Engine app name
# IBMCLOUD_IMAGE_NAME          = Full image path (e.g. us.icr.io/namespace/app:tag)
# IBMCLOUD_IMG_PROD            = Local container image name
# IBMCLOUD_API_KEY             = IBM Cloud IAM API key (optional, use --sso if not set)

ibmcloud-check-env:
	@bash -eu -o pipefail -c '\
		echo "🔍  Verifying required IBM Cloud variables (.env.ce)…"; \
		missing=0; \
		for var in IBMCLOUD_REGION IBMCLOUD_PROJECT IBMCLOUD_RESOURCE_GROUP \
		           IBMCLOUD_CODE_ENGINE_APP IBMCLOUD_IMAGE_NAME IBMCLOUD_IMG_PROD \
		           IBMCLOUD_CPU IBMCLOUD_MEMORY IBMCLOUD_REGISTRY_SECRET; do \
			if [ -z "$${!var}" ]; then \
				echo "❌  Missing: $$var"; \
				missing=1; \
			fi; \
		done; \
		if [ -z "$$IBMCLOUD_API_KEY" ]; then \
			echo "⚠️   IBMCLOUD_API_KEY not set – interactive SSO login will be used"; \
		else \
			echo "🔑  IBMCLOUD_API_KEY found"; \
		fi; \
		if [ "$$missing" -eq 0 ]; then \
			echo "✅  All required variables present in .env.ce"; \
		else \
			echo "💡  Add the missing keys to .env.ce before continuing."; \
			exit 1; \
		fi'

ibmcloud-cli-install:
	@echo "☁️  Detecting OS and installing IBM Cloud CLI…"
	@if grep -qi microsoft /proc/version 2>/dev/null; then \
		echo "🔧 Detected WSL2"; \
		curl -fsSL https://clis.cloud.ibm.com/install/linux | sh; \
	elif [ "$$(uname)" = "Darwin" ]; then \
		echo "🍏 Detected macOS"; \
		curl -fsSL https://clis.cloud.ibm.com/install/osx | sh; \
	elif [ "$$(uname)" = "Linux" ]; then \
		echo "🐧 Detected Linux"; \
		curl -fsSL https://clis.cloud.ibm.com/install/linux | sh; \
	elif command -v powershell.exe >/dev/null; then \
		echo "🪟 Detected Windows"; \
		powershell.exe -Command "iex (New-Object Net.WebClient).DownloadString('https://clis.cloud.ibm.com/install/powershell')"; \
	else \
		echo "❌ Unsupported OS"; exit 1; \
	fi
	@echo "✅ CLI installed. Installing required plugins…"
	@ibmcloud plugin install container-registry -f
	@ibmcloud plugin install code-engine -f
	@ibmcloud --version

ibmcloud-login:
	@echo "🔐 Starting IBM Cloud login…"
	@echo "──────────────────────────────────────────────"
	@echo "👤  User:               $(USER)"
	@echo "📍  Region:             $(IBMCLOUD_REGION)"
	@echo "🧵  Resource Group:     $(IBMCLOUD_RESOURCE_GROUP)"
	@if [ -n "$(IBMCLOUD_API_KEY)" ]; then \
		echo "🔑  Auth Mode:          API Key (with --sso)"; \
	else \
		echo "🔑  Auth Mode:          Interactive (--sso)"; \
	fi
	@echo "──────────────────────────────────────────────"
	@if [ -z "$(IBMCLOUD_REGION)" ] || [ -z "$(IBMCLOUD_RESOURCE_GROUP)" ]; then \
		echo "❌ IBMCLOUD_REGION or IBMCLOUD_RESOURCE_GROUP is missing. Aborting."; \
		exit 1; \
	fi
	@if [ -n "$(IBMCLOUD_API_KEY)" ]; then \
		ibmcloud login --apikey "$(IBMCLOUD_API_KEY)" --sso -r "$(IBMCLOUD_REGION)" -g "$(IBMCLOUD_RESOURCE_GROUP)"; \
	else \
		ibmcloud login --sso -r "$(IBMCLOUD_REGION)" -g "$(IBMCLOUD_RESOURCE_GROUP)"; \
	fi
	@echo "🎯 Targeting region and resource group…"
	@ibmcloud target -r "$(IBMCLOUD_REGION)" -g "$(IBMCLOUD_RESOURCE_GROUP)"
	@ibmcloud target

ibmcloud-ce-login:
	@echo "🎯 Targeting Code Engine project '$(IBMCLOUD_PROJECT)' in region '$(IBMCLOUD_REGION)'…"
	@ibmcloud ce project select --name "$(IBMCLOUD_PROJECT)"

ibmcloud-list-containers:
	@echo "📦 Listing Code Engine images"
	ibmcloud cr images
	@echo "📦 Listing Code Engine applications…"
	@ibmcloud ce application list

ibmcloud-tag:
	@echo "🏷️  Tagging image $(IBMCLOUD_IMG_PROD) → $(IBMCLOUD_IMAGE_NAME)"
	podman tag $(IBMCLOUD_IMG_PROD) $(IBMCLOUD_IMAGE_NAME)
	podman images | head -3

ibmcloud-push:
	@echo "📤 Logging into IBM Container Registry and pushing image…"
	@ibmcloud cr login
	podman push $(IBMCLOUD_IMAGE_NAME) --creds iamapikey:$(IBMCLOUD_API_KEY)  

ibmcloud-deploy:
	@echo "🚀 Deploying image to Code Engine as '$(IBMCLOUD_CODE_ENGINE_APP)' using registry secret $(IBMCLOUD_REGISTRY_SECRET)…"
	@if ibmcloud ce application get --name $(IBMCLOUD_CODE_ENGINE_APP) > /dev/null 2>&1; then \
		echo "🔁 Updating existing app…"; \
		ibmcloud ce application update --name $(IBMCLOUD_CODE_ENGINE_APP) \
			--image private.$(IBMCLOUD_IMAGE_NAME) \
			--cpu $(IBMCLOUD_CPU) --memory $(IBMCLOUD_MEMORY) \
			--env-from-secret $(IBMCLOUD_ENV_SECRET) \
			--env-from-configmap $(IBMCLOUD_ENV_CONFIGMAP) \
			--registry-secret $(IBMCLOUD_REGISTRY_SECRET); \
	else \
		echo "🆕 Creating new app…"; \
		ibmcloud ce application create --name $(IBMCLOUD_CODE_ENGINE_APP) \
			--image private.$(IBMCLOUD_IMAGE_NAME) \
			--cpu $(IBMCLOUD_CPU) --memory $(IBMCLOUD_MEMORY) \
			--env-from-secret $(IBMCLOUD_ENV_SECRET) \
			--env-from-configmap $(IBMCLOUD_ENV_CONFIGMAP) \
			--port 4444 \
			--registry-secret $(IBMCLOUD_REGISTRY_SECRET); \
	fi

ibmcloud-ce-logs:
	@echo "📜 Streaming logs for '$(IBMCLOUD_CODE_ENGINE_APP)'…"
	@ibmcloud ce application logs --name $(IBMCLOUD_CODE_ENGINE_APP) --follow

ibmcloud-ce-status:
	@echo "📈 Application status for '$(IBMCLOUD_CODE_ENGINE_APP)'…"
	@ibmcloud ce application get --name $(IBMCLOUD_CODE_ENGINE_APP)

ibmcloud-ce-rm:
	@echo "🗑️  Deleting Code Engine app: $(IBMCLOUD_CODE_ENGINE_APP)…"
	@ibmcloud ce application delete --name $(IBMCLOUD_CODE_ENGINE_APP) -f
