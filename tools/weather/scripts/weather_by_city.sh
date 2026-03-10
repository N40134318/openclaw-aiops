#!/usr/bin/env bash
set -euo pipefail

CITY_NAME="${1:-}"
if [ -z "$CITY_NAME" ]; then
  echo '{"ok":false,"error":"missing_city_name","message":"usage: weather_by_city.sh <city_name>"}'
  exit 1
fi

ENCODED_CITY="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$CITY_NAME")"

curl -s --max-time 5 "http://127.0.0.1:8000/weather_by_city/${ENCODED_CITY}"
