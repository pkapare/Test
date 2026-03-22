#!/usr/bin/env bash
# =============================================================================
# Runtime constants — sourced by startup scripts.
# Values baked at image build time. Override via environment variables.
# =============================================================================
PORT_SERVE_WEB="${PORT_SERVE_WEB:-8229}"
PORT_CODE_SERVER="${PORT_CODE_SERVER:-8228}"
PORT_SSH="${PORT_SSH:-2222}"
PORT_HEALTH="${PORT_HEALTH:-8080}"
SSH_PASSWORD="${SSH_PASSWORD:-claude-dev}"
CODE_SERVER_PASSWORD="${CODE_SERVER_PASSWORD:-claude-dev}"
SSH_PASSWORD_RANDOMIZE="${SSH_PASSWORD_RANDOMIZE:-true}"
