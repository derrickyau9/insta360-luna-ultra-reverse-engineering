param(
    [string]$Endpoint = "192.168.42.1:5555"
)

$adb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adb) {
    $sdkAdb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $sdkAdb) {
        $adbPath = $sdkAdb
    } else {
        throw "adb was not found in PATH or the default Android SDK location."
    }
} else {
    $adbPath = $adb.Source
}

& $adbPath connect $Endpoint
& $adbPath -s $Endpoint wait-for-device
& $adbPath -s $Endpoint shell id

Write-Host "Opening a root ADB shell on $Endpoint..."
& $adbPath -s $Endpoint shell
