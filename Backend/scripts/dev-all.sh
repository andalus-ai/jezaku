#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT_DIR}/.dev-logs"
PID_FILE="${ROOT_DIR}/.dev-pids"

mkdir -p "${LOG_DIR}"
: > "${PID_FILE}"

echo "Installing shared backend modules"
mvn -f "${ROOT_DIR}/common/pom.xml" -DskipTests install > "${LOG_DIR}/common-install.log" 2>&1

services=(
  "identity:8101"
  "profile:8102"
  "social:8103"
  "memory:8104"
  "spatial-trails-places:8105"
  "events:8106"
  "notifications:8107"
  "media:8108"
  "presence:8109"
  "safety:8110"
  "engagement:8111"
  "discovery:8112"
  "journeys:8113"
  "messaging:8114"
  "rewards:8115"
  "camera:8116"
)

cleanup() {
  if [[ -f "${PID_FILE}" ]]; then
    while read -r pid; do
      if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
        kill "${pid}" 2>/dev/null || true
      fi
    done < "${PID_FILE}"
  fi
}

trap cleanup EXIT INT TERM

for entry in "${services[@]}"; do
  service="${entry%%:*}"
  port="${entry##*:}"
  log_file="${LOG_DIR}/${service}.log"
  echo "Starting ${service} on http://localhost:${port}"
  (
    cd "${ROOT_DIR}/${service}"
    mvn quarkus:dev
  ) > "${log_file}" 2>&1 &
  echo "$!" >> "${PID_FILE}"
done

echo
echo "Logs are in ${LOG_DIR}"
echo "Press Ctrl+C to stop all services."
wait
