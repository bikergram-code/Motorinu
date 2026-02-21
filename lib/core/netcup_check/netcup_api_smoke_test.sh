#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://www.bikergram.de/api"

echo "== Bikergram API Smoke Test =="
echo "BASE_URL: ${BASE_URL}"

echo
echo "[1/5] Draft start..."
START_JSON=$(curl -sS -X POST "${BASE_URL}/profile/draft/start" \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  --data '{"deviceId":"local-smoke-test"}')

echo "Response: ${START_JSON}"
DRAFT_ID=$(echo "$START_JSON" | sed -n 's/.*"\(draftId\|id\)"[ ]*:[ ]*"\([^"]\+\)".*/\2/p' | head -n 1)

if [[ -z "${DRAFT_ID}" ]]; then
  echo "ERROR: Kein draftId/id im Response gefunden."
  echo "-> Prüfe Backend-Response-Format (draftId oder id)."
  exit 1
fi

echo "draftId = ${DRAFT_ID}"

echo
echo "[2/5] Save step 1 (name) ..."
curl -sS -X PATCH "${BASE_URL}/profile/draft/${DRAFT_ID}/step/1" \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  --data '{"data":{"name":"SmokeTester"},"markCompleted":true}' | head -c 500; echo

echo
echo "[3/5] Load draft ..."
curl -sS -X GET "${BASE_URL}/profile/draft/${DRAFT_ID}" \
  -H "Accept: application/json" | head -c 500; echo

echo
echo "[4/5] Upload profile image (optional) ..."
TMP_IMG=$(mktemp)
# 1x1 png
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\x0cIDAT\x08\xd7c\xf8\xff\xff?\x00\x05\xfe\x02\xfe\xa7\x8d\xa4\x81\x00\x00\x00\x00IEND\xaeB`\x82' > "$TMP_IMG"

set +e
curl -sS -X POST "${BASE_URL}/upload/profile-image" \
  -H "Accept: application/json" \
  -F "file=@${TMP_IMG};filename=smoke.png" | head -c 500; echo
UPLOAD_RC=$?
set -e

rm -f "$TMP_IMG"
if [[ $UPLOAD_RC -ne 0 ]]; then
  echo "WARN: Upload endpoint nicht erreichbar/fehlgeschlagen. (Kann ok sein, wenn du Upload anders machst.)"
fi

echo
echo "[5/5] Submit draft ..."
curl -sS -X POST "${BASE_URL}/profile/draft/${DRAFT_ID}/submit" \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  --data '{}' | head -c 800; echo

echo
echo "DONE. Wenn alle Calls 200/OK liefern, ist Backend bereit."
