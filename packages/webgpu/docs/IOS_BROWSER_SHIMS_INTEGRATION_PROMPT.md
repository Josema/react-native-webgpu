# Prompt de Integración iOS (WebGPU Core + Browser Shims)

## Objetivo
Integrar `webgpu-core` (Dawn + JSI) dentro de una app iOS nativa (sin React Native), reutilizando una capa de browser shims para ejecutar código JS estilo navegador (como el ejemplo del triángulo).

Este documento está pensado para usarlo como prompt técnico en otro repositorio/proyecto.

## Prompt listo para usar

```text
Actúa como Staff Engineer C++/JSI/Metal para integrar el paquete webgpu-core en esta app iOS nativa.

Contexto:
- Runtime JS: JSI (JSC o Hermes).
- Backend gráfico: Dawn + Metal (CAMetalLayer).
- Ya existen browser shims base para: requestAnimationFrame, canvas, window y document.
- Necesito correr código WebGPU JS estilo navegador:
  - navigator.gpu.requestAdapter()
  - adapter.requestDevice()
  - canvas.getContext('webgpu')

Objetivo:
1) Instalar WebGPU en runtime JS con:
   - rnwgpu::installWebGPU(runtime, hostContext)
2) Conectar un surface nativo iOS (CAMetalLayer) con:
   - MetalSurfaceHost::attachSurface(surfaceId, layer, width, height)
3) Exponer los shims faltantes y alinear semántica browser/webgpu.
4) Ejecutar un smoke JS (triángulo) y validar render + resize sin crash.

Restricciones:
- Sin dependencias React Native.
- Cambios incrementales y revisables.
- Threading seguro para callbacks async/promise.
- Evitar rediseño innecesario.

Implementación requerida:
A) Bootstrap nativo
- Crear runtime JSI.
- Crear ApplePlatformContext + JSDispatcher main thread.
- Llamar installWebGPU(runtime, hostContext).
- Registrar surface CAMetalLayer con surfaceId fijo (por ejemplo 1).
- Mantener resize: al cambiar bounds/scale, llamar resizeSurface(surfaceId, w, h).

B) Browser shims (globalThis)
- navigator (si no existe)
- navigator.gpu
  - requestAdapter(options?) -> delegar a WebGPUHost.gpu.requestAdapter(options)
  - getPreferredCanvasFormat() -> delegar a WebGPUHost.gpu.getPreferredCanvasFormat()
- canvas
  - width/height/clientWidth/clientHeight
  - getContext('webgpu') -> devuelve y cachea WebGPUHost.createCanvasContext(surfaceId, width, height)
- document.querySelector('canvas') -> devolver canvas shim
- window.devicePixelRatio
- requestAnimationFrame/cancelAnimationFrame
- createImageBitmap (si aplica en la app) -> delegar a WebGPUHost.createImageBitmap(...)

C) Ajustes de compatibilidad que NO son browser-puros pero sí necesarios en este core
- Present explícito:
  - Tras device.queue.submit(...), llamar context.present() en cada frame.
  - Si el código JS no lo llama, añadir shim helper que lo haga automáticamente.
- getCurrentTexture + resize:
  - actualizar canvas.width/height antes de render
  - mantener resizeSurface(surfaceId, w, h) desde host iOS

D) Validación
- adapter != null
- device != null
- context.configure(...) OK
- frame loop dibuja triángulo
- resize de vista recompone surface y sigue renderizando
- sin referencias React*/RCT*/TurboModule/Fabric

Entregables:
1) Archivos tocados + rationale corto.
2) Código de shims final (JS) y bootstrap host (ObjC++/C++).
3) Comandos build/run para simulador.
4) Resultado de smoke test en logs.
```

---

## Checklist de shims faltantes (además de los que indicaste)

Partiendo de que ya tienes `requestAnimationFrame`, `canvas`, `window` y `document` base, para que el ejemplo JS de triángulo funcione de forma estable faltan normalmente:

1. `globalThis.navigator` (si no existe).
2. `navigator.gpu` enlazado a `WebGPUHost.gpu`.
3. `navigator.gpu.getPreferredCanvasFormat()`.
4. `canvas.getContext('webgpu')` con caché por `surfaceId`.
5. `document.querySelector('canvas')` devolviendo ese canvas shim.
6. `window.devicePixelRatio` (mapear desde `UIScreen.mainScreen.scale`).
7. `context.present()` por frame (explícito o inyectado), porque este core lo expone y lo usa para presentar en iOS.
8. `createImageBitmap` (opcional, pero recomendable para compat con libs que lo asumen).

Opcionales útiles:
- `globalThis.self = globalThis`
- `performance.now()`
- `console.*` robusto hacia logs nativos

---

## Contrato mínimo de integración (nativo)

Orden recomendado:

1. Crear runtime JSI.
2. `installWebGPU(runtime, hostContext)`.
3. `attachSurface(surfaceId, CAMetalLayer, width, height)`.
4. Evaluar script JS de shims.
5. Evaluar script JS de app (triángulo).
6. En resize UIKit: `resizeSurface(surfaceId, width, height)`.

APIs clave del paquete:
- `rnwgpu::installWebGPU(jsi::Runtime&, WebGPUHostContext)`
- `WebGPUHost.createCanvasContext(surfaceId, width, height)` (desde JS)

Referencia en este repo:
- `/Users/enzo/projects/react-native-webgpu/packages/webgpu/cpp/rnwgpu/WebGPUHostRuntime.h`
- `/Users/enzo/projects/react-native-webgpu/packages/webgpu/cpp/rnwgpu/api/WebGPUHostObject.h`
- `/Users/enzo/projects/react-native-webgpu/packages/webgpu/ios-native-example/WebGPURenderer.mm`

---

## Shim JS de referencia (adaptador browser -> webgpu-core)

```js
(function installBrowserLikeShims() {
  const g = globalThis;

  // Base globals
  g.self ??= g;
  g.window ??= g;
  g.navigator ??= {};

  if (!g.WebGPUHost || !g.WebGPUHost.gpu) {
    throw new Error('WebGPUHost.gpu no está instalado. Ejecuta installWebGPU primero.');
  }

  // navigator.gpu
  g.navigator.gpu = {
    requestAdapter(options) {
      return g.WebGPUHost.gpu.requestAdapter(options);
    },
    getPreferredCanvasFormat() {
      return g.WebGPUHost.gpu.getPreferredCanvasFormat();
    },
    get wgslLanguageFeatures() {
      return g.WebGPUHost.gpu.wgslLanguageFeatures;
    },
  };

  // Canvas shim (1 surfaceId <-> 1 CAMetalLayer)
  const surfaceId = 1;
  const canvas = g.canvas ?? {
    width: 1,
    height: 1,
    clientWidth: 1,
    clientHeight: 1,
    style: {},
  };

  let webgpuContext = null;
  canvas.getContext = function getContext(kind) {
    if (kind !== 'webgpu') return null;
    if (!webgpuContext) {
      webgpuContext = g.WebGPUHost.createCanvasContext(surfaceId, canvas.width, canvas.height);
    }
    return webgpuContext;
  };

  g.canvas = canvas;

  // document shim mínimo
  g.document ??= {};
  g.document.querySelector ??= (sel) => (sel === 'canvas' ? canvas : null);

  // devicePixelRatio (inyectar valor real desde host si puedes)
  g.window.devicePixelRatio ??= 1;

  // createImageBitmap opcional (útil para ecosistema web)
  g.createImageBitmap ??= (input) => g.WebGPUHost.createImageBitmap(input);

  // RAF/cRAF deben existir en tu host; fallback simple
  if (!g.requestAnimationFrame) {
    let rafId = 0;
    const rafMap = new Map();
    g.requestAnimationFrame = (cb) => {
      const id = ++rafId;
      const t = Date.now();
      const handle = setTimeout(() => {
        rafMap.delete(id);
        cb(t);
      }, 16);
      rafMap.set(id, handle);
      return id;
    };
    g.cancelAnimationFrame = (id) => {
      const h = rafMap.get(id);
      if (h != null) {
        clearTimeout(h);
        rafMap.delete(id);
      }
    };
  }
})();
```

---

## Adaptación del triángulo JS (punto crítico: present)

Tu ejemplo JS es válido casi completo. En este core, añade `context.present?.()` después de `queue.submit(...)`:

```js
function frame() {
  const commandEncoder = device.createCommandEncoder();
  const textureView = context.getCurrentTexture().createView();
  const pass = commandEncoder.beginRenderPass({
    colorAttachments: [{
      view: textureView,
      clearValue: { r: 0.1, g: 0.1, b: 0.15, a: 1.0 },
      loadOp: 'clear',
      storeOp: 'store',
    }],
  });
  pass.setPipeline(pipeline);
  pass.draw(3);
  pass.end();

  device.queue.submit([commandEncoder.finish()]);
  context.present?.(); // importante para este host iOS

  requestAnimationFrame(frame);
}
```

---

## Validación rápida (simulador)

1. `adapter` no nulo.
2. `device` no nulo.
3. `context.configure(...)` sin excepción.
4. loop de frames activo.
5. resize (rotación/cambio bounds) mantiene render.

Logs recomendados:
- `[smoke] adapter=ok`
- `[smoke] device=ok`
- `[smoke] configure=ok`
- `[smoke] frame=ok`
- `[smoke] resize=ok`

---

## Riesgos conocidos

1. Diferencia semántica browser vs host nativo en `present`.
2. Falta de algunos Web APIs fuera de WebGPU (`OffscreenCanvas`, `ImageData`, etc.) según librerías de terceros.
3. Sincronización de callbacks async si el dispatcher no reinyecta en el thread correcto.
4. Ajustes de `devicePixelRatio`/resize inconsistentes si host y shim no comparten la misma fuente de tamaño.
