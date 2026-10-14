# Soporte Multi-Monitor para Moonlight-Qt

Este documento describe la arquitectura, protocolo, atajos y funcionamiento de la funcionalidad **Multi-Monitor Dinámico** introducida en Moonlight-Qt y `moonlight-common-c`.

---

## 1. Arquitectura y Protocolo de Comunicación

Para permitir la alternancia fluida de monitores remotos sin desconectar ni reiniciar la sesión de streaming, se añade soporte para el paquete de control **`CONTROL_MSG_SET_DISPLAY` (código `0x0502`)**.

### Especificación del Paquete
- **Opcode de Control:** `0x0502` (`CONTROL_MSG_SET_DISPLAY`)
- **Transporte:** ENet confiable (`ENET_PACKET_FLAG_RELIABLE`) a través del canal de control encriptado (Gen 7 Encrypted) hacia el host (p. ej., Sunshine).
- **Carga Útil (Payload):** Identificador numérico de la pantalla destino (1 byte):
  - `0`: Pantalla 1 (`DISPLAY_TARGET_P1`)
  - `1`: Pantalla 2 (`DISPLAY_TARGET_P2`)
  - `2`: Mosaico Horizontal (`DISPLAY_TARGET_MOSAIC`)
  - `3`: Mosaico Vertical (`DISPLAY_TARGET_MOSAIC_V`)

### Capa Core C (`moonlight-common-c`)
Se implementó en `src/Limelight.h` y `src/ControlStream.c` la API nativa:
```c
// Identificadores de pantalla destino
#define CONTROL_MSG_SET_DISPLAY 0x0502
#define DISPLAY_TARGET_P1        0
#define DISPLAY_TARGET_P2        1
#define DISPLAY_TARGET_MOSAIC    2
#define DISPLAY_TARGET_MOSAIC_V  3

// Envía la solicitud de cambio de monitor al host
int LiSendDisplayTarget(uint8_t displayTarget);
```

---

## 2. Atajos de Teclado en el Stream

Durante la sesión activa de streaming, el usuario puede alternar instantáneamente la pantalla mostrada utilizando atajos rápidos (funcionan tanto con `Ctrl + Alt` como con `Ctrl + Alt + Shift`, y admiten AltGr):

| Atajo Rápido | Atajo Completo | Acción | Destino |
|---|---|---|---|
| **`Ctrl + Alt + 1`** | `Ctrl + Alt + Shift + 1` | Conmuta a la primera pantalla remota | Pantalla 1 (P1) |
| **`Ctrl + Alt + 2`** | `Ctrl + Alt + Shift + 2` | Conmuta a la segunda pantalla remota | Pantalla 2 (P2) |
| **`Ctrl + Alt + M`** | `Ctrl + Alt + Shift + M` | Muestra ambas pantallas lado a lado | Mosaico Horizontal |
| **`Ctrl + Alt + 3`** (o 4/V) | `Ctrl + Alt + Shift + 3` | Muestra ambas pantallas una arriba y otra abajo | Mosaico Vertical |
| **`Ctrl + Alt + Z`** | `Ctrl + Alt + Shift + Z` | **Liberar/Capturar ratón y mostrar HUD** | Alterna ratón libre / capturado |

> **Nota sobre supresión de teclas:** Todos los atajos interceptan y limpian inmediatamente los modificadores (`Ctrl`, `Alt`, `Shift`) y suprimen el evento de liberación (`key up`), evitando que cualquier pulsación se filtre al host o al juego.
>
> **Nota sobre compatibilidad:** El atajo previo de Moonlight `Ctrl + Alt + Shift + M` (que alternaba el modo de captura del ratón) ha sido reasignado a `Ctrl + Alt + Shift + F10` para garantizar que la letra **`M`** quede reservada intuitivamente para **Mosaico**.

---

## 3. Selector Visual Interactivo en el Overlay y Menú

### Liberar el ratón y usar el HUD
1. **Sacar el ratón:** Presiona **`Ctrl + Alt + Z`** (o `Ctrl + Alt + Shift + Z`). El cursor del ratón se liberará del juego y aparecerá de forma fija el HUD interactivo en la parte superior:
   ```
   [ *1: Pantalla 1* ]   [ 2: Pantalla 2 ]   [ M: Mosaico H ]   [ V: Mosaico V ]
   ```
2. **Hacer clic en los botones:** Con el ratón libre, haz clic izquierdo sobre cualquiera de los 4 cuadrantes para cambiar inmediatamente entre monitores y modos mosaico. El ratón permanecerá libre para que puedas elegir cómodamente.
3. **Volver al juego:** Haz clic en cualquier parte de la pantalla debajo de la franja superior (o vuelve a presionar `Ctrl + Alt + Z`) para recapturar el ratón en el juego y ocultar el HUD.
4. **Notificación en atajos directos:** Si usas los atajos de teclado directamente (`Ctrl + Alt + 1/2/M/3`), el overlay aparecerá temporalmente durante 3.5 segundos confirmando el cambio y se ocultará automáticamente sin interferir con el juego.
4. Soporte nativo integrado en todos los renderizadores de vídeo de Moonlight:
   - DirectX 11 (`d3d11va`)
   - DirectX 9 (`dxva2`)
   - SDL2 Software / GPU (`sdlvid`)
   - OpenGL ES (`eglvid`)
   - Linux DRM/KMS (`drm`)
   - Vulkan (`plvk`)
   - VA-API (`vaapi`)
   - VDPAU (`vdpau`)
   - macOS Metal (`vt_metal`)
   - macOS AVSampleBufferDisplayLayer (`vt_avsamplelayer`)

### Menú de Configuración y Componente QML
- **Ajustes de Moonlight (`SettingsView.qml`):** Se añade una sección dedicada *Multi-Monitor / Pantalla de transmisión* donde el usuario puede predeterminar la pantalla inicial deseada mediante un desplegable y el widget visual.
- **Componente `DisplaySelector.qml`:** Componente modular interactivo reutilizable en la interfaz QML que se enlaza bidireccionalmente con la propiedad `session.displayTarget`.

---

## 4. Calibración y Remapeo de Coordenadas del Ratón

Cuando el host cuenta con dos pantallas en disposición horizontal y se conmuta a una de ellas:
- **Modo Pantalla 1 (`DISPLAY_TARGET_P1`):**
  - Factor de escala horizontal: `0.5`
  - Desplazamiento horizontal: `0.0`
  - Coordenadas de entrada remapeadas al rango `[0.0, 0.5]` del escritorio virtual del host.
- **Modo Pantalla 2 (`DISPLAY_TARGET_P2`):**
  - Factor de escala horizontal: `0.5`
  - Desplazamiento horizontal: `0.5`
  - Coordenadas de entrada remapeadas al rango `[0.5, 1.0]` del escritorio virtual del host.
- **Modo Mosaico (`DISPLAY_TARGET_MOSAIC`):**
  - Factor de escala: `1.0`, Desplazamiento: `0.0`. Abarca la totalidad del lienzo remoto.

La calibración se aplica de forma unificada en:
- Eventos de ratón absoluto (`LiSendMousePositionEvent`).
- Eventos táctiles directos (`LiSendTouchEvent`).
- Eventos de lápiz óptico (`LiSendPenEvent`).
- Emulación táctil de ratón absoluto.

---

## 5. Resumen de Archivos Modificados

| Archivo | Cambios Principales |
|---|---|
| `moonlight-common-c/.../Limelight.h` | Declaración de `CONTROL_MSG_SET_DISPLAY` y `LiSendDisplayTarget`. |
| `moonlight-common-c/.../ControlStream.c` | Implementación de `LiSendDisplayTarget` con transmisión ENet confiable. |
| `app/settings/streamingpreferences.h/.cpp` | Preferencia persistente `targetDisplay` y enumeración `TargetDisplay`. |
| `app/streaming/session.h/.cpp` | Propiedad `displayTarget`, slots de conmutación, temporizador y lógica de overlay. |
| `app/streaming/input/input.h/.cpp` | Nuevos `KeyCombo`, calibración de matriz de entrada y reasignación de atajo de ratón. |
| `app/streaming/input/keyboard.cpp` | Manejador de atajos `Ctrl+Alt+Shift+1/2/M` y soporte para teclado numérico. |
| `app/streaming/input/mouse.cpp` | Calibración de coordenadas absolutas y clics interactivos sobre el selector. |
| `app/streaming/input/abstouch.cpp` | Calibración de coordenadas para pantallas táctiles y stylus. |
| `app/streaming/video/overlaymanager.h/.cpp` | Nuevo tipo de overlay `OverlayDisplaySelector` con tipografía y color cian. |
| `app/streaming/video/ffmpeg-renderers/*` | Posicionamiento centrado superior en los 10 motores de renderizado. |
| `app/gui/DisplaySelector.qml` | Componente visual interactivo con botones de selección de pantalla. |
| `app/gui/SettingsView.qml` | Integración del selector visual en la vista de ajustes de Moonlight. |
| `app/qml.qrc` | Registro de `DisplaySelector.qml` en los recursos compilados de Qt. |
