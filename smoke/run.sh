#!/usr/bin/env bash
# Runs INSIDE the built image. Boots the backported PHP's built-in server,
# does a session round-trip and a real multipart upload, asserts the verdict.
set -euo pipefail
PHP=/opt/php/bin/php
WWW=/smoke/www
PORT=8099
COOKIES=/tmp/smoke_cookies

echo "php: $($PHP -v | head -1)"

"$PHP" -d error_reporting=E_ALL -d display_errors=1 -S 127.0.0.1:$PORT -t "$WWW" >/tmp/smoke_server.log 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null || true' EXIT
# Wait for the server to accept connections.
for i in $(seq 1 30); do curl -fsS "http://127.0.0.1:$PORT/" -o /dev/null 2>/dev/null && break; sleep 0.3; done

# Make a payload file with known size.
PAYLOAD=/tmp/smoke_payload.bin
head -c 65536 /dev/urandom > "$PAYLOAD"
SIZE=$(wc -c < "$PAYLOAD" | tr -d ' ')

# Request 1: GET, establishes a session.
R1=$(curl -fsS -c "$COOKIES" "http://127.0.0.1:$PORT/")
# Request 2: POST the file on the same session.
R2=$(curl -fsS -b "$COOKIES" -c "$COOKIES" -F "f=@${PAYLOAD}" "http://127.0.0.1:$PORT/")

echo "GET  -> $R1"
echo "POST -> $R2"

# Assert with the backported php itself (no jq dependency).
"$PHP" -r '
  $r = json_decode($argv[1], true);
  $size = (int)$argv[2];
  if (!$r) { fwrite(STDERR, "no json\n"); exit(2); }
  $c = $r["checks"];
  $fail = [];
  if (!$r["ok"]) $fail[] = "ok=false";
  if (empty($c["session_id_present"])) $fail[] = "no session id";
  if (($c["session_counter"] ?? 0) < 2) $fail[] = "session not persisted (counter=".($c["session_counter"]??0).")";
  if (empty($c["upload_received"])) $fail[] = "upload not received";
  if (empty($c["upload_moved"])) $fail[] = "upload not moved";
  if (($c["upload_bytes_on_disk"] ?? -1) !== $size) $fail[] = "upload size mismatch (".($c["upload_bytes_on_disk"]??-1)." vs $size)";
  if ($fail) { fwrite(STDERR, "SMOKE FAIL: ".implode("; ", $fail)."\n"); exit(1); }
  fwrite(STDOUT, "SMOKE PASS: session persisted (hits=".$c["session_counter"]."), upload ".$size." bytes received+moved, upload_progress_keys=".$c["upload_progress_keys"]."\n");
' "$R2" "$SIZE"
