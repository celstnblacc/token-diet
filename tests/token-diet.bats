#!/usr/bin/env bats
# Tests for scripts/token-diet CLI

load test_helper

# ---------------------------------------------------------------------------
# Cycle 1.1 — basic dispatch
# ---------------------------------------------------------------------------

@test "token-diet --help prints USAGE and COMMANDS and exits 0" {
  run "$SCRIPTS_DIR/token-diet" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
  [[ "$output" == *"COMMANDS"* ]]
}

@test "token-diet help (subcommand) exits 0" {
  run "$SCRIPTS_DIR/token-diet" help
  [ "$status" -eq 0 ]
}

@test "token-diet unknown command exits 1" {
  run "$SCRIPTS_DIR/token-diet" nonexistent-command
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Cycle 2.1 — health: missing tools
# ---------------------------------------------------------------------------

@test "health: exits 1 and prints tool names when no tools installed" {
  # Shadow real tools with stubs that exit 1 so health sees them as missing
  for tool in rtk tilth uvx docker; do
    printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP_BIN/$tool"
    chmod +x "$TMP_BIN/$tool"
  done

  run "$SCRIPTS_DIR/token-diet" health
  [ "$status" -eq 1 ]
  [[ "$output" == *"RTK"* ]]
  [[ "$output" == *"tilth"* ]]
  [[ "$output" == *"Serena"* ]]
}

# ---------------------------------------------------------------------------
# Cycle 2.2 — health: all tools present
# ---------------------------------------------------------------------------

@test "health: exits 0 when all three tools are available" {
  mock_cmd_with_gain
  mock_cmd tilth
  mock_cmd uvx

  run "$SCRIPTS_DIR/token-diet" health
  [ "$status" -eq 0 ]
  [[ "$output" == *"All tools healthy"* ]]
}

# ---------------------------------------------------------------------------
# Cycle 2.3 — health: MCP host registration
# ---------------------------------------------------------------------------

@test "health: shows MCP host names when tools are registered" {
  mock_cmd_with_gain
  mock_cmd tilth
  mock_cmd uvx
  mock_mcp_config claude-code tilth
  mock_mcp_config claude-code serena

  run "$SCRIPTS_DIR/token-diet" health
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude-code"* ]]
}

# ---------------------------------------------------------------------------
# Cycle 2.4 — health: listed in --help
# ---------------------------------------------------------------------------

@test "help text includes health command" {
  run "$SCRIPTS_DIR/token-diet" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"health"* ]]
}

# ---------------------------------------------------------------------------
# Cycle 3.7 — uninstall dispatch
# ---------------------------------------------------------------------------

@test "uninstall subcommand dispatches to uninstall.sh" {
  # Plant a file to prove uninstall ran
  mkdir -p "$TMP_HOME/.local/bin"
  echo "#!/bin/bash" > "$TMP_HOME/.local/bin/token-diet-dashboard"
  chmod +x "$TMP_HOME/.local/bin/token-diet-dashboard"

  run "$SCRIPTS_DIR/token-diet" uninstall --force
  [ "$status" -eq 0 ]
  [ ! -f "$TMP_HOME/.local/bin/token-diet-dashboard" ]
}
