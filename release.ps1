<#
    Publica una version nueva del addon: actualiza el .toc, hace commit, crea la etiqueta y la sube.
    GitHub arma el ZIP y lo publica en Releases.
    Uso: .\release.ps1 -Version 2.2
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+(\.\d+)+$')]
    [string]$Version
)

$Toc = Join-Path $PSScriptRoot "addon\WowPeruLandGearExport\WowPeruLandGearExport.toc"
$Tag = "v$Version"

Set-Location $PSScriptRoot

if (git tag --list $Tag) {
    Write-Error "La etiqueta $Tag ya existe"
    exit 1
}

if (git status --porcelain) {
    Write-Error "Hay cambios sin commit. Haz commit primero y vuelve a ejecutar."
    exit 1
}

$Content = [System.IO.File]::ReadAllText($Toc)
$Content = $Content -replace '(?m)^## Version:.*$', "## Version: $Version"
[System.IO.File]::WriteAllText($Toc, $Content)

git add $Toc
git commit -m "Version $Version" --allow-empty
git tag $Tag
git push origin HEAD $Tag
if ($LASTEXITCODE -ne 0) {
    Write-Error "No se pudo subir a GitHub"
    exit 1
}

Write-Host "Version $Version publicada. El ZIP aparecera en Releases en un minuto." -ForegroundColor Green
