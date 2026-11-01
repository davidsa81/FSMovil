# FSMovil

App Android para los empleados de empresas que usan **FacturaScripts** (plugin **AppMovil**).
Una sola app para todas las empresas: el empleado escanea el QR que le dan en la oficina
(FacturaScripts → Administrador → App móvil) y queda enlazado.

## Qué hace
- Inicio con un botón grande por cada apartado que el empleado tiene activado.
- **Partes de trabajo** (plugin PartesTrabajo v3): mis partes, cómo llegar, llamar al cliente,
  empezar/terminar trabajo, materiales (con escáner de código de barras), fotos, observaciones,
  firma del cliente y cierre (solo el encargado).
- **Sin cobertura**: todo se guarda en el móvil y se envía solo cuando vuelve la conexión, en orden
  y sin duplicados (cada acción lleva un identificador único).
- Avisos de la oficina y aviso de actualización de la app.

## Compilar
No hace falta instalar nada: **GitHub Actions** compila el APK en cada cambio (pestaña *Actions* →
último *Compilar APK* → *Artifacts*).

Para publicar una versión: crear una etiqueta `v1.0.1` (por ejemplo desde *Releases → Draft a new
release*). El APK queda en la publicación y siempre en:

    https://github.com/<usuario>/FSMovil/releases/latest/download/FSMovil.apk

Ese enlace se pone en FacturaScripts → App móvil → Ajustes → *Enlace de descarga del APK*, junto con
el *versionCode* que indica la publicación.

La carpeta `android/` no está en el repositorio: se genera en cada compilación con `flutter create`
y se ajusta con `tool/configurar_android.py` (permisos, icono, firma).

### Firma del APK
El APK se firma con la clave guardada en los secretos del repositorio
(*Settings → Secrets and variables → Actions*):

| Secreto | Contenido |
|---|---|
| `KEYSTORE_BASE64` | el archivo `fsmovil.jks` en base64 |
| `KEYSTORE_PASSWORD` | contraseña del almacén |
| `KEY_ALIAS` | `fsmovil` |
| `KEY_PASSWORD` | contraseña de la clave |

### Notificaciones push
Secreto `GOOGLE_SERVICES_JSON` con el contenido de `google-services.json` del proyecto Firebase
(app Android `com.fsmovil.fsmovil`). Sin él la app se compila igual, pero sin notificaciones.
Los envíos los hace el servicio `fsmovil-push` (plugin AppMovil), que guarda la cuenta de servicio.

**Guarda una copia del `.jks` y su contraseña fuera de GitHub.** Si se pierde, las nuevas versiones
no podrán instalarse encima de la anterior: habría que desinstalar la app en cada móvil.

## Estructura
- `lib/api` – cliente de la API de AppMovil.
- `lib/datos` – sesión, cola offline, caché y estado.
- `lib/pantallas` – pantallas (enlazar, inicio, avisos, pendientes, partes...).
- `tool/` – configuración Android e iconos.
