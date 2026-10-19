# GRFS-Recomp

Launcher de **Ghost Recon Future Soldier Recomp** para macOS Apple Silicon, construido sobre ReXGlue/Xenos y Vulkan mediante MoltenVK. Proyecto experimental independiente, sin afiliación con Ubisoft, Microsoft ni ReXGlue.

## Descargar e instalar

Descarga **GRFS-Recompiled-macOS-arm64.zip** desde [Releases](https://github.com/alex-stampede/GRFS-Recomp/releases/latest), descomprime y arrastra **GRFS Recompiled.app** a Aplicaciones. Abre la app y selecciona tu propia ISO compatible de Xbox 360. No necesitas instalar el SDK.

**Requisitos de esta build:** Apple Silicon y macOS **27.0 o posterior**. Es el mínimo de los binarios actuales, no una afirmación de compatibilidad con versiones anteriores. La firma es ad hoc; todavía no hay firma Developer ID ni notarización de Apple. No se ha validado aún en una segunda Mac.

La primera apertura verifica los ejecutables y tamaños de los archivos, muestra progreso del 0 al 100% y extrae localmente el juego. En siguientes aperturas inicia directamente. El instalador se oculta al arrancar el juego. El paquete no contiene la ISO ni los archivos de datos originales.

Solo está validada la edición identificada por los hashes de `launcher/compatible-game.json`. Otras regiones o revisiones pueden rechazarse.

## Actualizaciones

Al abrir, el launcher consulta la última Release pública de este repositorio. Si hay una build más reciente muestra los cambios y permite elegir **Descargar y actualizar** o **Ahora no**. Sin conexión o sin una Release compatible continúa normalmente.

Las actualizaciones deben incluir `update.json`, un manifiesto firmado con Ed25519. La clave pública está fijada en la app; se verifica también el SHA-256 del ZIP, la identidad de la app, su build y la firma de código. La actualización se prepara antes de cerrar el launcher. Un auxiliar reemplaza solo la app, conserva una copia de la versión anterior junto a ella y vuelve a abrirla. Si no tiene permiso de escritura ofrece la actualización para moverla manualmente. No requiere contraseña de GitHub.

Esta versión añade el actualizador por primera vez: las versiones anteriores deben reemplazarse manualmente una vez. Las siguientes podrán actualizarse desde la app. El flujo automático está probado con datos sintéticos; la primera actualización entre dos Releases públicas todavía requiere validación.

## Partidas y shaders

Los datos se conservan en `~/Library/Application Support/GRFS Recompiled/`:

- `Game`: instalación extraída.
- `UserData`: perfil y partidas.
- `Cache`: shaders y pipelines conocidos.
- `Logs`: registros del juego.
- `Updates`: descargas y preparación de actualizaciones.

Reemplazar la app no borra estos directorios. Las partidas del prototipo anterior no se migran automáticamente.

El SDK precarga los shaders conocidos y conserva su almacenamiento. No puede descubrir todos los shaders de antemano ni evitar toda recompilación; las escenas nuevas pueden dar tirones. El 100% de instalación no significa compilación de todos los shaders.

## Estado

Campaña, creación y continuación de partidas, Guerrilla, audio y controles han funcionado en la Mac de desarrollo. Persisten errores gráficos en algunas cinemáticas y al recargar ciertas escenas. Se conserva el ajuste mip0 de la base jugable; no es una corrección completa del sistema de mipmaps.

## Código y compilación

`launcher/` contiene la interfaz AppKit, lector XDVDFS, actualizador, auxiliar de reemplazo y pruebas. Este repositorio no incluye la ISO, partidas, claves privadas ni el código generado a partir del juego.

Para compilar necesitas las herramientas de Xcode y un runtime ARM64 compatible ya compilado: `grfs`, `librexruntime.dylib`, `librexgpu-xenos.dylib`, `libgrfs_AICLASS_X360_F.dylib`, `libTracyClient.dylib` y `vulkan/`. Define `GRFS_RUNTIME_DIR` con esa carpeta y ejecuta `python3 launcher/build.py`. `GRFS_ICON_FILE` permite indicar un `.icns`. El script no recompila el juego; el ZIP de Release incluye el runtime listo para usar con tu ISO.

El SDK original está en [rexglue/rexglue-sdk](https://github.com/rexglue/rexglue-sdk). Se acompaña la distribución con una instantánea del código del SDK utilizado en desarrollo y sus dependencias, en `ReXGlue-SDK-source.tar.gz`; el historial de reproducción del juego sigue en desarrollo. Esta instantánea no contiene código del juego generado desde la ISO.

Para preparar futuras versiones y publicar manifiestos firmados consulta [RELEASING.md](RELEASING.md). El actualizador solo acepta versiones firmadas con la clave correspondiente a `launcher/update-public-key.txt`.

## Licencias

El código original del launcher está bajo MIT. ReXGlue/Xenia y las dependencias conservan sus licencias en `THIRD_PARTY_LICENSES`, también incluidas dentro de la app. El juego y su arte pertenecen a sus titulares y no quedan cubiertos por la licencia del launcher.
