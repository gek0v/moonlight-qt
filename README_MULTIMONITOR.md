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

Durante la sesión activa de streaming, el usuario puede alternar instantáneamente la pantalla mostrada utilizando los siguientes atajos globales:

| Atajo | Acción | Destino |
|---|---|---|
| **`Ctrl + Alt + Shift + 1`** (o Numpad 1) | Conmuta a la primera pantalla remota | Pantalla 1 (P1) |
| **`Ctrl + Alt + Shift + 2`** (o Numpad 2) | Conmuta a la segunda pantalla remota | Pantalla 2 (P2) |
| **`Ctrl + Alt + Shift + M`** | Muestra ambas pantallas lado a lado | Mosaico Horizontal |
| **`Ctrl + Alt + Shift + 3`** (o Numpad 3) | Muestra ambas pantallas una arriba y otra abajo | Mosaico Vertical |

> **Nota sobre compatibilidad:** El atajo previo de Moonlight `Ctrl + Alt + Shift + M` (que alternaba el modo de captura del ratón) ha sido reasignado a `Ctrl + Alt + Shift + F10` para garantizar que la letra **`M`** quede reservada intuitivamente para **Mosaico**.

---

## 3. Selector Visual Interactivo en el Overlay y Menú

### Overlay en Stream (`OverlayDisplaySelector`)
Al presionar cualquiera de los atajos de cambio de pantalla o al iniciar el stream:
1. Se activa en la parte superior central de la ventana de renderizado un selector visual interactivo:
   ```
   [ *1: Pantalla 1* ]   [ 2: Pantalla 2 ]   [ M: Mosaico H ]   [ V: Mosaico V ]
   ```
   El elemento con asteriscos `*` resalta cuál es la pantalla activa actual.
2. **Interactividad con ratón:** El overlay es interactivo con el puntero. Si el usuario hace clic izquierdo sobre cualquiera de los 4 cuadrantes de la franja superior durante su visualización, la sesión conmuta inmediatamente a P1, P2, Mosaico H o Mosaico V, respectivamente.
3. El overlay permanece visible durante 3.5 segundos tras cada interacción y se desvanece automáticamente para no interferir con la experiencia visual o de juego.
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
