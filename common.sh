#!/usr/bin/env bash
# common.sh - Common environment variables

# Default PostgreSQL version and derived values
export PG_VERSION="${PG_VERSION:-17.5}"
export PG_MAJOR_VERSION="$(echo "$PG_VERSION" | cut -d. -f1)"

# Spock patch repo and branch
export PG_SPOCK_REPO="https://github.com/pgEdge/spock.git"
export SPOCK_BRANCH="main"
