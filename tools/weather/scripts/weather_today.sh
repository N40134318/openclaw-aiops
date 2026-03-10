#!/usr/bin/env bash
set -euo pipefail
curl -s --max-time 5 http://127.0.0.1:8000/weather_today
