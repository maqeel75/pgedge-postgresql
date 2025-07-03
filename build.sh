#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
  echo "Detected RPM-based system"
  source "$(dirname "$0")/build-rpm.sh"
elif command -v apt-get &>/dev/null; then
  echo "Detected Debian-based system"
  source "$(dirname "$0")/build-deb.sh"
else
  echo "Unsupported platform: No known package manager found" >&2
  exit 1
fi

###########
# Main
###########
prepare
build
post_build
