#pragma once

#include <functional>

namespace rnwgpu::host {

// Host-provided bridge that schedules work on the JavaScript runtime thread.
class JSDispatcher {
public:
  using Task = std::function<void()>;

  virtual ~JSDispatcher() = default;
  virtual void post(Task task) = 0;
};

} // namespace rnwgpu::host
