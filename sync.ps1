# Copia la skin de esta carpeta a Rainmeter\Skins\milaneson y recarga los widgets.
# Conserva los ajustes del usuario (Settings.inc / State.inc); solo agrega claves nuevas.
# Uso:  powershell -ExecutionPolicy Bypass -File .\sync.ps1

$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'milaneson'
$dst = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins\milaneson'
$rm  = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
$userFiles = @('Settings.inc', 'State.inc', 'Cover.png')

function Get-Configs($root) {
    if (-not (Test-Path $root)) { return @() }
    Get-ChildItem -Directory $root | Where-Object { $_.Name -notlike '@*' } | ForEach-Object { $_.Name } | Sort-Object
}
$before = (Get-Configs $dst) -join ','

# 1) Espejo de archivos, sin tocar los del usuario
robocopy $src $dst /MIR /XF $userFiles /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy fallo con codigo $LASTEXITCODE" }

# 2) Archivos del usuario: copiar si faltan; en Settings.inc agregar claves nuevas
foreach ($f in 'Settings.inc', 'State.inc') {
    $s = Join-Path $src "@Resources\$f"; $d = Join-Path $dst "@Resources\$f"
    if (-not (Test-Path $d)) { Copy-Item $s $d; continue }
    $have = @{}
    foreach ($l in Get-Content $d -Encoding Unicode) { if ($l -match '^\s*([^;=\[]+?)\s*=') { $have[$Matches[1]] = 1 } }
    $add = Get-Content $s -Encoding Unicode | Where-Object { $_ -match '^\s*([^;=\[]+?)\s*=' -and -not $have.ContainsKey($Matches[1]) }
    if ($add) {
        Add-Content $d -Value $add -Encoding Unicode
        Write-Host "  $f + $($add.Count) clave(s) nueva(s)"
    }
}

# 3) Recargar en Rainmeter
$after = (Get-Configs $dst) -join ','
if (Test-Path $rm) {
    if ($before -ne $after) {
        & $rm '!RefreshApp'                          # hay configs nuevas/borradas
        Write-Host 'Rainmeter: RefreshApp (cambiaron las configs)'
    } else {
        & $rm '!RefreshGroup' 'MilanesonWidgets'
        & $rm '!Refresh' 'milaneson\Hub'
        Write-Host 'Rainmeter: widgets y Hub recargados'
    }
}
Write-Host "Sincronizado -> $dst"
