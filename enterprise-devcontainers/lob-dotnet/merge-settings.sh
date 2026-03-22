#!/bin/sh
set -e
# Merge org + LOB settings. Permissions are combined; hooks are org-only
# (intentional — org controls audit/security hooks, LOB hooks are not supported).
jq -s '
  .[0] as $org | .[1] as $team |
  ($org * $team) |
  .permissions.allow = ([$org.permissions.allow // [], $team.permissions.allow // []] | add | unique) |
  .permissions.deny  = ([$org.permissions.deny  // [], $team.permissions.deny  // []] | add | unique) |
  .hooks = ($org.hooks // {})
' /home/node/.claude/settings.json /tmp/lob-claude/settings.json \
  > /tmp/merged-settings.json \
  && mv /tmp/merged-settings.json /home/node/.claude/settings.json
