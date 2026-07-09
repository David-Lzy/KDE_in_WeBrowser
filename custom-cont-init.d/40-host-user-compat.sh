#!/usr/bin/with-contenv bash
set -euo pipefail

host_user="${HOST_USER:-}"
host_uid="${HOST_UID:-${PUID:-1000}}"
host_gid="${HOST_GID:-${PGID:-1000}}"
container_user="${CONTAINER_USER:-}"

if [[ -z "${host_user}" ]]; then
  echo "[host-user] HOST_USER is unset, keeping LinuxServer default user mapping"
  exit 0
fi

if [[ -z "${container_user}" ]]; then
  container_user="docker_${host_user}"
fi

if [[ ! "${container_user}" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "[host-user] Invalid CONTAINER_USER: ${container_user}" >&2
  exit 1
fi

if [[ ! "${host_uid}" =~ ^[0-9]+$ || ! "${host_gid}" =~ ^[0-9]+$ ]]; then
  echo "[host-user] HOST_UID and HOST_GID must be numeric" >&2
  exit 1
fi

install -d -o "${host_uid}" -g "${host_gid}" -m 755 /config

group_tmp="$(mktemp)"
awk -F: -v name="${container_user}" '$1 != name' /etc/group >"${group_tmp}"
{
  echo "${container_user}:x:${host_gid}:"
  cat "${group_tmp}"
} >/etc/group
rm -f "${group_tmp}"

passwd_tmp="$(mktemp)"
awk -F: -v name="${container_user}" '$1 != name' /etc/passwd >"${passwd_tmp}"
{
  echo "${container_user}:x:${host_uid}:${host_gid}:Docker desktop for ${host_user}:/config:/bin/bash"
  cat "${passwd_tmp}"
} >/etc/passwd
rm -f "${passwd_tmp}"

install -d -m 755 /home
if [[ ! -e "/home/${container_user}" ]]; then
  ln -s /config "/home/${container_user}"
fi

echo "[host-user] Added ${container_user} as UID ${host_uid}, GID ${host_gid}, HOME /config"
