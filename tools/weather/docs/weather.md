# OpenClaw Weather Module 技术文档

## 1. 项目目标

在 OpenClaw Agent 中实现一个 **稳定、可控的天气查询工具**。

要求：

- Agent 不直接访问天气网站
    
- 所有请求通过 **本地脚本 + Adapter**
    
- 返回 **结构化 JSON**
    
- 支持自然语言查询
    

示例：

```
北京天气怎么样
今晚天气怎么样
今天适合洗车吗
101010100 的天气
看看当前实况天气
```

---

# 2. 系统架构

整体架构：

```
User
  ↓
OpenClaw Agent
  ↓
TOOLS.md
  ↓
vm-run
  ↓
weather.sh
  ↓
weather_adapter (FastAPI)
  ↓
weather.com.cn
```

模块职责：

|模块|作用|
|---|---|
|Agent|理解自然语言|
|TOOLS.md|决定调用哪个脚本|
|weather.sh|统一天气入口|
|vm-run|容器安全执行宿主机命令|
|weather_adapter|抓取并解析天气数据|
|weather.com.cn|天气数据源|

---

# 3. Adapter 服务

使用：

```
FastAPI
requests
BeautifulSoup
```

启动方式：

```
python3 -m uvicorn weather_adapter:app --host 0.0.0.0 --port 8000
```

服务地址：

```
http://127.0.0.1:8000
```

---

# 4. API接口

## 4.1 Health

```
GET /health
```

返回：

```json
{
  "ok": true,
  "service": "weather_adapter"
}
```

---

## 4.2 支持城市

```
GET /supported_cities
```

返回：

```json
{
  "ok": true,
  "data": [
    "北京",
    "上海",
    "广州",
    "瓦房店"
  ]
}
```

---

## 4.3 默认城市天气

```
GET /weather_today
```

默认城市：

```
瓦房店
```

---

## 4.4 城市名称查询

```
GET /weather_by_city/{city}
```

示例：

```
/weather_by_city/北京
```

---

## 4.5 城市代码查询

```
GET /weather1d/{city_code}
```

示例：

```
/weather1d/101010100
```

---

# 5. 返回数据结构

示例：

```json
{
  "city_name": "北京",
  "updated_at": "11:30",
  "current": {
    "temp_c": 9.3,
    "humidity": "35%",
    "wind": "东北风 1级",
    "air_quality": "101"
  },
  "today_day": {
    "weather": "多云",
    "temp_c": 11
  },
  "tonight": {
    "weather": "晴",
    "temp_c": 2
  },
  "clothing": {},
  "sport": {},
  "car_wash": {},
  "uv": {},
  "source": "weather.com.cn"
}
```

---

# 6. 天气解析逻辑

网页结构包含两个主要卡片：

```
今日白天
今日夜间
```

解析字段：

```
title
weather
temp_c
wind
sunrise
sunset
```

同时解析：

```
day_num
phase
```

---

# 7. 时段智能判断

根据当前时间：

```
06:00 - 17:59  → 白天
18:00 - 05:59  → 夜间
```

生成：

```
current_focus
next_focus
```

---

# 8. 实况天气

解析页面 **实况模块**：

包含：

```
温度
湿度
风向
空气质量
```

返回：

```json
"current": {
  "temp_c": 8.9,
  "humidity": "26%",
  "wind": "南风 3级",
  "air_quality": "26"
}
```

---

# 9. 城市支持

通过：

```
CITY_CODE_MAP
```

管理城市。

示例：

```
北京 101010100
上海 101020100
广州 101280101
瓦房店 101070202
```

---

# 10. 脚本层

宿主机脚本：

```
weather.sh
weather_by_city.sh
weather_by_code.sh
```

示例：

```
bash weather.sh
bash weather.sh 北京
bash weather.sh 101010100
```

---

# 11. 容器调用

Docker Gateway 调用方式：

```
vm-run exec "bash /home/claw/.openclaw/workspace/weather.sh 北京"
```

示例：

```
sh /home/node/.openclaw/workspace/vm-run exec "bash weather.sh 北京"
```

---

# 12. Agent 工具规则

TOOLS.md 中定义：

- 天气问题 → 使用 weather helper script
    
- 禁止访问 wttr.in
    
- 禁止直接调用外部 API
    

Agent 输出必须基于：

```
weather_adapter JSON
```

---

# 13. Agent 输出模板

示例：

```
北京天气：

10日白天：多云，11℃
10日夜间：晴，2℃

穿衣：较冷
运动：较适宜
洗车：适宜
紫外线：强
```

---

# 14. 测试

命令：

```
curl http://127.0.0.1:8000/weather_today
```

```
curl http://127.0.0.1:8000/weather_by_city/北京
```

```
curl http://127.0.0.1:8000/weather1d/101010100
```

日志：

```
tail -f ~/.openclaw/workspace/weather.log
```

---

# 15. 已实现功能

支持：

```
当前实况天气
今日白天
今日夜间
城市名查询
城市代码查询
默认城市
生活指数
洗车建议
Agent 自动调用工具
```

---

# 16. 稳定性

系统具备：

```
结构化 JSON
解析回退机制
不支持城市提示
容器安全执行
```

版本：

```
Weather Tool v1.0
```

---

# 17. 未来扩展

建议升级：

```
7天天气
自动城市识别
AQI等级解释
全球城市支持
```

---

# 18. 结论

OpenClaw Weather Module 已实现：

```
稳定天气查询
本地工具控制
结构化天气数据
Agent 自动调用
```

天气模块开发完成。

---

# AGENTS.md新增天气模块部分

```md
## Using local tools

When a request can be answered by a local workspace tool, prefer that tool over guessing or using unrelated external services.

For weather, system status, docker status, or other host-related information:
- Prefer local tools described in TOOLS.md
- Use returned structured data directly
- Do not invent missing values
- If the tool fails, say so plainly

## Weather behavior

When a user asks about weather:

1. Prefer using local weather helper scripts described in `TOOLS.md`.
2. Prefer the unified weather entry script when available.
3. Use structured JSON returned by the weather helper directly.
4. Do not guess weather or fabricate values.
5. If the helper script runs on the host, execute it through `vm-run`.

Examples of weather questions:

- 某地天气
- 北京天气
- 上海天气
- 今晚天气
- 明天白天天气
- 温度
- 风力
- 日出 / 日落
- 穿衣建议
- 运动建议
- 洗车建议
- 紫外线建议

### Tool selection

Before answering weather questions:

1. Check `TOOLS.md` for the available weather helper scripts.
2. Use the preferred unified entry script if available.
3. If the user provides a city name, pass it as the script argument.
4. If the user provides a city code, pass it as the script argument.
5. If no location is provided, use the default local weather context.
6. Use the returned structured output directly when constructing the answer.

### Failure handling

If the weather helper script fails or returns invalid data, respond exactly:

暂时无法获取实时天气数据。

### Weather response rules

For weather questions:

- Always answer in Chinese.
- Do not output internal reasoning such as “I'll check...” or “Looking at the previous results...”.
- Do not mention unrelated default locations such as Shanghai unless the tool result explicitly says so.
- If the user does not specify a location, use the default local weather context returned by the local weather script.
- If a requested forecast block is missing (for example `tomorrow_day` is null), say so briefly in Chinese and do not add speculation.
- Keep the response concise and directly based on the returned weather fields.

```

# TOOLS.md新增天气模块部分

```md
---

## Weather Helper Scripts

### Purpose

Use local weather helper scripts to obtain structured weather data.

Prefer local scripts over ad-hoc weather lookups or unrelated public weather services.

---

### Script location

Weather helper scripts usually live in the host workspace:

/home/claw/.openclaw/workspace/

If a script is host-side, execute it through the container wrapper.

---

### Required execution method

Inside the container environment, do **not** run host-side weather scripts directly.

Always use:

sh /home/node/.openclaw/workspace/vm-run exec "bash <host_script> [args]"

Examples:

sh /home/node/.openclaw/workspace/vm-run exec "bash /home/claw/.openclaw/workspace/weather.sh"

sh /home/node/.openclaw/workspace/vm-run exec "bash /home/claw/.openclaw/workspace/weather.sh 北京"

sh /home/node/.openclaw/workspace/vm-run exec "bash /home/claw/.openclaw/workspace/weather.sh 101010100"

---

### When to use

Use a weather helper script when the user asks about:

- 某地天气
- 今晚天气
- 明天白天天气
- 温度
- 风力
- 日出 / 日落
- 穿衣建议
- 运动建议
- 洗车建议
- 紫外线建议

---

### Script selection guidance

Choose the weather script that best matches the request:

- Use `weather.sh` as the preferred unified entry.
- Use `weather.sh` with no argument for the default local weather context.
- Use `weather.sh <city_name>` when the user gives a city name.
- Use `weather.sh <city_code>` when the user gives a city code directly.
- If needed, the underlying helper scripts may still be used directly.
- Prefer the most specific existing script instead of inventing a new command flow.

---

### Structured output

Weather helper scripts should return **JSON**.

Typical fields may include:

- city_name
- updated_at
- current
- tonight
- tomorrow_day
- clothing
- sport
- car_wash
- uv

Different scripts may return different fields.  
Use the available fields directly.

---

### Answering rules

After running a weather script:

1. Read the returned JSON.
2. Use returned values directly.
3. Do not invent missing values.
4. Do not replace numeric values with estimates.
5. Do not mix fields from different forecast sections.
6. Preserve exact weather conditions and temperatures.

---

### Suggested answer format

某地天气：

- 今晚：{tonight.weather}，{tonight.temp_c}℃，{tonight.wind}，日落 {tonight.sunset}
- 明天白天：{tomorrow_day.weather}，{tomorrow_day.temp_c}℃，{tomorrow_day.wind}，日出 {tomorrow_day.sunrise}

Optional:

- 穿衣：{clothing.level}，{clothing.text}
- 运动：{sport.level}，{sport.text}
- 洗车：{car_wash.level}，{car_wash.text}
- 紫外线：{uv.level}，{uv.text}

Adjust wording to match the returned fields.

---

### Current known weather scripts

Currently available scripts:

- /home/claw/.openclaw/workspace/weather.sh
- /home/claw/.openclaw/workspace/weather_today.sh
- /home/claw/.openclaw/workspace/weather_by_city.sh <city_name>
- /home/claw/.openclaw/workspace/weather_by_code.sh <city_code>

Preferred unified entry:

- /home/claw/.openclaw/workspace/weather.sh

Examples:

sh /home/node/.openclaw/workspace/vm-run exec "bash /home/claw/.openclaw/workspace/weather.sh"

sh /home/node/.openclaw/workspace/vm-run exec "bash /home/claw/.openclaw/workspace/weather.sh 北京"

sh /home/node/.openclaw/workspace/vm-run exec "bash /home/claw/.openclaw/workspace/weather.sh 101010100"

---

### Selection examples

Examples:

- “今天天气怎么样” → use `weather.sh`
- “北京天气怎么样” → use `weather.sh 北京`
- “101010100 的天气” → use `weather.sh 101010100`

If multiple scripts could work, prefer the one that matches the user's input most directly.

---

### Forbidden behavior

Do not use:

- wttr.in
- unrelated public weather services when a local helper exists
- self-constructed weather curl commands if a helper script is available
- guessed weather values
- trend prediction not present in the returned data

---

### Failure handling

If the weather script fails or returns invalid data, answer exactly:

暂时无法获取实时天气数据。

If a weather helper returns `ok: false` with `unsupported_city`,
report that the city is not currently supported instead of guessing.
```

之后与claw在webui对话让它把天气模块的使用方法写入长期记忆的文件中。
