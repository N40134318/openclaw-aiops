#!/usr/bin/env bash
set -euo pipefail

CITY_CODE="${1:-101070202}"
curl -s "http://127.0.0.1:8000/weather1d/${CITY_CODE}"

