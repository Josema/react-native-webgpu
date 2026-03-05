#include "MainQueueJSDispatcher.h"

#import <Foundation/Foundation.h>

namespace rnwgpu {

void MainQueueJSDispatcher::post(Task task) {
  dispatch_async(dispatch_get_main_queue(), ^{
    task();
  });
}

} // namespace rnwgpu
