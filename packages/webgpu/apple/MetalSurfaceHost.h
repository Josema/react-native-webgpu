#pragma once

#import <QuartzCore/CAMetalLayer.h>

#include <memory>

#include "WebGPUHostRuntime.h"
#include "host/SurfaceLifecycle.h"

namespace rnwgpu {

class MetalSurfaceHost : public host::SurfaceLifecycle {
public:
  explicit MetalSurfaceHost(std::shared_ptr<WebGPUHostRuntime> runtime);

  void attachSurface(int surfaceId, CAMetalLayer *layer, int width, int height);

  void attachSurface(int surfaceId, void *nativeSurface, int width,
                     int height) override;
  void resizeSurface(int surfaceId, int width, int height) override;
  void detachSurface(int surfaceId) override;

private:
  std::shared_ptr<WebGPUHostRuntime> _runtime;
};

} // namespace rnwgpu
