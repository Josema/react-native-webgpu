# WebGPU Core (RN-free)

Native WebGPU core based on Dawn with JSI bindings and a minimal native iOS example.

## Architecture

- `webgpu-core`
  - C++ WebGPU API wrappers (`GPU*`, `GPUCanvasContext`, descriptors)
  - JSI object model and async bridge
  - Host bootstrap API:
    - `rnwgpu::installWebGPU(jsi::Runtime&, WebGPUHostContext)`
    - `rnwgpu::createCanvasContext(WebGPUHostRuntime&, surfaceHandle, width, height)`
- `ios-native-example`
  - Native UIKit app (`CAMetalLayer`)
  - `ApplePlatformContext` (no React dependencies)
  - `MainQueueJSDispatcher` for JS-thread callback marshalling
  - `MetalSurfaceHost` for surface lifecycle (`attach/resize/detach`)

## Build (iOS Simulator)

```sh
npm run configure:ios
npm run build:ios
```

## Run (iPhone X simulator in this workspace)

```sh
npm run run:ios
```

## Smoke Validation

The app logs smoke checkpoints on launch:

- `[ios-native-example][smoke] adapter=ok device=ok configure=ok`
- `[ios-native-example][smoke] resize=ok`

These validate:

- `requestAdapter` path
- `requestDevice` path
- `configure/getCurrentTexture/present` path
- surface resize reconfiguration path

## Repository Layout

- `cpp/`: WebGPU core implementation
- `apple/`: Apple host adapters (`ApplePlatformContext`, dispatch/surface host)
- `webgpu-core/third_party/jsi`: vendored JSI
- `webgpu-core/third_party/jsc`: vendored JSCRuntime
- `ios-native-example/`: minimal native iOS app
