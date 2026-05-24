#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/lib/common.sh
. "$REPO_DIR/scripts/lib/common.sh"
. "$REPO_DIR/scripts/lib/kamailio.sh"
. "$REPO_DIR/scripts/lib/nginx.sh"
. "$REPO_DIR/scripts/lib/validation.sh"

main() {
  require_root
  health_check
  ok "MNSCloud Kamailio WebRTC Edge validation OK."
}

main "$@"
