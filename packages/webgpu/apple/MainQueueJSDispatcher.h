#pragma once

#include "host/JSDispatcher.h"

namespace rnwgpu {

class MainQueueJSDispatcher final : public host::JSDispatcher {
public:
  MainQueueJSDispatcher() = default;
  ~MainQueueJSDispatcher() override = default;

  void post(Task task) override;
};

} // namespace rnwgpu
