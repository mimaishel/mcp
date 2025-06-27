# IBM Cloud MCP Server

The IBM Cloud MCP Server provides an interface layer between AI assistants and IBM Cloud CLI tools. This README details how to install, build, configure, and run the MCP Server for development and testing.

## Overview

The MCP server implementation for IBM Cloud is built directly into the IBM Cloud CLI native binaries.
MCP features are provided as **EXPERIMENTAL** features at this time.

There are two runtime scenarios supported:

1. **Local install** - Configure any MCP Host Application (Claude, VSCode, Cursor, Cline, mcp-cli, etc.) to use IBM Cloud CLI as an MCP server.  This scenario involves installing the IBM Cloud CLI locally and then updating the host application's JSON MCP configuration settings to use the IBM Cloud CLI in MCP mode, using the stdio mcp transport.
2. **Containerized MCP Servers** - Use the Containers provided in the `/src` dir to build fit-for-purpose containerized versions of the IBM Cloud MCP Server which can be deployed on any container runtime (podman, docker, IBM Cloud Code Engine, Redhat OpenShift, Kubernetes, etc.) to run as an MCP Remote server (HTTP transport).  This scenario involves building the container file, providinging environment variables to configure the appropriate tools to be exposed via MCP, and securely configuring the credentials to be used for the container. 

## 💻 Local Install

### Don't have IBM Cloud CLI? --> Install it!

Simply [install the IBM Cloud CLI](https://cloud.ibm.com/docs/cli?topic=cli-install-ibmcloud-cli)--that's all you need!

### Already have IBM Cloud CLI? --> Check to see if you have MCP features

If you already have the IBM Cloud CLI installed, check to see if MCP features are available:

```sh
ibmcloud --help
```

If you already have MCP features, you will see the following section near the bottom of the output:

```text
MCP OPTIONS:
  --mcp-transport      [EXPERIMENTAL] Specify the transport to start the MCP server. Valid options are `stdio` or a valid `HTTP SSE URL`.
  --mcp-tools          [EXPERIMENTAL] Specifies an optional comma-delimited list of commands to expose as MCP tools.
  --mcp-allow-write    [EXPERIMENTAL] Allows write operations for tasks such as creating a resource.
```

If you don't have MCP features, update with:

```sh
ibmcloud update
ibmcloud --help
```

Verify that the `MCP OPTIONS` are available and proceed with configuring your host application to use the IBM Cloud MCP Server (proceed to the `Usage` section below).

## 📦 Containerized IBMCloud MCP Servers

Containerfiles and Makefiles for building IBM Cloud MCP Server containers are located in directories under the `/src` folder.

>You can also use the IBM Cloud MCP Server Containerized installation instead of the Local Install steps in the previous section if you have `podman`, `docker` or similar container runtime installed locally.

Get started using containized IBM Cloud MCP Servers with the [Core MCP Server](servers/core-mcp-server.md)

## 🤏🏻 Usage (Local Installs)

1. Obtain an IBM Cloud **API key** with minimal permissions for testing.

> This should preferably be a **service id** api-key rather than user api-key, to restrict access privileges to only areas of IBM Cloud that you will be testing with the MCP server. For the name of the service id, you can use the name of a fictional platform engineering agent like, “<your_initials>-network-engineer” or “<your_initials>-account-manager”.  Then create an access group that assigns your new service id with the restricted access permissions that you want to allow the simulated agent to use.  

2. Find the path to your IBM Cloud CLI binary:

```bash
where ibmcloud
```

3. Log in:

```bash
ibmcloud login --apikey <your-api-key>
```

4. Set up a host app like [mcp-cli](https://github.com/IBM/mcp-cli) and configure the MCP json for the host app to point to the IBM Cloud CLI binary and allowed tools:

```json
{
  "mcpServers": {
    "ibmcloud": {
      "command": "/path/to/ibmcloud",  
      "args": [
        "--mcp-transport", "stdio",
        "--mcp-tools", "resource_groups,target,COMMANDS_THAT_LIST_AND_VIEW_RESOURCES"
      ]
    }
  }
}
```

## 🛡️ Safe mode -- Secure by default

The default configuration of IBM Cloud MCP Server will run in **Safe Mode** which will not allow tools which make changes to IBM Cloud resources to be invoked via MCP.  To override this default behavior, use the `--mcp-allow-write` argument in the mcp configuration, eg.:

```json
{
  "mcpServers": {
    "ibmcloud": {
      "command": "/path/to/ibmcloud",
      "args": [
        "--mcp-transport", "stdio",
        "--mcp-allow-write",
        "--mcp-tools", "resource_groups,target,COMMANDS_THAT_CREATE_UPDATE_OR_DELETE_RESOURCES"
      ]
    }
  }
}
```

## Project Directory Structure

The repository is organized as follows:

```text
docs/                   # Website documentation
src/                    # IBM Cloud MCP Server containers
  core/                 # MCP Server for IBM Cloud core tools
  serverless/           # MCP Server container configurations for Serverless computing on IBM Cloud
  OTHER_SERVICES/       # MCP Server container configurations for other IBM Cloud services
```

- **docs/** is reserved for future website templates.
- **src/** contains scripts to build fit-for purpose MCP Server containers
- **src/core** contains all files related to the IBM Cloud MCP Server container, including build scripts and documentation.
- **core/.env.example** and **core/.env.ce.example** provide templates for required environment variables.
- **core/start.sh** is the script executed when the container starts.

MCP Server container configurations are provided for each each major IBM Cloud subsystem withing the `/src` directory. 

## OpenAI and LLM Access

- Add `OPENAI_API_KEY` to your `.env`.  See template `.env` files in the `/src/core` directory.
- Optionally, configure [Ollama](https://ollama.com/) for local model testing.

## Running mcp-cli

1. Install `uv`: https://docs.astral.sh/uv/getting-started/installation/
2. Install [mcp-cli](https://github.com/IBM/mcp-cli)
3. Setup and run `mcp-cli`: Make sure it works with one of the basic MCP server examples and an LLM provider like OpenAI
4. Edit `server_config.json` to include ibmcloud (see above examples).
5. Restart `mcp-cli`.  Type `/tools`. The IBM Cloud tools you configured should be listed.
6. Type a prompt, eg. "List resource groups" or "Target the xxx resource group".  If you have enabled `--mcp-allow-write` mode, you can try "Create a resource group named 'mcp-test'".

## 🧠 LLM Requirements & Limitations

- Only LLMs that support **tool calling** work with MCP.
- LLM context window sizes vary and can affect results, including the ability to use multiple tools within a conversation.
- Limit tools exposed to 20–30 per session. MCP injects tool metadata into LLM context.

## 🖥️ MCP Host Applications

The IBM Cloud MCP features have been used successfully with the following MCP-compliant apps. However, any MCP-compliant host application should work, but YMMV:

- VSCode
- mcp-cli
- Cline
- Claude desktop
- Vim + mcphub
- Cursor

## 🚨 Important Security Considerations 🚨

There are common security vulnerabilities which also apply when using MCP that you should mitigate appropriately:

- Follow principle of **least priviledge**:  When configuring access policies for the service identity/IBMCLOUD_API_KEY, mitigate attacks by ensuring that your agents/host applications and MCP servers can only access resources that are allowed for the agent’s responsibility and no more.

- **Zero trust**: Secure your MCP server software supply chain--only use MCP servers from trusted sources (mitigate where possible with standards like CycloneDX SBOM)

- **Secrets management**: Never place secrets in your mcp.json config file.  Use appropriate secret managers, and use .env files as intended.

- **Prevent unintended data leaks**:  

  - MCP Server To/From Model: Data will flow back to LLM provider/model hosting locations.  Make sure these sites are trusted and secure.

  - MCP Server To/From other Agents: With multi-agent systems that have agents which use MCP, tasks may be delegated by LLM to other agents eg. Planner/Router/Director/Supervisor agents using A2A or ACP.  Since data is returned from MCP servers to LLM’s, LLM’s may use this data as input to further tasks that are sent to other agents.  Artifact output of your agents may be sent to other agents or humans via different channels (eg. push notifications, event streams).

  - MCP Server To/From other MCP Servers configured in the same agent or host application.  Data returned from MCP Servers gets passed back to the LLM for further processing.  The LLM may use this data as input to other MCP Servers it has access to via the host application, potentially sending the data into tools that provide access into other systems.  

- **Monitor all data flows** for potential data leaks. Tools like Jaeger, OpenTelemetry and security monitors configured on your agent runtimes can be used to help detect threats. 

## 🗣️ Feedback

We would love you hear your feedback on these new features through [Issues in this repo](https://github.com/IBM-Cloud/ibmcloud-mcp-server/issues).