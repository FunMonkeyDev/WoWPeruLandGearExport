<#
    Copia el addon WowPeruLandGearExport a la carpeta AddOns del cliente de WoW.
    Uso: .\deploy-addon.ps1
    Opcional: .\deploy-addon.ps1 -WowPath "D:\Otra Ruta\WoW PeruLand"
#>
param(
    [string]$WowPath = "C:\WoW PeruLand"
)

$Source = Join-Path $PSScriptRoot "addon\WowPeruLandGearExport"
$AddOnsDir = Join-Path $WowPath "Interface\AddOns"
$Destination = Join-Path $AddOnsDir "WowPeruLandGearExport"

if (-not (Test-Path $Source)) {
    Write-Error "No se encontro la carpeta del addon en: $Source"
    exit 1
}

if (-not (Test-Path $AddOnsDir)) {
    Write-Error "No se encontro Interface\AddOns en: $WowPath (revisa la ruta del cliente)"
    exit 1
}

Copy-Item -Path $Source -Destination $AddOnsDir -Recurse -Force

Write-Host "Addon copiado a: $Destination" -ForegroundColor Green
Get-ChildItem $Destination
