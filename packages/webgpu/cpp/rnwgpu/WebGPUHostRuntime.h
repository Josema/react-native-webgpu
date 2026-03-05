#pragma once

#include <memory>

#include "PlatformContext.h"
#include "SurfaceRegistry.h"
#include "api/GPU.h"
#include "api/Canvas.h"
#include "api/GPUCanvasContext.h"
#include "host/JSDispatcher.h"

namespace facebook {
namespace jsi {
class Runtime;
} // namespace jsi
} // namespace facebook

namespace rnwgpu {

namespace jsi = facebook::jsi;

struct WebGPUHostContext {
  std::shared_ptr<PlatformContext> platformContext;
  std::shared_ptr<host::JSDispatcher> jsDispatcher;
};

class WebGPUHostRuntime {
public:
  WebGPUHostRuntime(jsi::Runtime *jsRuntime, WebGPUHostContext hostContext);
  ~WebGPUHostRuntime();

  static void installWebGPUWorkletHelpers(jsi::Runtime &runtime);

  std::shared_ptr<GPUCanvasContext> createCanvasContext(int surfaceHandle,
                                                        int width,
                                                        int height);

  std::shared_ptr<Canvas> getNativeSurface(int surfaceHandle);

  std::shared_ptr<GPU> gpu() const { return _gpuHost; }

  std::shared_ptr<PlatformContext> platformContext() const {
    return _platformContext;
  }

  wgpu::Instance instance() const { return _gpu; }

private:
  jsi::Runtime *_jsRuntime;
  std::shared_ptr<host::JSDispatcher> _jsDispatcher;
  std::shared_ptr<GPU> _gpuHost;

public:
  wgpu::Instance _gpu;
  std::shared_ptr<PlatformContext> _platformContext;
};

std::shared_ptr<WebGPUHostRuntime>
installWebGPU(jsi::Runtime &runtime, WebGPUHostContext hostContext);

std::shared_ptr<GPUCanvasContext>
createCanvasContext(WebGPUHostRuntime &runtime, int surfaceHandle, int width,
                    int height);

} // namespace rnwgpu
