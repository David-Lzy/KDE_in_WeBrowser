#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${ENV_FILE:-$repo_dir/.env}"
output_file="${1:-${BAOTA_COMPOSE_FILE:-$repo_dir/data/baota/docker-compose.yml}}"
profiles_raw="${BAOTA_COMPOSE_PROFILES:-${COMPOSE_PROFILES:-frpc}}"

compose_files=(
  "$repo_dir/compose/webtop-kde.yml"
  "$repo_dir/compose.local.yml"
)

if [[ ! -f "$env_file" ]]; then
  echo "missing env file: $env_file" >&2
  echo "run scripts/install.sh or scripts/configure-deployment.sh first" >&2
  exit 1
fi

for compose_file in "${compose_files[@]}"; do
  if [[ ! -f "$compose_file" ]]; then
    echo "missing compose file: $compose_file" >&2
    echo "run scripts/install.sh or scripts/configure-deployment.sh first" >&2
    exit 1
  fi
done

profile_args=()
case "${profiles_raw,,}" in
  "" | "0" | "false" | "none" | "off" | "skip")
    ;;
  *)
    IFS=', ' read -r -a profiles <<<"$profiles_raw"
    for profile in "${profiles[@]}"; do
      [[ -n "$profile" ]] && profile_args+=(--profile "$profile")
    done
    ;;
esac

mkdir -p "$(dirname "$output_file")"
rendered="$(mktemp)"
stripped="$(mktemp)"
trap 'rm -f "$rendered" "$stripped"' EXIT

docker compose \
  "${profile_args[@]}" \
  --env-file "$env_file" \
  -f "${compose_files[0]}" \
  -f "${compose_files[1]}" \
  config >"$rendered"

# Baota calls docker compose without profile flags. Keep only the services
# selected above, then remove their profile markers from the generated file.
awk '
  skip_profiles {
    if ($0 ~ /^      - /) next
    skip_profiles = 0
  }
  /^    profiles:$/ {
    skip_profiles = 1
    next
  }
  { print }
' "$rendered" >"$stripped"

install -m 0644 "$stripped" "$output_file"
docker compose -f "$output_file" config --quiet
printf 'Rendered Baota compose: %s\n' "$output_file"
