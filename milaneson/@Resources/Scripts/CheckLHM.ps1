# Detecta LibreHardwareMonitor para el Hub de milaneson.
# Imprime una sola linea:  ESTADO|RutaExe|Puerto
#   OK         servidor web responde y hay sensores de CPU/GPU
#   AUTH       el servidor web pide usuario/contrasena
#   NOSENSORS  responde, pero sin los sensores esperados (suele ser: no corre como admin)
#   NOWEB      LHM esta abierto, pero el servidor web no responde
#   STOPPED    LHM esta instalado, pero no esta abierto
#   MISSING    no se encontro LibreHardwareMonitor.exe
param([int]$Port = 8085)

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$exeName = 'LibreHardwareMonitor.exe'

function Find-LhmExe {
    # 1) Tarea programada que crea LHM con "Run on Windows Startup"
    foreach ($t in (Get-ScheduledTask | Where-Object { $_.TaskName -like '*LibreHardwareMonitor*' })) {
        foreach ($a in $t.Actions) {
            $p = $a.Execute.Trim('"')
            if ($p -and (Test-Path $p)) { return $p }
        }
    }
    # 2) Proceso en ejecucion (si LHM corre como admin, Windows oculta la ruta)
    $p = (Get-Process LibreHardwareMonitor | Select-Object -First 1).Path
    if ($p -and (Test-Path $p)) { return $p }
    # 3) Carpetas habituales
    $roots = @(
        'C:\Apps', $env:ProgramFiles, ${env:ProgramFiles(x86)},
        "$env:LOCALAPPDATA\Programs", "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
        "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents"
    ) | Where-Object { $_ -and (Test-Path $_) }
    foreach ($r in $roots) {
        $hit = Get-ChildItem -Path $r -Filter $exeName -Recurse -Depth 3 -File | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return ''
}

$exe = Find-LhmExe
$running = [bool](Get-Process LibreHardwareMonitor)

# Leer el puerto y la autenticacion desde LibreHardwareMonitor.config
$authOn = $false
if ($exe) {
    $cfg = Join-Path (Split-Path $exe) 'LibreHardwareMonitor.config'
    if (Test-Path $cfg) {
        try {
            [xml]$x = Get-Content -Raw $cfg
            $kv = @{}
            foreach ($n in $x.configuration.appSettings.add) { $kv[$n.key] = $n.value }
            if ($kv['listenerPort'] -match '^\d+$') { $Port = [int]$kv['listenerPort'] }
            $authOn = ($kv['authenticationEnabled'] -eq 'true')
        } catch {}
    }
}

function Out-State($s) { Write-Output ("{0}|{1}|{2}" -f $s, $exe, $Port); exit 0 }

# Probar el servidor web
$body = $null; $code = 0
try {
    $r = Invoke-WebRequest -Uri "http://localhost:$Port/data.json" -UseBasicParsing -TimeoutSec 3
    $code = [int]$r.StatusCode; $body = $r.Content
} catch {
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
}

if ($code -eq 401 -or ($authOn -and -not $body)) { Out-State 'AUTH' }
if ($body) {
    $cpuTemp = $body -match '"Text":"(Core \(Tctl/Tdie\)|CPU Package)","Min":"[^"]*","Value":"[\d.]+ \\u00B0C"'
    $cpuLoad = $body -match '"Text":"CPU Total"'
    $gpu     = $body -match '"Text":"GPU Core"'
    if ($cpuTemp -and $cpuLoad -and $gpu) { Out-State 'OK' }
    Out-State 'NOSENSORS'
}
if ($running) { Out-State 'NOWEB' }
if ($exe)     { Out-State 'STOPPED' }
Out-State 'MISSING'
