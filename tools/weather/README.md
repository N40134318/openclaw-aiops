# Weather Tool

本模块为 OpenClaw AI Ops 提供本地天气能力。

## 组成

- adapter/weather_adapter.py
- scripts/weather.sh
- scripts/weather_today.sh
- scripts/weather_by_city.sh
- scripts/weather_by_code.sh

## 调用链

Agent -> vm-run -> host script -> weather_adapter -> weather.com.cn

## 常用测试

bash tools/weather/scripts/weather.sh
bash tools/weather/scripts/weather.sh 北京
bash tools/weather/scripts/weather.sh 101010100
