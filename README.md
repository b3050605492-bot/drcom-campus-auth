# Dr.COM Campus Auto Login

> A lightweight PowerShell script that automatically detects and logs into Dr.COM-based campus networks. No extra dependencies, runs on any Windows machine.

## How It Works

```
┌─────────────┐     ┌──────────────────┐     ┌────────────┐
│ Check WiFi  │────→│ Detect Captive   │────→│ JSONP      │
│ & IP ready  │     │ Portal (204 err) │     │ Login      │
└─────────────┘     └──────────────────┘     └────────────┘
                                                    │
                                              ┌─────┴─────┐
                                              │  Loop 60s  │
                                              │  keep-alive │
                                              └───────────┘
```

1. **WiFi check** — Optionally verify you're on the right SSID
2. **Network ready** — Wait for valid IP and gateway reachability
3. **Portal detection** — Hit standard captive-portal detection URLs:
   - `gstatic.com/generate_204`
   - `msftconnecttest.com/redirect`
   - Empty response = online; redirect/non-empty = behind portal
4. **Login** — Send a GET request to `/drcom/login` with `DDDDD`/`upass` as JSONP
5. **Keep-alive** — In `-Loop` mode, re-check every 60 seconds

## Usage

```powershell
# Copy config template and fill in your credentials
cp config.example.ps1 config.ps1
# Edit config.ps1 with your info

# One-shot login
.\campus-auto-login.ps1

# Force login even if online
.\campus-auto-login.ps1 -Force

# Daemon mode (infinite loop, checks every 60s)
.\campus-auto-login.ps1 -Loop
```

### Environment Variables (Alternative to Config File)

| Variable       | Description                | Default       |
|----------------|----------------------------|---------------|
| `CAMPUS_SSID`  | WiFi SSID to watch         | *(optional)*  |
| `CAMPUS_USER`  | Your student/employee ID   | *(required)*  |
| `CAMPUS_PASS`  | Your portal password       | *(required)*  |
| `CAMPUS_AUTH`  | Auth server IP             | `172.16.1.2`  |
| `CAMPUS_LOG`   | Log file path              | `$TEMP\campus-login.log` |

### Scheduled Task (Auto-start on Boot)

```powershell
# Run once as admin
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-WindowStyle Hidden -File `"D:\path\to\campus-auto-login.ps1`" -Loop"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "Campus Auto Login" -Action $action -Trigger $trigger -RunLevel Highest
```

## Requirements

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1+ (built-in)
- No external modules or packages required

## Tech Details

- **Auth protocol**: Dr.COM's GET `/drcom/login` endpoint with JSONP callback
- **Detection**: Uses `Invoke-WebRequest` on well-known captive portal detection URLs
- **Resilience**: Retries up to 3 times, waits for network fully ready before attempting

## Why This Exists

Many Chinese university dorm networks run Dr.COM's 802.1x or web portal authentication. The portal randomly drops sessions and the built-in client is unreliable. This script runs silently in the background, re-authenticating as needed.

## License

MIT
