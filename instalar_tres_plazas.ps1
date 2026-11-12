# Ejecutar desde C:\estacionaya-infra\estacionaya
$ErrorActionPreference = "Stop"
$raiz = (Get-Location).Path
$ruta = Join-Path $raiz "vision_module\zonas_ezviz_antizana.json"
$codigo = Join-Path $raiz "vision_module\detector_zonas_ezviz.py"
$archivoNuevo = Join-Path $PSScriptRoot "vision_module\detector_zonas_ezviz.py"
if (!(Test-Path $ruta)) { throw "No existe $ruta" }
if (!(Test-Path $archivoNuevo)) { throw "No se encontro detector en el ZIP" }
$config = Get-Content $ruta -Raw -Encoding UTF8 | ConvertFrom-Json
$ant = @($config.zones | Where-Object { $_.id -eq "ANT-002" })
if ($ant.Count -ne 1) { throw "Debe existir exactamente una zona ANT-002" }
$antes = ($ant[0].roi | ConvertTo-Json -Compress)
$marca = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item $ruta "$ruta.respaldo_$marca" -Force
if (Test-Path $codigo) { Copy-Item $codigo "$codigo.respaldo_$marca" -Force }
$config.zones = @($ant[0])
# JSON UTF-8 sin BOM para Python json.load
$json = $config | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($ruta, $json + "`n", [System.Text.UTF8Encoding]::new($false))
Copy-Item $archivoNuevo $codigo -Force
$verificacion = Get-Content $ruta -Raw -Encoding UTF8 | ConvertFrom-Json
$despues = ($verificacion.zones[0].roi | ConvertTo-Json -Compress)
if ($antes -ne $despues) { throw "ERROR: ROI ANT-002 no coincide. Revisar respaldo." }
Write-Host "Listo: ANT-002 intacto. Otros recuadros retirados. Presiona C para crear las DOS plazas nuevas."
Write-Host "No se altero Supabase. Mantener solo ANT-002 en VISION_ACTIVE_ZONES hasta calibrar."
