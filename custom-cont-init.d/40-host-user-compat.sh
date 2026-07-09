#!/usr/bin/with-contenv bash
set -euo pipefail

host_user="${HOST_USER:-}"
host_uid="${HOST_UID:-${PUID:-1000}}"
host_gid="${HOST_GID:-${PGID:-1000}}"
container_user="${CONTAINER_USER:-}"
linuxserver_user="abc"

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

if [[ "${container_user}" != "${linuxserver_user}" ]]; then
  group_tmp="$(mktemp)"
  awk -F: -v source="${linuxserver_user}" -v target="${container_user}" '
    BEGIN { OFS = FS }
    {
      split($4, members, ",")
      has_source = 0
      has_target = 0
      for (idx in members) {
        if (members[idx] == source) has_source = 1
        if (members[idx] == target) has_target = 1
      }
      if (has_source && !has_target) {
        $4 = ($4 == "" ? target : $4 "," target)
      }
      print
    }
  ' /etc/group >"${group_tmp}"
  cat "${group_tmp}" >/etc/group
  rm -f "${group_tmp}"
fi

passwd_tmp="$(mktemp)"
awk -F: -v name="${container_user}" '$1 != name' /etc/passwd >"${passwd_tmp}"
{
  echo "${container_user}:x:${host_uid}:${host_gid}:Docker desktop for ${host_user}:/config:/bin/bash"
  cat "${passwd_tmp}"
} >/etc/passwd
rm -f "${passwd_tmp}"

if [[ -f /etc/shadow && "${container_user}" != "${linuxserver_user}" ]]; then
  shadow_template="$(awk -F: -v name="${linuxserver_user}" '$1 == name { sub(/^[^:]*:/, ""); print; exit }' /etc/shadow || true)"
  if [[ -z "${shadow_template}" ]]; then
    shadow_template="*:0:0:99999:7:::"
  fi
  shadow_tmp="$(mktemp)"
  awk -F: -v name="${container_user}" '$1 != name' /etc/shadow >"${shadow_tmp}"
  {
    echo "${container_user}:${shadow_template}"
    cat "${shadow_tmp}"
  } >/etc/shadow
  rm -f "${shadow_tmp}"
  chmod 0600 /etc/shadow
fi

if command -v visudo >/dev/null 2>&1 && [[ "${container_user}" != "${linuxserver_user}" ]]; then
  sudoers_file="/etc/sudoers.d/kde-webtop-${container_user}"
  printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "${container_user}" >"${sudoers_file}"
  chmod 0440 "${sudoers_file}"
  visudo -cf "${sudoers_file}" >/dev/null
fi

install -d -m 755 /home
if [[ ! -e "/home/${container_user}" ]]; then
  ln -s /config "/home/${container_user}"
fi

echo "[host-user] Preferred ${container_user} as UID ${host_uid}, GID ${host_gid}, HOME /config; kept ${linuxserver_user} compatibility"
