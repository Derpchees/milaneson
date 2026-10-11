# Genera el instalador dist\milaneson_<version>.rmskin
# Uso:  powershell -ExecutionPolicy Bypass -File .\build.ps1

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$root      = $PSScriptRoot
$skinDir   = Join-Path $root 'milaneson'
$installer = Join-Path $root 'installer'
$distDir   = Join-Path $root 'dist'

$rmskinIni = Join-Path $installer 'RMSKIN.ini'
$version = (Select-String -Path $rmskinIni -Pattern '^Version=(.+)$').Matches[0].Groups[1].Value.Trim()
New-Item -ItemType Directory -Force $distDir | Out-Null
$out = Join-Path $distDir "milaneson_$version.rmskin"
if (Test-Path $out) { Remove-Item $out -Force }

# Lista de (archivo local, ruta dentro del paquete). Rutas con "/" para el zip.
$entries = @()
$entries += ,@($rmskinIni, 'RMSKIN.ini')
Get-ChildItem -Recurse -File $skinDir | ForEach-Object {
    $rel = $_.FullName.Substring($skinDir.Length + 1).Replace('\', '/')
    $entries += ,@($_.FullName, "Skins/milaneson/$rel")
}
Get-ChildItem -Recurse -File (Join-Path $installer 'Plugins') -Filter *.dll | ForEach-Object {
    $entries += ,@($_.FullName, "Plugins/$($_.Directory.Name)/$($_.Name)")
}

# 1) Zip normal
$fs = [System.IO.File]::Open($out, 'CreateNew')
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
foreach ($e in $entries) {
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $e[0], $e[1], [System.IO.Compression.CompressionLevel]::Optimal)
}
$zip.Dispose()
$fs.Dispose()

# 2) Pie que Rainmeter exige en un .rmskin: tamaño del zip (int64), flags (0) y "RMSKIN\0"
$zipSize = (Get-Item $out).Length
$footer = New-Object System.Collections.Generic.List[byte]
$footer.AddRange([BitConverter]::GetBytes([int64]$zipSize))
$footer.Add(0)
$footer.AddRange([Text.Encoding]::ASCII.GetBytes("RMSKIN"))
$footer.Add(0)
$fs = [System.IO.File]::Open($out, 'Append')
$fs.Write($footer.ToArray(), 0, $footer.Count)
$fs.Dispose()

Write-Host "Listo: $out ($($entries.Count) archivos)"
