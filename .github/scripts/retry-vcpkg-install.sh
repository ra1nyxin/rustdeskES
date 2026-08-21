#!/usr/bin/env bash

set -uo pipefail

max_attempts="${VCPKG_INSTALL_ATTEMPTS:-10}"
base_delay_seconds="${VCPKG_RETRY_BASE_DELAY_SECONDS:-15}"

if [[ ! "$max_attempts" =~ ^[1-9][0-9]*$ ]] || \
   [[ ! "$base_delay_seconds" =~ ^[1-9][0-9]*$ ]]; then
  echo "::error::VCPKG_INSTALL_ATTEMPTS and VCPKG_RETRY_BASE_DELAY_SECONDS must be positive integers"
  exit 2
fi

if (( $# == 0 )); then
  echo "::error::No vcpkg install command was supplied"
  exit 2
fi

attempt=1
while (( attempt <= max_attempts )); do
  echo "Running vcpkg dependency installation (attempt ${attempt}/${max_attempts})"
  if "$@"; then
    exit 0
  else
    status=$?
  fi

  if (( attempt == max_attempts )); then
    echo "::error::vcpkg dependency installation failed after ${max_attempts} attempts"
    if [[ -n "${VCPKG_ROOT:-}" && -d "${VCPKG_ROOT}" ]]; then
      while IFS= read -r -d '' log_file; do
        echo "${log_file}:"
        echo "======"
        cat "${log_file}"
        echo "======"
      done < <(find "${VCPKG_ROOT}" -name "*.log" -type f -print0)
    fi
    exit "$status"
  fi

  if [[ -n "${VCPKG_ROOT:-}" && -d "${VCPKG_ROOT}/downloads" ]]; then
    find "${VCPKG_ROOT}/downloads" -type f \
      \( -name "*.part" -o -name "*.tmp" -o -size 0 \) -delete
  fi

  delay_seconds=$((base_delay_seconds * attempt))
  if (( delay_seconds > 120 )); then
    delay_seconds=120
  fi
  echo "::warning::vcpkg attempt ${attempt} failed with exit code ${status}; retrying in ${delay_seconds} seconds"
  sleep "$delay_seconds"
  attempt=$((attempt + 1))
done
