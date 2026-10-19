# Launcher

Código AppKit del instalador XDVDFS y del actualizador firmado. Consulta el README de la raíz para instalación, requisitos y limitaciones, y RELEASING.md para publicar versiones.

- main.swift: entrada de la app y utilidades CLI de inspección/extracción.
- Launcher.swift: selección de ISO, validación, progreso, arranque y datos persistentes.
- Updater.swift: consulta de GitHub, consentimiento, firma Ed25519 y descarga verificada.
- UpdateHelper.swift: reemplazo con copia anterior y reapertura.
- GameTitle.m: adaptación exclusiva del título de la ventana; mantiene intacto el runtime validado.
- compatible-game.json: hashes de ejecutables compatibles, sin contenido del juego.
- required-files.json: inventario de nombres y tamaños esperados.
- build.py: empaquetado, firmas ad hoc, ZIP, checksum y manifiesto por firmar.

## Pruebas

Compila main.swift, Launcher.swift y Updater.swift con AppKit y CryptoKit a `/private/tmp/grfs-launcher-build`; ejecuta `python3 launcher/test_iso.py`.

Compila UpdateHelper.swift con AppKit a `/private/tmp/grfs-update-helper`; ejecuta `python3 launcher/test_updates.py`. Las pruebas verifican extracción, rechazo de ISO inválida, firma válida, manipulación, clave incorrecta, origen de descarga, comparación de builds, reemplazo, copia anterior y conservación de datos externos.

No se incluye la clave privada de firma. No uses la clave pública del proyecto para publicar builds firmadas con otra clave: las apps instaladas rechazarían la actualización.
