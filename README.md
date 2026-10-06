# WowPeruLand Gear Export

Addon para el cliente 3.3.5a de WowPeruLand. Exporta el equipo de tu personaje para usarlo en la web del servidor o para pedirle consejo a una IA.

## Instalación

1. Descarga el ZIP de la última versión desde [Releases](../../releases/latest).
2. Descomprímelo dentro de `Interface\AddOns` en la carpeta de tu cliente. Debe quedar `Interface\AddOns\WowPeruLandGearExport`.
3. Reinicia el juego y activa el addon en la pantalla de personajes.

Para actualizar, repite los pasos y reemplaza la carpeta.

## Comandos

| Comando | Qué hace |
|---|---|
| `/gearexport` | Genera el texto de tu equipo para importarlo en la web de WowPeruLand. |
| `/geai` | Genera un prompt completo con tu equipo, tus bolsas y tus encantamientos. Pégalo en cualquier IA (ChatGPT, Gemini, Claude) y te dirá qué equipar, qué mejoras buscar y qué encantar. |
| `/geai2` | Lo mismo que `/geai`, pero solo con los datos del personaje. Es para pegarlo en el asistente del servidor, que ya tiene las instrucciones. |

En los tres casos se abre una ventana con el texto: `Ctrl+A` para seleccionarlo y `Ctrl+C` para copiarlo.

## Para quien mantiene el addon

- `deploy-addon.ps1` copia el addon a tu cliente local para probarlo.
- `release.ps1 -Version 2.2` actualiza la versión, crea la etiqueta y la sube. GitHub arma el ZIP y lo publica en Releases.
- `addon/WowPeruLandGearExport/GEM_INSTRUCCIONES.md` tiene las instrucciones del asistente (Gem o GPT) que recibe el texto de `/geai2`.
