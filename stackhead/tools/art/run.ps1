param(
    [string]$Rojo = 'rojo',
    [string]$Lune = 'lune',
    [string]$Python = 'python',
    [string]$Node = 'node',
    [int]$Port = 8124
)
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '../..')
$artServer = $null
try {
    New-Item -ItemType Directory -Force build/art/out | Out-Null
    & $Rojo build default.project.json -o build/Stackhead.rbxl
    if ($LASTEXITCODE -ne 0) { throw 'Rojo build failed' }
    & $Lune run tools/preview/export_scene.luau build/Stackhead.rbxl build/art/scene.json
    if ($LASTEXITCODE -ne 0) { throw 'Scene export failed' }
    if (-not (Test-Path build/art/node_modules/three)) {
        & npm.cmd install --prefix build/art --no-audit --no-fund three@0.180.0
        if ($LASTEXITCODE -ne 0) { throw 'Three.js install failed' }
    }
    Copy-Item tools/art/art.html,tools/art/composite.html,tools/art/fonts.css build/art/
    $artServer = Start-Process -FilePath $Python -ArgumentList @('-m','http.server',"$Port",'--bind','127.0.0.1','--directory','build/art') -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 1
    $env:SHOTS = 'tower crash icon panels worlds'
    & $Node tools/art/shoot.mjs "http://127.0.0.1:$Port" build/art/out
    if ($LASTEXITCODE -ne 0) { throw 'Rendering failed (Playwright + Chromium required)' }
    Copy-Item build/art/out/thumbnail-*.png,build/art/out/icon-512.png marketing/
} finally {
    if ($null -ne $artServer -and -not $artServer.HasExited) { Stop-Process -Id $artServer.Id }
    Pop-Location
}
