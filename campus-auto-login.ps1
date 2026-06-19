# Dr.COM Campus Auto Login
# Auto-detect captive portal → JSONP login → keep-alive loop
# Works with most Dr.COM-based campus networks (China)
#
# Usage:
#   .\campus-auto-login.ps1 -Loop              # daemon mode (60s interval)
#   .\campus-auto-login.ps1 -Force              # one-shot forced login
#
# Config via environment variables (or config.example.ps1):
#   CAMPUS_SSID     WiFi SSID to watch (optional, skips check if empty)
#   CAMPUS_USER     Your student/employee account
#   CAMPUS_PASS     Your password
#   CAMPUS_AUTH     Auth server IP (default 172.16.1.2)

param([switch]$Force, [switch]$Loop)

# ── Config ────────────────────────────────────────────────────────
$CfgFile = Join-Path $PSScriptRoot 'config.ps1'
if (Test-Path $CfgFile) { . $CfgFile }

$SSID    = $env:CAMPUS_SSID
$User    = $env:CAMPUS_USER
$Pass    = $env:CAMPUS_PASS
$AuthSvr = $env:CAMPUS_AUTH
if (-not $AuthSvr) { $AuthSvr = '172.16.1.2' }

$LogFile = $env:CAMPUS_LOG
if (-not $LogFile) { $LogFile = "$env:TEMP\campus-login.log" }

# ── Helpers ──────────────────────────────────────────────────────
function log($m) {
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$ts $m" | Out-File $LogFile -Append -Encoding utf8
    Write-Host "$ts $m"
}

# ── Login Logic ──────────────────────────────────────────────────
function Do-Login {
    param([bool]$force)

    log '========== START =========='

    # 1. Check credentials
    if (-not $User -or -not $Pass) {
        log 'ERROR: CAMPUS_USER and CAMPUS_PASS not set'
        return
    }

    # 2. WiFi check (optional)
    if ($SSID) {
        $w = (netsh wlan show interfaces | Select-String 'SSID|BSSID' | Out-String).Trim()
        if ($w -notmatch $SSID) { log "Not on SSID: $SSID"; return }
        log "WiFi: $SSID"
    }

    # 3. Wait for network
    log 'Waiting for network...'
    for ($i = 0; $i -lt 20; $i++) {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias '*Wi*' -ErrorAction SilentlyContinue |
            Where-Object { $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1)
        if ($ip -and $ip.IPAddress -ne '0.0.0.0') {
            log "IP: $($ip.IPAddress)"
            Start-Sleep 3
            try { if (Test-Connection $AuthSvr -Count 1 -Quiet) { break } } catch {}
        }
        Start-Sleep 2
    }

    # 4. Captive portal detection
    $needLogin = $force
    $testUrls = @(
        'http://www.gstatic.com/generate_204',
        'http://connectivitycheck.gstatic.com/generate_204',
        'http://www.msftconnecttest.com/redirect'
    )
    foreach ($pu in $testUrls) {
        try {
            $r = Invoke-WebRequest $pu -TimeoutSec 5 -UseBasicParsing -MaximumRedirection 0
            $len = $r.Content.Length
            if ($len -lt 100) {
                log "Internet OK ($($pu.Split('/')[2]), ${len}B)"
                break
            }
            log "Non-empty from $($pu.Split('/')[2]): ${len}B → portal"
            $needLogin = $true
        } catch {
            if ($_.Exception.Response.StatusCode -eq 302 -or
                $_.Exception.Response.Headers['Location']) {
                log 'Redirect → portal'
                $needLogin = $true
            } elseif ($_.Exception.Message -match 'timed out|unable|forcibly') {
                log "Net error: $($_.Exception.Message)"
                $needLogin = $true
            }
        }
        if ($needLogin) { break }
    }
    if (-not $needLogin) { log 'No portal detected, online'; return }

    log 'Behind portal, sending login...'

    # 5. Login via JSONP
    $maxRetry = 3
    for ($attempt = 1; $attempt -le $maxRetry; $attempt++) {
        log "Login attempt $attempt / $maxRetry"
        try {
            $ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            $loginUrl = "http://${AuthSvr}/drcom/login?callback=dr1003" +
                "&DDDDD=${User}&upass=${Pass}&0MKKey=123456" +
                "&R1=0&R2=&R3=1&R6=0&para=00&v6ip=" +
                "&terminal_type=1&lang=zh-cn&jsVersion=4.1.3&v=${ts}&lang=zh"

            $resp = Invoke-WebRequest $loginUrl -Method GET -TimeoutSec 10 -UseBasicParsing `
                -Headers @{
                    'Accept'='*/*'; 'Accept-Language'='zh-CN,zh;q=0.9'
                    'Referer'="http://${AuthSvr}/"
                    'User-Agent'='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                }
            $body = $resp.Content

            if ($body -match 'dr1003\((\{.+?\})\)') {
                $json = $Matches[1]
                if ($json -match '"result"\s*:\s*1') { log 'LOGIN SUCCESS!'; return }
                if ($json -match '"result"\s*:\s*0' -and $json -match '"msg"\s*:\s*1') {
                    log 'Already online'; return
                }
                log "Unexpected response: $($json.Substring(0, [Math]::Min(200,$json.Length)))"
            } else {
                log "Bad response: $($body.Substring(0,[Math]::Min(200,$body.Length)))"
            }
            Start-Sleep 2
        } catch {
            log "Error: $($_.Exception.Message)"
            Start-Sleep 3
        }
    }
    log 'LOGIN FAILED after retries'
}

# ── Main ─────────────────────────────────────────────────────────
if ($Loop) {
    log '=== LOOP MODE STARTED ==='
    while ($true) {
        try { Do-Login -force $false }
        catch { log "Loop error: $($_.Exception.Message)" }
        Start-Sleep -Seconds 60
    }
} else {
    Do-Login -force $Force
}
