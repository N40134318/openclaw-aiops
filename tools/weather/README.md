
# Weather Module

OpenClaw-AIOps 的天气工具模块，为 Agent 提供本地天气查询能力。

该模块通过 **宿主机脚本 + Adapter 服务** 抓取 `weather.com.cn` 数据，并返回结构化 JSON，供 Agent 使用。

---

# 功能

当前支持：

### 实况天气

- 当前温度
- 相对湿度
- 风向风力
- 空气质量

### 天气预报

- 今日白天
- 今晚
- 自动白天/夜间识别

### 生活指数

- 穿衣建议
- 运动建议
- 洗车建议
- 紫外线指数

### 查询方式

支持：

- 默认城市查询
- 城市名称查询
- 城市代码查询

---

# 模块架构

```

Agent (container)  
│  
│ vm-run  
▼  
weather.sh (host)  
│  
▼  
weather_adapter.py (FastAPI)  
│  
▼  
weather.com.cn

```

说明：

Agent 不直接访问互联网天气服务，而是：

1. 调用宿主机脚本
2. 脚本访问 adapter
3. adapter 抓取 weather.com.cn
4. 返回结构化 JSON

---

# 项目结构

```

tools/weather/

├── README.md

├── adapter/  
│ └── weather_adapter.py  
│  
├── scripts/  
│ ├── weather.sh  
│ ├── weather_today.sh  
│ ├── weather_by_city.sh  
│ └── weather_by_code.sh  
│  
└── docs/  
└── weather.md

```

说明：

| 目录      | 作用      |
| ------- | ------- |
| adapter | 天气解析服务  |
| scripts | 宿主机调用脚本 |
| docs    | 模块技术文档  |

---

# 使用方法

### 默认天气

```

bash tools/weather/scripts/weather.sh

```

返回默认城市天气。

---

### 城市名称查询

```

bash tools/weather/scripts/weather.sh 北京

```

---

### 城市代码查询

```

bash tools/weather/scripts/weather.sh 101010100

````

---

# 返回 JSON 示例

```json
{
  "ok": true,
  "data": {
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
      "temp_c": 11,
      "wind": "3级",
      "sunrise": "06:34"
    },
    "tonight": {
      "weather": "晴",
      "temp_c": 2,
      "wind": "3级",
      "sunset": "18:15"
    },
    "clothing": {
      "level": "较冷",
      "text": "建议着厚外套加毛衣等服装。"
    }
  }
}
````

说明：

`current` 为 **实时天气**

`today_day` 为 **今日白天**

`tonight` 为 **今日夜间**

---

# Agent 调用规范

当用户询问天气相关问题时：

```
优先使用本地 weather.sh
不要直接调用外部天气 API
不要构造 curl 抓取天气网页
必须使用返回 JSON 数据回答
```

例如：

用户：

```
北京天气怎么样
```

Agent 执行：

```
weather.sh 北京
```

---

# 支持的城市

可通过接口查看：

```
/supported_cities
```

当前支持中国主要城市，例如：

```
北京
上海
广州
深圳
成都
杭州
武汉
西安
瓦房店
...
```

---

# 数据来源

```
weather.com.cn
```

本模块仅作为解析适配器，不提供天气数据本身。

---

# 技术文档

模块完整技术文档：

```
tools/weather/docs/weather.md
```

包含：

- Adapter 设计
    
- 页面解析逻辑
    
- 白天夜间 UI 差异
    
- 实况天气提取规则
    
- JSON 输出结构
    

---

# 扩展规划

未来可能增加：

### 更多天气数据

- 7 天天气
    
- 15 天天气
    
- 小时级天气
    

### 国际城市支持

支持全球城市天气。

### 缓存机制

减少频繁抓取天气站点。

### 多天气源

支持多个天气数据源。

---

# 注意事项

1. 当前版本只支持中国城市
    
2. 城市名称需使用中文
    
3. 天气数据来自 weather.com.cn
    
4. 页面结构变化可能需要更新解析逻辑

