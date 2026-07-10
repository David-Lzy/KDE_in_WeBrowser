#!/usr/bin/env bash
set -euo pipefail

deployment_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${deployment_dir}/lib/configure-flow.sh" "$@"
