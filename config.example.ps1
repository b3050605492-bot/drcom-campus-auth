# Campus Auto Login - Config Template
# Copy to config.ps1 and fill in your credentials
# The script will also read from environment variables:
#   CAMPUS_SSID, CAMPUS_USER, CAMPUS_PASS, CAMPUS_AUTH, CAMPUS_LOG

$env:CAMPUS_SSID = ''                # WiFi SSID (optional, leave empty to skip)
$env:CAMPUS_USER = 'your_account'    # Student/employee ID
$env:CAMPUS_PASS = 'your_password'   # Portal password
$env:CAMPUS_AUTH = '172.16.1.2'      # Auth server IP
$env:CAMPUS_LOG  = "$env:TEMP\campus-login.log"  # Log file path
