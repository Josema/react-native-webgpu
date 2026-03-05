#include "WebGPUHostRuntime.h"

#include "GPU.h"
#include "NativeObject.h"
#include "api/WebGPUHostObject.h"

// GPU API classes (for instanceof support)
#include "GPUAdapter.h"
#include "GPUAdapterInfo.h"
#include "GPUBindGroup.h"
#include "GPUBindGroupLayout.h"
#include "GPUBuffer.h"
#include "GPUCanvasContext.h"
#include "GPUCommandBuffer.h"
#include "GPUCommandEncoder.h"
#include "GPUCompilationInfo.h"
#include "GPUCompilationMessage.h"
#include "GPUComputePassEncoder.h"
#include "GPUComputePipeline.h"
#include "GPUDevice.h"
#include "GPUDeviceLostInfo.h"
#include "GPUError.h"
#include "GPUExternalTexture.h"
#include "GPUInternalError.h"
#include "GPUOutOfMemoryError.h"
#include "GPUPipelineLayout.h"
#include "GPUQuerySet.h"
#include "GPUQueue.h"
#include "GPURenderBundle.h"
#include "GPURenderBundleEncoder.h"
#include "GPURenderPassEncoder.h"
#include "GPURenderPipeline.h"
#include "GPUSampler.h"
#include "GPUShaderModule.h"
#include "GPUSupportedLimits.h"
#include "GPUTexture.h"
#include "GPUTextureView.h"
#include "GPUUncapturedErrorEvent.h"
#include "GPUValidationError.h"

// Enums
#include "GPUBufferUsage.h"
#include "GPUColorWrite.h"
#include "GPUMapMode.h"
#include "GPUShaderStage.h"
#include "GPUTextureUsage.h"

#include <memory>
#include <stdexcept>
#include <utility>

namespace rnwgpu {

WebGPUHostRuntime::WebGPUHostRuntime(jsi::Runtime *jsRuntime,
                                     WebGPUHostContext hostContext)
    : _jsRuntime(jsRuntime), _jsDispatcher(std::move(hostContext.jsDispatcher)),
      _platformContext(std::move(hostContext.platformContext)) {
  if (_jsRuntime == nullptr) {
    throw std::runtime_error("WebGPUHostRuntime requires a valid jsi::Runtime");
  }
  if (_platformContext == nullptr) {
    throw std::runtime_error("WebGPUHostRuntime requires a PlatformContext");
  }
  if (_jsDispatcher == nullptr) {
    throw std::runtime_error("WebGPUHostRuntime requires a JSDispatcher");
  }

  // Register main runtime for RuntimeAwareCache
  BaseRuntimeAwareCache::setMainJsRuntime(_jsRuntime);

  auto gpu = std::make_shared<GPU>(*_jsRuntime);
  _gpuHost = gpu;
  auto webGPUHost =
      std::make_shared<WebGPUHostObject>(gpu, _platformContext, _jsDispatcher);
  _gpu = gpu->get();
  _jsRuntime->global().setProperty(*_jsRuntime, "WebGPUHost",
                                   WebGPUHostObject::create(*_jsRuntime,
                                                            webGPUHost));

  // Install constructors for instanceof support
  GPU::installConstructor(*_jsRuntime);
  GPUAdapter::installConstructor(*_jsRuntime);
  GPUAdapterInfo::installConstructor(*_jsRuntime);
  GPUBindGroup::installConstructor(*_jsRuntime);
  GPUBindGroupLayout::installConstructor(*_jsRuntime);
  GPUBuffer::installConstructor(*_jsRuntime);
  GPUCanvasContext::installConstructor(*_jsRuntime);
  GPUCommandBuffer::installConstructor(*_jsRuntime);
  GPUCommandEncoder::installConstructor(*_jsRuntime);
  GPUCompilationInfo::installConstructor(*_jsRuntime);
  GPUCompilationMessage::installConstructor(*_jsRuntime);
  GPUComputePassEncoder::installConstructor(*_jsRuntime);
  GPUComputePipeline::installConstructor(*_jsRuntime);
  GPUDevice::installConstructor(*_jsRuntime);
  GPUDeviceLostInfo::installConstructor(*_jsRuntime);
  GPUError::installConstructor(*_jsRuntime);
  GPUExternalTexture::installConstructor(*_jsRuntime);
  GPUInternalError::installConstructor(*_jsRuntime);
  GPUOutOfMemoryError::installConstructor(*_jsRuntime);
  GPUValidationError::installConstructor(*_jsRuntime);
  GPUUncapturedErrorEvent::installConstructor(*_jsRuntime);
  GPUPipelineLayout::installConstructor(*_jsRuntime);
  GPUQuerySet::installConstructor(*_jsRuntime);
  GPUQueue::installConstructor(*_jsRuntime);
  GPURenderBundle::installConstructor(*_jsRuntime);
  GPURenderBundleEncoder::installConstructor(*_jsRuntime);
  GPURenderPassEncoder::installConstructor(*_jsRuntime);
  GPURenderPipeline::installConstructor(*_jsRuntime);
  GPUSampler::installConstructor(*_jsRuntime);
  GPUShaderModule::installConstructor(*_jsRuntime);
  GPUSupportedLimits::installConstructor(*_jsRuntime);
  GPUTexture::installConstructor(*_jsRuntime);
  GPUTextureView::installConstructor(*_jsRuntime);

  _jsRuntime->global().setProperty(*_jsRuntime, "GPUBufferUsage",
                                   GPUBufferUsage::create(*_jsRuntime));
  _jsRuntime->global().setProperty(*_jsRuntime, "GPUColorWrite",
                                   GPUColorWrite::create(*_jsRuntime));
  _jsRuntime->global().setProperty(*_jsRuntime, "GPUMapMode",
                                   GPUMapMode::create(*_jsRuntime));
  _jsRuntime->global().setProperty(*_jsRuntime, "GPUShaderStage",
                                   GPUShaderStage::create(*_jsRuntime));
  _jsRuntime->global().setProperty(*_jsRuntime, "GPUTextureUsage",
                                   GPUTextureUsage::create(*_jsRuntime));

  installWebGPUWorkletHelpers(*_jsRuntime);
}

void WebGPUHostRuntime::installWebGPUWorkletHelpers(jsi::Runtime &runtime) {
  // __webgpuIsWebGPUObject - checks if a value is a WebGPU NativeObject
  auto isWebGPUObjectFunc = jsi::Function::createFromHostFunction(
      runtime, jsi::PropNameID::forUtf8(runtime, "__webgpuIsWebGPUObject"), 1,
      [](jsi::Runtime &rt, const jsi::Value & /*thisVal*/,
         const jsi::Value *args, size_t count) -> jsi::Value {
        if (count < 1 || !args[0].isObject()) {
          return jsi::Value(false);
        }
        auto obj = args[0].getObject(rt);

        if (!obj.hasNativeState(rt)) {
          return jsi::Value(false);
        }

        auto objectCtor = rt.global().getPropertyAsObject(rt, "Object");
        auto getPrototypeOf =
            objectCtor.getPropertyAsFunction(rt, "getPrototypeOf");
        auto proto = getPrototypeOf.call(rt, obj);

        if (!proto.isObject()) {
          return jsi::Value(false);
        }

        auto protoObj = proto.getObject(rt);
        auto symbolCtor = rt.global().getPropertyAsObject(rt, "Symbol");
        auto toStringTag = symbolCtor.getProperty(rt, "toStringTag");
        if (toStringTag.isUndefined()) {
          return jsi::Value(false);
        }

        auto getOwnPropertyDescriptor =
            objectCtor.getPropertyAsFunction(rt, "getOwnPropertyDescriptor");
        auto desc = getOwnPropertyDescriptor.call(rt, protoObj, toStringTag);
        return jsi::Value(desc.isObject());
      });
  runtime.global().setProperty(runtime, "__webgpuIsWebGPUObject",
                               std::move(isWebGPUObjectFunc));

  // __webgpuBox - boxes a WebGPU object for Worklets serialization
  auto boxFunc = jsi::Function::createFromHostFunction(
      runtime, jsi::PropNameID::forUtf8(runtime, "__webgpuBox"), 1,
      [](jsi::Runtime &rt, const jsi::Value & /*thisVal*/,
         const jsi::Value *args, size_t count) -> jsi::Value {
        if (count < 1 || !args[0].isObject()) {
          throw jsi::JSError(rt,
                             "__webgpuBox() requires a WebGPU object argument");
        }

        auto obj = args[0].getObject(rt);

        if (!obj.hasNativeState(rt)) {
          throw jsi::JSError(
              rt, "Object has no native state - not a WebGPU object");
        }

        auto objectCtor = rt.global().getPropertyAsObject(rt, "Object");
        auto getPrototypeOf =
            objectCtor.getPropertyAsFunction(rt, "getPrototypeOf");
        auto proto = getPrototypeOf.call(rt, obj);

        std::string brand;
        if (proto.isObject()) {
          auto protoObj = proto.getObject(rt);
          auto symbolCtor = rt.global().getPropertyAsObject(rt, "Symbol");
          auto toStringTag = symbolCtor.getProperty(rt, "toStringTag");
          if (!toStringTag.isUndefined()) {
            auto getOwnPropertyDescriptor = objectCtor.getPropertyAsFunction(
                rt, "getOwnPropertyDescriptor");
            auto desc =
                getOwnPropertyDescriptor.call(rt, protoObj, toStringTag);
            if (desc.isObject()) {
              auto descObj = desc.getObject(rt);
              auto value = descObj.getProperty(rt, "value");
              if (value.isString()) {
                brand = value.getString(rt).utf8(rt);
              }
            }
          }
        }

        if (brand.empty()) {
          throw jsi::JSError(rt, "Cannot determine WebGPU object type - no "
                                 "Symbol.toStringTag found");
        }

        auto nativeState = obj.getNativeState(rt);
        auto boxed = std::make_shared<BoxedWebGPUObject>(nativeState, brand);
        return jsi::Object::createFromHostObject(rt, boxed);
      });
  runtime.global().setProperty(runtime, "__webgpuBox", std::move(boxFunc));
}

WebGPUHostRuntime::~WebGPUHostRuntime() {
  _jsRuntime = nullptr;
  _gpuHost = nullptr;
  _jsDispatcher = nullptr;
}

std::shared_ptr<GPUCanvasContext>
WebGPUHostRuntime::createCanvasContext(int surfaceHandle, int width,
                                       int height) {
  if (_gpuHost == nullptr) {
    throw std::runtime_error("WebGPUHostRuntime is not initialized");
  }
  return std::make_shared<GPUCanvasContext>(_gpuHost, surfaceHandle, width,
                                            height);
}

std::shared_ptr<Canvas> WebGPUHostRuntime::getNativeSurface(int surfaceHandle) {
  auto &registry = rnwgpu::SurfaceRegistry::getInstance();
  auto info = registry.getSurfaceInfo(surfaceHandle);
  if (info == nullptr) {
    return std::make_shared<Canvas>(nullptr, 0, 0);
  }
  auto nativeInfo = info->getNativeInfo();
  return std::make_shared<Canvas>(nativeInfo.nativeSurface, nativeInfo.width,
                                  nativeInfo.height);
}

std::shared_ptr<WebGPUHostRuntime>
installWebGPU(jsi::Runtime &runtime, WebGPUHostContext hostContext) {
  return std::make_shared<WebGPUHostRuntime>(&runtime, std::move(hostContext));
}

std::shared_ptr<GPUCanvasContext>
createCanvasContext(WebGPUHostRuntime &runtime, int surfaceHandle, int width,
                    int height) {
  return runtime.createCanvasContext(surfaceHandle, width, height);
}

} // namespace rnwgpu
