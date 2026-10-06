@echo off
rem Instala o actualiza el addon WowPeruLandGearExport. Doble clic para ejecutar.
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; iex (irm https://raw.githubusercontent.com/FunMonkeyDev/WoWPeruLandGearExport/main/install.ps1)"
pause
