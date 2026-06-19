# 九江科技职业大学校园网认证

> 轻量级 PowerShell 脚本，自动检测并登录 Dr.COM 校园网。零依赖，任何 Windows 电脑都能跑。

## 背景

九江科技职业大学的校园网（Dr.COM）会不定期断链，官方客户端又不稳定。写了个脚本挂在后台，每 60 秒检测一次，发现掉线就自动重新认证。

## 工作原理

```
┌──────────────┐    ┌──────────────────┐    ┌────────────┐
│ 检测 WiFi    │───→│ 检测是否被 Portal  │───→│ JSONP 登录 │
│ 等网络就绪    │    │ 劫持（204 检测）   │    │            │
└──────────────┘    └──────────────────┘    └────────────┘
                                                    │
                                              ┌─────┴─────┐
                                              │ 每 60 秒   │
                                              │ 循环保活    │
                                              └───────────┘
```

1. **WiFi 检测** — 可选，确认连的是校园网 SSID
2. **等待网络就绪** — 等到拿到有效 IP、能 ping 通认证服务器
3. **Portal 检测** — 访问几个标准检测 URL：
   - `gstatic.com/generate_204`
   - `msftconnecttest.com/redirect`
   - 返回空内容 = 已联网；重定向或非空 = 被 Portal 墙挡住了
4. **发送登录** — 向 `/drcom/login` 发 GET 请求，携带 `DDDDD`/`upass`，走 JSONP 格式
5. **循环保活** — `-Loop` 模式每 60 秒重跑一轮，断了自动重登

## 使用方法

```powershell
# 复制配置模板并填写你的账号密码
cp config.example.ps1 config.ps1
# 编辑 config.ps1 填入真实信息

# 一次性登录
.\campus-auto-login.ps1

# 强制登录（即使已在线）
.\campus-auto-login.ps1 -Force

# 守护模式（无限循环，每 60s 检测一次）
.\campus-auto-login.ps1 -Loop
```

### 环境变量（不用配置文件也行）

| 变量           | 说明            | 默认值        |
|----------------|----------------|---------------|
| `CAMPUS_SSID`  | WiFi SSID      | *（可选）*    |
| `CAMPUS_USER`  | 学号 / 工号     | *（必填）*    |
| `CAMPUS_PASS`  | 登录密码         | *（必填）*    |
| `CAMPUS_AUTH`  | 认证服务器 IP    | `172.16.1.2` |
| `CAMPUS_LOG`   | 日志文件路径      | `$TEMP\campus-login.log` |

### 开机自启（任务计划程序）

```powershell
# 管理员身份运行一次
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-WindowStyle Hidden -File `"D:\path\to\campus-auto-login.ps1`" -Loop"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "Campus Auto Login" -Action $action -Trigger $trigger -RunLevel Highest
```

## 运行环境

- Windows 10/11 或 Windows Server 2016+
- PowerShell 5.1+（系统自带）
- 不需要装任何额外模块或包

## 技术细节

- **认证协议**：Dr.COM 的 GET `/drcom/login` 接口，JSONP callback 格式
- **断网检测**：用 `Invoke-WebRequest` 访问标准 captive portal 检测 URL，判断是否被劫持
- **容错**：最多重试 3 次，等网络完全就绪才发登录请求

## 许可证

MIT
