#!/bin/sh
set -e
# Merge LOB-level MCP servers with project-level MCP servers.
# LOB MCP config provides baseline servers; project can add more.
# Project servers override team servers with the same name.
if [ -f /home/node/.claude.json ] && [ -f /tmp/project-claude/claude.json ]; then
    jq -s '
      .[0] as $team | .[1] as $proj |
      { mcpServers: (($team.mcpServers // {}) * ($proj.mcpServers // {})) }
    ' /home/node/.claude.json /tmp/project-claude/claude.json \
      > /tmp/merged-mcp.json \
      && mv /tmp/merged-mcp.json /home/node/.claude.json
elif [ -f /tmp/project-claude/claude.json ]; then
    cp /tmp/project-claude/claude.json /home/node/.claude.json
fi
