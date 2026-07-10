#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

set -a
source .env
set +a

scripts/deployment/actions/ensure-gateway-tls.sh

compose=(
  docker compose
  --env-file .env
  -f compose/webtop-kde.yml
  --profile frpc
)

"${compose[@]}" pull --ignore-buildable --ignore-pull-failures
"${compose[@]}" build --pull
"${compose[@]}" up -d --build --remove-orphans

docker image prune -f
docker builder prune -af --filter "until=24h"
