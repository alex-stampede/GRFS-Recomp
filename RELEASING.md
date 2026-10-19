# Publicar una versión

1. Prueba los cambios conservando una copia de la base anterior. Incrementa `version`, `build` (entero creciente), `tag` y el mínimo real de macOS en `launcher/version.json`.
2. Define `GRFS_RUNTIME_DIR` con el runtime probado y, opcionalmente, `GRFS_ICON_FILE`. Ejecuta `python3 launcher/build.py`.
3. Compila `launcher/release-tools/SignUpdate.swift`. La clave privada de mantenimiento se guarda **fuera del repositorio**, con permisos 600. No la regeneres para cada Release: las apps instaladas fijan la clave pública anterior. Haz una copia segura fuera de GitHub.
4. Solo para un proyecto nuevo: `SignUpdate init /ruta/privada/update.key launcher/update-public-key.txt`. Para esta distribución la clave pública ya está fijada: usa la clave privada existente.
5. Firma el manifiesto: `SignUpdate sign /ruta/privada/update.key launcher/dist/update-payload.json launcher/dist/update.json`.
6. Crea una Release pública estable cuyo tag coincida con `version.json`. Adjunta `GRFS-Recompiled-macOS-arm64.zip`, `SHA256SUMS.txt`, `update.json` y el archivo de fuentes/licencias del SDK correspondiente. Publica la Release solo cuando todos los adjuntos estén presentes.
7. Comprueba la descarga, el manifiesto y la actualización desde la versión anterior. Las prereleases y drafts no las selecciona el endpoint `releases/latest`.

Nunca subas `.release-secrets`, claves, tokens, ISO, XEX originales, partidas ni datos extraídos. El ZIP compilado va a Releases, no al historial de código. El rollback automático cubre un error al reemplazar archivos; si la app nueva arranca pero falla funcionalmente, cierra el juego y recupera la copia `GRFS Previous-….app`.
