#pragma once

namespace rnwgpu::host {

class SurfaceLifecycle {
public:
  virtual ~SurfaceLifecycle() = default;

  virtual void attachSurface(int surfaceHandle, void *nativeSurface,
                             int width, int height) = 0;
  virtual void resizeSurface(int surfaceHandle, int width, int height) = 0;
  virtual void detachSurface(int surfaceHandle) = 0;
};

} // namespace rnwgpu::host
