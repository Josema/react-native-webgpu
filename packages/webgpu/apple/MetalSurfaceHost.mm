#include "MetalSurfaceHost.h"

#include <stdexcept>

namespace rnwgpu {

MetalSurfaceHost::MetalSurfaceHost(std::shared_ptr<WebGPUHostRuntime> runtime)
    : _runtime(std::move(runtime)) {
  if (_runtime == nullptr) {
    throw std::runtime_error("MetalSurfaceHost requires WebGPUHostRuntime");
  }
}

void MetalSurfaceHost::attachSurface(int surfaceId, CAMetalLayer *layer,
                                     int width, int height) {
  void *nativeSurface = (__bridge void *)layer;
  attachSurface(surfaceId, nativeSurface, width, height);
}

void MetalSurfaceHost::attachSurface(int surfaceId, void *nativeSurface,
                                     int width, int height) {
  auto &registry = rnwgpu::SurfaceRegistry::getInstance();
  auto gpu = _runtime->instance();
  auto surface =
      _runtime->platformContext()->makeSurface(gpu, nativeSurface, width, height);
  registry.getSurfaceInfoOrCreate(surfaceId, gpu, width, height)
      ->switchToOnscreen(nativeSurface, surface);
}

void MetalSurfaceHost::resizeSurface(int surfaceId, int width, int height) {
  auto &registry = rnwgpu::SurfaceRegistry::getInstance();
  auto info = registry.getSurfaceInfo(surfaceId);
  if (info != nullptr) {
    info->resize(width, height);
  }
}

void MetalSurfaceHost::detachSurface(int surfaceId) {
  auto &registry = rnwgpu::SurfaceRegistry::getInstance();
  registry.removeSurfaceInfo(surfaceId);
}

} // namespace rnwgpu
