#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8114}"
BASE_URL="${BASE_URL%/}"
OPS_TOKEN="${OPS_TOKEN:-}"
OPS_ACTOR="${OPS_ACTOR:-messaging-ops-smoke}"
REQUEST_ID="${REQUEST_ID:-messaging-smoke-$(date +%s)}"
BATCH_SIZE="${BATCH_SIZE:-25}"

require_command() {
  local command_name="$1"
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 2
  fi
}

require_command curl
require_command jq

COMMON_HEADERS=(
  -H "Accept: application/json"
  -H "Content-Type: application/json"
  -H "X-Request-Id: ${REQUEST_ID}"
)

OPS_HEADERS=(
  -H "Accept: application/json"
  -H "Content-Type: application/json"
  -H "X-Request-Id: ${REQUEST_ID}"
  -H "X-Jezaku-Ops-Actor: ${OPS_ACTOR}"
)

if [[ -n "${OPS_TOKEN}" ]]; then
  OPS_HEADERS+=(-H "X-Jezaku-Ops-Token: ${OPS_TOKEN}")
fi

api_get() {
  local path="$1"
  curl -fsS "${COMMON_HEADERS[@]}" "${BASE_URL}${path}"
}

api_post() {
  local path="$1"
  local body="$2"
  curl -fsS -X POST "${COMMON_HEADERS[@]}" -d "${body}" "${BASE_URL}${path}"
}

ops_get() {
  local path="$1"
  curl -fsS "${OPS_HEADERS[@]}" "${BASE_URL}${path}"
}

ops_post() {
  local path="$1"
  local body="$2"
  curl -fsS -X POST "${OPS_HEADERS[@]}" -d "${body}" "${BASE_URL}${path}"
}

extract_required() {
  local json="$1"
  local expression="$2"
  local label="$3"
  local value
  value="$(jq -r "${expression} // empty" <<<"${json}")"
  if [[ -z "${value}" ]]; then
    echo "Could not read ${label} from response:" >&2
    jq . <<<"${json}" >&2
    exit 1
  fi
  printf '%s' "${value}"
}

suffix="$(date +%s)-${RANDOM}"
sender_id="smoke_sender_${suffix}"
recipient_id="smoke_recipient_${suffix}"
message_body="Messaging ops smoke ${suffix}"

echo "Messaging ops smoke"
echo "Base URL: ${BASE_URL}"
echo "Request ID: ${REQUEST_ID}"

echo "Checking readiness..."
if ! curl -fsS "${BASE_URL}/q/health/ready" >/dev/null; then
  echo "Messaging service is not ready at ${BASE_URL}." >&2
  echo "Start it first, for example: mvn -f Backend/pom.xml -pl messaging -am quarkus:dev" >&2
  exit 1
fi

thread_request="$(
  jq -n \
    --arg creatorId "${sender_id}" \
    --arg participantId "${recipient_id}" \
    '{creatorId: $creatorId, threadType: "direct", participantIds: [$participantId]}'
)"
thread_response="$(api_post "/messaging/threads" "${thread_request}")"
thread_id="$(extract_required "${thread_response}" ".threadId" "threadId")"
echo "Created direct thread: ${thread_id}"

message_request="$(
  jq -n \
    --arg senderId "${sender_id}" \
    --arg body "${message_body}" \
    '{senderId: $senderId, body: $body}'
)"
message_response="$(api_post "/messaging/threads/${thread_id}/messages" "${message_request}")"
message_id="$(extract_required "${message_response}" ".messageId" "messageId")"
echo "Sent message: ${message_id}"

drain_response="$(ops_post "/messaging/ops/pipeline/drain?batchSize=${BATCH_SIZE}" "{}")"
outbox_dispatched="$(extract_required "${drain_response}" ".outboxDispatched" "outboxDispatched")"
fanout_delivered="$(extract_required "${drain_response}" ".fanoutDelivered" "fanoutDelivered")"
echo "Drained pipeline: outbox=${outbox_dispatched}, realtime=${fanout_delivered}"

events_response="$(api_get "/messaging/realtime/users/${recipient_id}/events?limit=10")"
event_count="$(jq -r ".count // 0" <<<"${events_response}")"
if (( event_count < 1 )); then
  echo "Expected at least one realtime event for ${recipient_id}, got ${event_count}" >&2
  jq . <<<"${events_response}" >&2
  exit 1
fi

delivery_ids="$(jq -c "[.events[].deliveryId]" <<<"${events_response}")"
ack_request="$(jq -n --argjson deliveryIds "${delivery_ids}" '{deliveryIds: $deliveryIds}')"
ack_response="$(api_post "/messaging/realtime/users/${recipient_id}/ack" "${ack_request}")"
acknowledged_count="$(extract_required "${ack_response}" ".acknowledgedCount" "acknowledgedCount")"
echo "Acknowledged realtime deliveries: ${acknowledged_count}"

status_response="$(ops_get "/messaging/ops/pipeline/status")"
audit_summary="$(ops_get "/messaging/ops/audit/summary?action=pipeline.drain")"
drain_audit_count="$(jq -r '[.byAction[]? | select(.key == "pipeline.drain") | .count][0] // 0' <<<"${audit_summary}")"

echo "Smoke summary:"
jq -n \
  --arg threadId "${thread_id}" \
  --arg messageId "${message_id}" \
  --arg recipientId "${recipient_id}" \
  --argjson realtimeEvents "${event_count}" \
  --argjson acknowledged "${acknowledged_count}" \
  --argjson outboxDispatched "${outbox_dispatched}" \
  --argjson fanoutDelivered "${fanout_delivered}" \
  --argjson pendingOutbox "$(jq -r '.outboxPending // 0' <<<"${status_response}")" \
  --argjson pendingFanout "$(jq -r '.fanoutQueued // 0' <<<"${status_response}")" \
  --argjson drainAuditCount "${drain_audit_count}" \
  '{
    threadId: $threadId,
    messageId: $messageId,
    recipientId: $recipientId,
    realtimeEvents: $realtimeEvents,
    acknowledged: $acknowledged,
    outboxDispatched: $outboxDispatched,
    fanoutDelivered: $fanoutDelivered,
    pendingOutbox: $pendingOutbox,
    pendingFanout: $pendingFanout,
    drainAuditCount: $drainAuditCount
  }'
