# RegMachine Go

`registerTool`（Flask）的 Go 移植版：Web 注册码生成器 + JSON API，配置通过 `.env` 本地化。

## 快速开始

```powershell
cd E:\BB_pro\gitHub\go_http
copy .env.example .env
go mod tidy
go run .
```

或用脚本（Git Bash / Linux / macOS，公共函数在 `common/base.sh`）：

```bash
./1Build.sh              # 编译
./1Build.sh windows      # 交叉编译 Windows
./1Build.sh linux        # 交叉编译 Linux
./1Build.sh --clean
./start.sh               # 后台启动
./start.sh --kill        # 端口占用时先杀旧进程
./start.sh --fg          # 前台启动
./stop.sh                # 停止
./stop.sh --force        # 按端口强制清理
```

打开：http://localhost:9212（端口以 `.env` 中 `APP_PORT` 为准）

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `APP_HOST` | `0.0.0.0` | 监听地址 |
| `APP_PORT` | `9212` | 监听端口 |
| `REGISTER_KEY` | 空 | 内置 8 字节 DES 密钥 |
| `DEFAULT_SN` | 空 | 页面注册码默认值 |

## API

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/api` | 接口说明 |
| `GET` | `/api/health` | 健康检查 |
| `POST` | `/api/register-code` | 生成激活码 |
| `POST` | `/api/machine-md5` | 机器码 MD5 |
| `POST` | `/api/generate` | 组合生成 |

```powershell
$body = @{ sn = "your-sn" } | ConvertTo-Json
Invoke-RestMethod -Uri http://127.0.0.1:9212/api/register-code -Method Post -ContentType "application/json" -Body $body
```

## 目录

```text
go_http/
├── 1Build.sh              # 编译
├── start.sh               # 启动
├── stop.sh                # 停止
├── common/base.sh         # 多平台公共函数（OS 探测、后缀、端口/PID）
├── main.go
├── config/                # .env / 环境变量
├── service/               # DES/XDES + MD5
├── api/                   # /api 路由
├── templates/             # Web 页面
└── static/                # css / js
```

算法与 Python 版一致：DES/ECB、Latin-1、0x00 补齐、小写 hex 激活码。
