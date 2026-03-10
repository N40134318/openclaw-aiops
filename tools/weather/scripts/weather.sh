#!/usr/bin/env bash
set -euo pipefail

ARG="${1:-}"

BASE_DIR="/home/claw/.openclaw/workspace"
TODAY_SCRIPT="${BASE_DIR}/weather_today.sh"
BY_CITY_SCRIPT="${BASE_DIR}/weather_by_city.sh"
BY_CODE_SCRIPT="${BASE_DIR}/weather_by_code.sh"

# 无参数：默认本地天气
if [ -z "$ARG" ]; then
  exec bash "$TODAY_SCRIPT"
fi

# 纯数字：按城市代码
if printf '%s' "$ARG" | grep -Eq '^[0-9]{6,12}$'; then
  exec bash "$BY_CODE_SCRIPT" "$ARG"
fi

# 其他：按城市名
exec bash "$BY_CITY_SCRIPT" "$ARG"
