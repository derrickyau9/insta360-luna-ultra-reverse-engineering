param(
    [string]$HostAlias = "luna",
    [string]$Command
)

$ssh = Get-Command ssh -ErrorAction Stop

if ($Command) {
    & $ssh.Source $HostAlias $Command
} else {
    & $ssh.Source $HostAlias
}
