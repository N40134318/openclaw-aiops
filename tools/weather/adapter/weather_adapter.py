import json
import re
from datetime import datetime
from zoneinfo import ZoneInfo

import requests
from bs4 import BeautifulSoup
from fastapi import FastAPI, HTTPException

app = FastAPI(title="weather.com.cn weather1d adapter")

BASE_URL = "https://www.weather.com.cn/weather1d/{city_code}.shtml"
SK2D_URL = "http://d1.weather.com.cn/sk_2d/{city_code}.html"

HEADERS = {
    "User-Agent": "Mozilla/5.0",
    "Referer": "https://www.weather.com.cn/",
    "Accept-Language": "zh-CN,zh;q=0.9",
}

SK_HEADERS = {
    "User-Agent": "Mozilla/5.0",
    "Referer": "http://www.weather.com.cn/",
    "Accept-Language": "zh-CN,zh;q=0.9",
}

CITY_CODE_MAP = {
    "瓦房店": "101070202",
    "大连": "101070201",
    "沈阳": "101070101",
    "北京": "101010100",
    "上海": "101020100",
    "天津": "101030100",
    "重庆": "101040100",
    "哈尔滨": "101050101",
    "长春": "101060101",
    "呼和浩特": "101080101",
    "石家庄": "101090101",
    "太原": "101100101",
    "西安": "101110101",
    "济南": "101120101",
    "青岛": "101120201",
    "郑州": "101180101",
    "南京": "101190101",
    "无锡": "101190201",
    "苏州": "101190401",
    "杭州": "101210101",
    "宁波": "101210401",
    "合肥": "101220101",
    "福州": "101230101",
    "厦门": "101230201",
    "南昌": "101240101",
    "武汉": "101200101",
    "长沙": "101250101",
    "广州": "101280101",
    "深圳": "101280601",
    "佛山": "101280800",
    "东莞": "101281601",
    "南宁": "101300101",
    "海口": "101310101",
    "成都": "101270101",
    "贵阳": "101260101",
    "昆明": "101290101",
    "拉萨": "101140101",
    "兰州": "101160101",
    "西宁": "101150101",
    "银川": "101170101",
    "乌鲁木齐": "101130101",
}


def clean_text(s: str) -> str:
    return re.sub(r"\s+", " ", (s or "")).strip()


def text_of(node, default: str = "") -> str:
    return clean_text(node.get_text(" ", strip=True)) if node else default


def parse_temp_value(text: str):
    if not text:
        return None
    m = re.search(r"(-?\d+(?:\.\d+)?)", text)
    if not m:
        return None
    v = float(m.group(1))
    return int(v) if v.is_integer() else v


def guess_city_name(soup: BeautifulSoup) -> str:
    txt = soup.get_text("\n", strip=True)

    patterns = [
        r"全国\s*>\s*[^>\n]+\s*>\s*[^>\n]+\s*>\s*([^>\n\s]+)",
        r"全国\s*>\s*[^>\n]+\s*>\s*([^>\n\s]+)",
    ]
    for p in patterns:
        m = re.search(p, txt)
        if m:
            name = clean_text(m.group(1))
            if name not in {"全国", "中国", "城区"}:
                return name

    title = soup.title.get_text(strip=True) if soup.title else ""
    m_title = re.match(r"([^,，]+?)天气预报", title)
    if m_title:
        name = clean_text(m_title.group(1))
        if name not in {"全国", "中国", "城区"}:
            return name

    return ""


def extract_updated_at(soup: BeautifulSoup) -> str:
    txt = soup.get_text("\n", strip=True)
    m = re.search(r"(\d{1,2}:\d{2})更新", txt)
    if m:
        return m.group(1)
    return ""

def fetch_current_observation_from_sk2d(city_code: str):
    """
    优先使用 weather.com.cn 的实况接口。
    常见返回字段：
    temp, SD, WD, WS, aqi
    """
    url = SK2D_URL.format(city_code=city_code)

    try:
        r = requests.get(url, headers=SK_HEADERS, timeout=8)
        r.raise_for_status()
        r.encoding = "utf-8"

        text = r.text.strip()

        # 常见格式：
        # var dataSK = {...}
        if "=" in text:
            text = text.split("=", 1)[1].strip()

        text = text.rstrip(";").strip()

        data = json.loads(text)

        temp_raw = data.get("temp")
        temp_c = parse_temp_value(str(temp_raw)) if temp_raw not in (None, "") else None

        humidity = clean_text(data.get("SD", ""))
        wd = clean_text(data.get("WD", ""))
        ws = clean_text(data.get("WS", ""))
        wind = clean_text(f"{wd} {ws}")

        aqi = clean_text(str(data.get("aqi", ""))) if data.get("aqi", "") not in (None, "") else ""

        return {
            "temp_c": temp_c,
            "humidity": humidity,
            "wind": wind,
            "air_quality": aqi,
        }
    except Exception:
        return None


def extract_current_observation_from_html(soup: BeautifulSoup):
    """
    HTML 保守兜底：
    只在“实况”卡片内提取，避免误把 today_day / tonight 的温度抓成 current.temp_c。
    """
    temp_c = None
    humidity = ""
    wind = ""
    air_quality = ""

    current_block = None

    for node in soup.select(".today li, .today div, .today section"):
        text = text_of(node)
        if "实况" in text and ("相对湿度" in text or "风" in text):
            current_block = node
            break

    if current_block is None:
        for node in soup.find_all(["div", "section", "li"]):
            text = text_of(node)
            if "实况" in text and ("相对湿度" in text or "风" in text):
                current_block = node
                break

    if current_block is None:
        return {
            "temp_c": None,
            "humidity": "",
            "wind": "",
            "air_quality": "",
        }

    block_text = text_of(current_block)

    m_temp = re.search(r"(-?\d+(?:\.\d+)?)\s*°?\s*C", block_text, re.I)
    if m_temp:
        temp_c = parse_temp_value(m_temp.group(1))
    else:
        candidates = re.findall(r"-?\d+(?:\.\d+)?", block_text)
        if candidates:
            nums = [float(x) for x in candidates]
            plausible = [x for x in nums if -60 <= x <= 60]
            decimal_vals = [x for x in plausible if abs(x - int(x)) > 1e-9]
            if decimal_vals:
                v = decimal_vals[0]
                temp_c = int(v) if float(v).is_integer() else v
            elif plausible:
                v = plausible[0]
                temp_c = int(v) if float(v).is_integer() else v

    m_humidity = re.search(r"相对湿度\s*([0-9]+%)", block_text)
    if m_humidity:
        humidity = m_humidity.group(1)

    m_wind = re.search(r"([东南西北]{1,2}风[,， ]*\d+级)", block_text)
    if m_wind:
        wind = clean_text(m_wind.group(1)).replace(",", " ")

    m_aq = re.search(r"(\d+\s*优)", block_text)
    if m_aq:
        air_quality = clean_text(m_aq.group(1))

    return {
        "temp_c": temp_c,
        "humidity": humidity,
        "wind": wind,
        "air_quality": air_quality,
    }


def extract_current_observation(soup: BeautifulSoup, city_code: str):
    """
    优先走 sk_2d 实况接口；
    失败时回退到 HTML 提取。
    """
    current = fetch_current_observation_from_sk2d(city_code)
    if current is not None:
        return current
    return extract_current_observation_from_html(soup)


def parse_card(card):
    title = text_of(card.select_one("h1"))
    weather = text_of(card.select_one("p.wea"))

    temp_text = text_of(card.select_one("p.tem"))
    temp_c = parse_temp_value(temp_text)

    wind_text = text_of(card.select_one("p.win"))
    wind = ""
    m_wind = re.search(r"(\d-\d级|\d级)", wind_text)
    if m_wind:
        wind = m_wind.group(1)
    else:
        all_text = text_of(card)
        m_wind2 = re.search(r"(\d-\d级|\d级)", all_text)
        if m_wind2:
            wind = m_wind2.group(1)

    sunrise = ""
    sunset = ""
    all_text = text_of(card)

    m_rise = re.search(r"日出\s*([0-2]?\d:\d{2})", all_text)
    if m_rise:
        sunrise = m_rise.group(1)

    m_set = re.search(r"日落\s*([0-2]?\d:\d{2})", all_text)
    if m_set:
        sunset = m_set.group(1)

    return {
        "title": title,
        "weather": weather,
        "temp_c": temp_c,
        "wind": wind,
        "sunrise": sunrise,
        "sunset": sunset,
    }


def parse_title_meta(title: str):
    """
    例如：
    10日白天 -> {"day_num": 10, "phase": "白天"}
    10日夜间 -> {"day_num": 10, "phase": "夜间"}
    """
    title = clean_text(title)
    m = re.search(r"(\d{1,2})日(白天|夜间)", title)
    if not m:
        return {
            "day_num": None,
            "phase": "",
        }
    return {
        "day_num": int(m.group(1)),
        "phase": m.group(2),
    }


def extract_forecast_cards(soup: BeautifulSoup):
    cards = []

    for h1 in soup.select(".today h1"):
        li = h1.find_parent("li")
        if not li:
            continue
        card = parse_card(li)
        meta = parse_title_meta(card["title"])
        card.update(meta)
        cards.append(card)

    dedup = []
    seen = set()
    for c in cards:
        key = (c.get("title"), c.get("weather"), c.get("temp_c"), c.get("wind"))
        if key not in seen:
            seen.add(key)
            dedup.append(c)

    return dedup


def resolve_periods(cards, now=None):
    if now is None:
        now = datetime.now(ZoneInfo("Asia/Shanghai"))

    today_num = now.day
    hour = now.hour

    today_day = None
    tonight = None
    tomorrow_day = None
    tomorrow_night = None

    for c in cards:
        day_num = c.get("day_num")
        phase = c.get("phase")

        if day_num == today_num and phase == "白天":
            today_day = c
        elif day_num == today_num and phase == "夜间":
            tonight = c
        elif day_num is not None and day_num > today_num and phase == "白天":
            if tomorrow_day is None or day_num < tomorrow_day["day_num"]:
                tomorrow_day = c
        elif day_num is not None and day_num > today_num and phase == "夜间":
            if tomorrow_night is None or day_num < tomorrow_night["day_num"]:
                tomorrow_night = c

    # 月末或页面仅两张卡时兜底
    if not today_day:
        for c in cards:
            if c.get("phase") == "白天":
                today_day = c
                break

    if not tonight:
        for c in cards:
            if c.get("phase") == "夜间":
                tonight = c
                break

    # 06:00-17:59 认为白天；18:00-05:59 认为夜间
    if 6 <= hour < 18:
        current_focus = today_day or tonight or tomorrow_day or tomorrow_night
        next_focus = tonight or tomorrow_day or tomorrow_night
    else:
        current_focus = tonight or tomorrow_night or tomorrow_day or today_day
        next_focus = tomorrow_day or tomorrow_night or today_day

    return {
        "today_day": today_day,
        "tonight": tonight,
        "tomorrow_day": tomorrow_day,
        "tomorrow_night": tomorrow_night,
        "current_focus": current_focus,
        "next_focus": next_focus,
    }


def extract_life_indexes(soup: BeautifulSoup):
    txt = soup.get_text("\n", strip=True)
    lines = [clean_text(x) for x in txt.splitlines() if clean_text(x)]

    def pick_index(name_cn: str):
        for i, line in enumerate(lines):
            if name_cn in line:
                level = lines[i - 1] if i - 1 >= 0 else ""
                desc = lines[i + 1] if i + 1 < len(lines) else ""
                return {"level": level, "text": desc}
        return {}

    return {
        "clothing": pick_index("穿衣指数"),
        "sport": pick_index("运动指数"),
        "car_wash": pick_index("洗车指数"),
        "uv": pick_index("紫外线指数"),
    }


def parse_weather1d(city_code: str):
    url = BASE_URL.format(city_code=city_code)

    resp = requests.get(url, headers=HEADERS, timeout=15)
    resp.raise_for_status()
    resp.encoding = "utf-8"

    soup = BeautifulSoup(resp.text, "lxml")

    city_name = guess_city_name(soup)
    updated_at = extract_updated_at(soup)
    current = extract_current_observation(soup, city_code)
    indexes = extract_life_indexes(soup)

    cards = extract_forecast_cards(soup)
    if not cards:
        raise RuntimeError("failed to locate forecast cards")

    periods = resolve_periods(cards)

    return {
        "city_code": city_code,
        "city_name": city_name,
        "updated_at": updated_at,
        "current": current,
        "cards": cards,
        "today_day": periods["today_day"],
        "tonight": periods["tonight"],
        "tomorrow_day": periods["tomorrow_day"],
        "tomorrow_night": periods["tomorrow_night"],
        "current_focus": periods["current_focus"],
        "next_focus": periods["next_focus"],
        "indexes": indexes,
        "source": "weather.com.cn",
        "source_url": url,
    }


def shape_response(raw: dict, fallback_city_name: str = ""):
    city_name = fallback_city_name or raw["city_name"]
    return {
        "city_name": city_name,
        "updated_at": raw["updated_at"],
        "current": raw["current"],
        "today_day": raw.get("today_day"),
        "tonight": raw.get("tonight"),
        "tomorrow_day": raw.get("tomorrow_day"),
        "tomorrow_night": raw.get("tomorrow_night"),
        "current_focus": raw.get("current_focus"),
        "next_focus": raw.get("next_focus"),
        "clothing": raw["indexes"].get("clothing", {}),
        "sport": raw["indexes"].get("sport", {}),
        "car_wash": raw["indexes"].get("car_wash", {}),
        "uv": raw["indexes"].get("uv", {}),
        "source": raw["source"],
        "source_url": raw["source_url"],
    }


@app.get("/")
def root():
    return {
        "ok": True,
        "message": "weather adapter is running",
        "usage": {
            "health": "/health",
            "cities": "/supported_cities",
            "default": "/weather_today",
            "by_city": "/weather_by_city/{city_name}",
            "by_code": "/weather1d/{city_code}",
        },
    }


@app.get("/health")
def health():
    return {
        "ok": True,
        "service": "weather_adapter",
    }


@app.get("/supported_cities")
def supported_cities():
    return {
        "ok": True,
        "data": sorted(CITY_CODE_MAP.keys()),
    }


@app.get("/weather_today")
def get_weather_today():
    try:
        raw = parse_weather1d("101070202")
        return {
            "ok": True,
            "data": shape_response(raw, fallback_city_name="瓦房店"),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/weather1d/{city_code}")
def get_weather1d(city_code: str):
    try:
        raw = parse_weather1d(city_code)
        return {
            "ok": True,
            "data": shape_response(raw),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/weather_by_city/{city_name}")
def get_weather_by_city(city_name: str):
    try:
        city_name = city_name.strip()
        if not city_name:
            raise HTTPException(status_code=400, detail="missing city name")

        city_code = CITY_CODE_MAP.get(city_name)
        if not city_code:
            return {
                "ok": False,
                "error": "unsupported_city",
                "message": f"暂不支持城市：{city_name}",
                "supported_cities": sorted(CITY_CODE_MAP.keys()),
            }

        raw = parse_weather1d(city_code)
        return {
            "ok": True,
            "data": shape_response(raw, fallback_city_name=city_name),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
