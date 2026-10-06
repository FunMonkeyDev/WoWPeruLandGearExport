<#
    Descarga la ultima version del addon WowPeruLandGearExport desde GitHub y la instala en el cliente.
    Uso rapido (pegar en PowerShell):
        irm https://raw.githubusercontent.com/FunMonkeyDev/WoWPeruLandGearExport/main/install.ps1 | iex
    Con otra ruta: descarga este archivo y ejecuta .\install.ps1 -WowPath "D:\Juegos\WoW PeruLand"
#>
param(
    [string]$WowPath = "C:\WoW PeruLand"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = "FunMonkeyDev/WoWPeruLandGearExport"
$AddonName = "WowPeruLandGearExport"

# Si el juego no esta en la ruta por defecto, se pregunta hasta dar con una carpeta valida.
while (-not (Test-Path (Join-Path $WowPath "Interface\AddOns"))) {
    Write-Host "No se encontro el juego en: $WowPath" -ForegroundColor Yellow
    $WowPath = Read-Host "Escribe la ruta de la carpeta del juego (o deja vacio para salir)"
    if (-not $WowPath) {
        Write-Host "Instalacion cancelada."
        return
    }
    $WowPath = $WowPath.Trim('"')
}

$AddOnsDir = Join-Path $WowPath "Interface\AddOns"
$TempZip = Join-Path $env:TEMP "$AddonName.zip"

try {
    Write-Host "Buscando la ultima version..."
    $Release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ "User-Agent" = $AddonName }
    $Asset = $Release.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
    if (-not $Asset) {
        throw "La version $($Release.tag_name) no tiene un ZIP publicado."
    }

    Write-Host "Descargando $($Asset.name)..."
    Invoke-WebRequest $Asset.browser_download_url -OutFile $TempZip -UseBasicParsing

    # Se borra la version anterior para que no queden archivos viejos.
    $Destination = Join-Path $AddOnsDir $AddonName
    if (Test-Path $Destination) {
        Remove-Item $Destination -Recurse -Force
    }
    Expand-Archive $TempZip -DestinationPath $AddOnsDir -Force
    Remove-Item $TempZip -Force

    Write-Host "Addon $($Release.tag_name) instalado en: $Destination" -ForegroundColor Green
    Write-Host "Si el juego esta abierto, reinicialo para cargar la version nueva."
}
catch {
    Write-Host "No se pudo instalar el addon: $($_.Exception.Message)" -ForegroundColor Red
}
