# 05 OpenClaw 部署

## 克隆项目

```
git clone https://github.com/openclaw/openclaw.git
```

---

## 构建镜像

```
docker build -t openclaw .
```

如果 VPS 性能较低：

推荐方式：

```
本地 build
↓
push dockerhub
↓
VPS pull
```

---

## 初始化 OpenClaw

```
node dist/index.js setup
```

挂载：

```
~/.openclaw
~/.ssh
```

---

## 服务健康检查

```
curl http://127.0.0.1:18789/healthz
```

---

## 设备配对

```
openclaw devices list
openclaw devices approve <id>
```

