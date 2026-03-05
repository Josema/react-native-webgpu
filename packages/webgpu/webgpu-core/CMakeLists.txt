set(WEBGPU_CORE_SOURCES
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/dawn_logging.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/jsi/Promise.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/jsi/RuntimeAwareCache.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/jsi/RuntimeLifecycleMonitor.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/WebGPUHostRuntime.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/async/AsyncRunner.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/async/AsyncTaskHandle.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/async/JSIMicrotaskDispatcher.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPU.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPUAdapter.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPUBindGroup.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPUBuffer.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPUCanvasContext.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPUCommandEncoder.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPUComputePassEncoder.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPUComputePipeline.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPUDevice.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPUDeviceLostInfo.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPUQuerySet.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPUQueue.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPURenderBundleEncoder.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPURenderPassEncoder.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPURenderPipeline.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPUShaderModule.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPUSupportedLimits.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/GPUTexture.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/third_party/jsi/jsi/jsi.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/third_party/jsi/jsi/jsilib-posix.cpp
)

add_library(webgpu-core STATIC ${WEBGPU_CORE_SOURCES})

# Needed for target_compile_definitions used by jsi export macros.
target_compile_definitions(webgpu-core PRIVATE JSI_EXPORT=)

target_include_directories(webgpu-core
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/../cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/jsi
    ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu
    ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api
    ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/rnwgpu/api/descriptors
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/jsi
)

target_compile_options(webgpu-core PRIVATE
  $<$<COMPILE_LANGUAGE:CXX>:-fexceptions>
)

set_target_properties(webgpu-core PROPERTIES
  POSITION_INDEPENDENT_CODE ON
)
