#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d /tmp/omarchy-screen-mirroring-tests.XXXXXX)"
trap 'find "$TEST_ROOT" -depth -delete' EXIT

export HOME="$TEST_ROOT/home"
export XDG_CONFIG_HOME="$TEST_ROOT/config"
export XDG_CACHE_HOME="$TEST_ROOT/cache"
export XDG_RUNTIME_DIR="$TEST_ROOT/runtime"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"

# shellcheck source=../bin/omarchy-screen-mirroring
source "$REPOSITORY_ROOT/bin/omarchy-screen-mirroring"

ensure_private_state_dir
lock_operations
PKEXEC="$REPOSITORY_ROOT/tests/mock-pkexec"
export PENDING_CLEANUP_FILE
export MOCK_UFW_LOG="$TEST_ROOT/ufw.log"
: > "$MOCK_UFW_LOG"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_pending() {
  local expected=$1 actual
  actual="$(pending_cleanup_list | paste -sd, -)"
  [[ "$actual" == "$expected" ]] || fail "pending cleanup was '$actual', expected '$expected'"
}

# The cleanup ledger is a durable set, not a single overwriteable slot.
pending_cleanup_add 198.51.100.2
pending_cleanup_add 192.0.2.1
pending_cleanup_add 198.51.100.2
assert_pending "192.0.2.1,198.51.100.2"
pending_cleanup_remove 192.0.2.1
assert_pending "198.51.100.2"
pending_cleanup_remove 198.51.100.2

# Cleanup intent must exist before either privileged allow command runs.
export MOCK_REQUIRE_PENDING=true
open_ports_for_connection 192.0.2.10
assert_pending "192.0.2.10"
export MOCK_REQUIRE_PENDING=false
close_ports_after_connection 192.0.2.10
pending_cleanup_has_entries && fail "successful cleanup left a pending entry"

# A partial open whose rollback also fails must retain its durable cleanup entry.
export MOCK_FAIL_TCP_ALLOW=true
export MOCK_FAIL_UDP_DELETE=true
(open_ports_for_connection 192.0.2.20 >/dev/null 2>&1) || true
assert_pending "192.0.2.20"
export MOCK_FAIL_TCP_ALLOW=false
export MOCK_FAIL_UDP_DELETE=false
attempt_port_cleanup
pending_cleanup_has_entries && fail "retry did not clear the pending entry"

# Cleanup must still attempt TCP if the UDP deletion fails.
pending_cleanup_add 192.0.2.30
: > "$MOCK_UFW_LOG"
export MOCK_FAIL_UDP_DELETE=true
attempt_port_cleanup && fail "cleanup unexpectedly succeeded"
grep -Fq "proto tcp" "$MOCK_UFW_LOG" || fail "TCP cleanup was skipped after a UDP failure"
export MOCK_FAIL_UDP_DELETE=false
attempt_port_cleanup

# The detached supervisor observes the exact process identity and cleans after exit.
cp /usr/bin/sleep "$TEST_ROOT/doubletake"
setsid "$TEST_ROOT/doubletake" 1 9>&- &
supervised_pid=$!
supervised_start="$(process_starttime "$supervised_pid")"
printf '%s\n' "$supervised_pid" > "$STREAM_PID_FILE"
printf '%s\n' "$supervised_pid" > "$STREAM_PGID_FILE"
printf '%s\n' "$supervised_start" > "$STREAM_START_FILE"
printf '%s\n' 192.0.2.40 > "$STREAM_IP_FILE"
pending_cleanup_add 192.0.2.40
: > "$MOCK_UFW_LOG"
supervise_stream "$supervised_pid" "$supervised_start" 192.0.2.40
pending_cleanup_has_entries && fail "supervisor left a pending cleanup entry"
[[ ! -f "$STREAM_PID_FILE" ]] || fail "supervisor left stale stream state"
grep -Fq "delete allow from 192.0.2.40" "$MOCK_UFW_LOG" || fail "supervisor did not remove firewall rules"

# Every receiver-controlled Text item is explicitly plain text, and names are sanitized.
grep -Fq 'textFormat: Text.PlainText' "$REPOSITORY_ROOT/Panel.qml" || fail "plain-text QML hardening is missing"
grep -Fq '.replace(/[<>]/g, "")' "$REPOSITORY_ROOT/Model.js" || fail "receiver text sanitization is missing"

printf 'security tests passed\n'
