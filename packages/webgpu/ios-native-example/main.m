#import <UIKit/UIKit.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>

#include <algorithm>
#include <chrono>
#include <memory>
#include <stdexcept>
#include <thread>

#include "ApplePlatformContext.h"
#include "MainQueueJSDispatcher.h"
#include "MetalSurfaceHost.h"
#include "WebGPUHostRuntime.h"
#include "api/GPUDevice.h"
#include "api/descriptors/GPUCanvasConfiguration.h"
#include "JSCRuntime.h"

namespace {

constexpr int kSurfaceId = 1;

wgpu::Adapter requestAdapterSync(wgpu::Instance instance) {
  std::atomic<bool> finished{false};
  wgpu::Adapter adapter = nullptr;

  wgpu::RequestAdapterOptions options{};
  options.backendType = wgpu::BackendType::Metal;

  instance.RequestAdapter(
      &options, wgpu::CallbackMode::AllowProcessEvents,
      [&finished, &adapter](wgpu::RequestAdapterStatus status,
                            wgpu::Adapter adapterResult,
                            wgpu::StringView message) {
        if (status == wgpu::RequestAdapterStatus::Success && adapterResult) {
          adapter = adapterResult;
        } else if (message.length > 0) {
          fprintf(stderr, "requestAdapter failed: %.*s\n",
                  (int)message.length, message.data);
        }
        finished.store(true, std::memory_order_release);
      });

  auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
  while (!finished.load(std::memory_order_acquire) &&
         std::chrono::steady_clock::now() < deadline) {
    instance.ProcessEvents();
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }

  return adapter;
}

wgpu::Device requestDeviceSync(wgpu::Adapter adapter) {
  std::atomic<bool> finished{false};
  wgpu::Device device = nullptr;

  wgpu::DeviceDescriptor descriptor{};
  adapter.RequestDevice(
      &descriptor, wgpu::CallbackMode::AllowProcessEvents,
      [&finished, &device](wgpu::RequestDeviceStatus status,
                           wgpu::Device deviceResult,
                           wgpu::StringView message) {
        if (status == wgpu::RequestDeviceStatus::Success && deviceResult) {
          device = deviceResult;
        } else if (message.length > 0) {
          fprintf(stderr, "requestDevice failed: %.*s\n", (int)message.length,
                  message.data);
        }
        finished.store(true, std::memory_order_release);
      });

  auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
  while (!finished.load(std::memory_order_acquire) &&
         std::chrono::steady_clock::now() < deadline) {
    adapter.GetInstance().ProcessEvents();
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }

  return device;
}

} // namespace

@interface WebGPURenderer : NSObject
@property(nonatomic, readonly, getter=isReady) BOOL ready;
- (instancetype)initWithLayer:(CAMetalLayer *)layer
                        width:(int)width
                       height:(int)height;
- (void)resizeWithWidth:(int)width height:(int)height;
- (void)drawFrame;
@end

@implementation WebGPURenderer {
  BOOL _ready;
  std::unique_ptr<facebook::jsi::Runtime> _runtime;
  std::shared_ptr<rnwgpu::WebGPUHostRuntime> _hostRuntime;
  std::shared_ptr<rnwgpu::MetalSurfaceHost> _surfaceHost;
  std::shared_ptr<rnwgpu::GPUCanvasContext> _canvasContext;
  std::shared_ptr<rnwgpu::GPUDevice> _deviceHost;

  wgpu::Adapter _adapter;
  wgpu::Device _device;
  wgpu::RenderPipeline _pipeline;
  wgpu::TextureFormat _format;
}

- (instancetype)initWithLayer:(CAMetalLayer *)layer
                        width:(int)width
                       height:(int)height {
  self = [super init];
  if (self) {
    _ready = NO;

    @try {
      _runtime = facebook::jsc::makeJSCRuntime();

      auto platformContext = std::make_shared<rnwgpu::ApplePlatformContext>();
      auto jsDispatcher = std::make_shared<rnwgpu::MainQueueJSDispatcher>();
      rnwgpu::WebGPUHostContext hostContext;
      hostContext.platformContext = platformContext;
      hostContext.jsDispatcher = jsDispatcher;
      _hostRuntime = rnwgpu::installWebGPU(*_runtime, std::move(hostContext));

      _surfaceHost = std::make_shared<rnwgpu::MetalSurfaceHost>(_hostRuntime);
      _surfaceHost->attachSurface(kSurfaceId, layer, width, height);

      _canvasContext = _hostRuntime->createCanvasContext(kSurfaceId, width, height);

      _adapter = requestAdapterSync(_hostRuntime->instance());
      if (_adapter == nullptr) {
        throw std::runtime_error("adapter == null");
      }

      _device = requestDeviceSync(_adapter);
      if (_device == nullptr) {
        throw std::runtime_error("device == null");
      }

      _deviceHost = std::make_shared<rnwgpu::GPUDevice>(
          _device, _hostRuntime->gpu()->getAsyncRunner(), "ios-native-example");
      _format = _hostRuntime->gpu()->getPreferredCanvasFormat();

      auto config = std::make_shared<rnwgpu::GPUCanvasConfiguration>();
      config->device = _deviceHost;
      config->format = _format;
      config->usage = static_cast<double>(wgpu::TextureUsage::RenderAttachment);
      config->alphaMode = wgpu::CompositeAlphaMode::Opaque;
      _canvasContext->configure(config);

      const char *shaderSource = R"(
@vertex
fn vs_main(@builtin(vertex_index) vertexIndex : u32) -> @builtin(position) vec4<f32> {
  var pos = array<vec2<f32>, 3>(
    vec2<f32>(0.0, 0.5),
    vec2<f32>(-0.5, -0.5),
    vec2<f32>(0.5, -0.5)
  );
  let xy = pos[vertexIndex];
  return vec4<f32>(xy, 0.0, 1.0);
}

@fragment
fn fs_main() -> @location(0) vec4<f32> {
  return vec4<f32>(0.95, 0.25, 0.18, 1.0);
}
)";

      wgpu::ShaderSourceWGSL wgslDesc{};
      wgslDesc.code = shaderSource;
      wgpu::ShaderModuleDescriptor shaderDesc{};
      shaderDesc.nextInChain = &wgslDesc;
      auto shader = _device.CreateShaderModule(&shaderDesc);

      wgpu::ColorTargetState colorTarget{};
      colorTarget.format = _format;

      wgpu::FragmentState fragment{};
      fragment.module = shader;
      fragment.entryPoint = "fs_main";
      fragment.targetCount = 1;
      fragment.targets = &colorTarget;

      wgpu::RenderPipelineDescriptor pipelineDesc{};
      pipelineDesc.vertex.module = shader;
      pipelineDesc.vertex.entryPoint = "vs_main";
      pipelineDesc.primitive.topology = wgpu::PrimitiveTopology::TriangleList;
      pipelineDesc.primitive.cullMode = wgpu::CullMode::None;
      pipelineDesc.fragment = &fragment;
      pipelineDesc.multisample.count = 1;

      _pipeline = _device.CreateRenderPipeline(&pipelineDesc);
      _ready = YES;

      [self resizeWithWidth:std::max(1, width / 2)
                     height:std::max(1, height / 2)];
      [self drawFrame];
      [self resizeWithWidth:width height:height];
      [self drawFrame];

      NSLog(@"[ios-native-example][smoke] adapter=%@ device=%@ configure=%@",
            _adapter != nullptr ? @"ok" : @"null",
            _device != nullptr ? @"ok" : @"null", _ready ? @"ok" : @"fail");
      NSLog(@"[ios-native-example][smoke] resize=ok");
    } @catch (NSException *exception) {
      NSLog(@"[ios-native-example] Exception: %@", exception);
      _ready = NO;
    } @catch (...) {
      _ready = NO;
    }
  }

  return self;
}

- (BOOL)isReady {
  return _ready;
}

- (void)resizeWithWidth:(int)width height:(int)height {
  if (!_ready) {
    return;
  }
  _surfaceHost->resizeSurface(kSurfaceId, width, height);
  _canvasContext->getCanvas()->setWidth(width);
  _canvasContext->getCanvas()->setHeight(height);
}

- (void)drawFrame {
  if (!_ready) {
    return;
  }

  auto texture = _canvasContext->getCurrentTexture();
  auto textureView = texture->get().CreateView();

  wgpu::RenderPassColorAttachment colorAttachment{};
  colorAttachment.view = textureView;
  colorAttachment.clearValue = {0.10, 0.11, 0.14, 1.0};
  colorAttachment.loadOp = wgpu::LoadOp::Clear;
  colorAttachment.storeOp = wgpu::StoreOp::Store;

  wgpu::RenderPassDescriptor renderPassDesc{};
  renderPassDesc.colorAttachmentCount = 1;
  renderPassDesc.colorAttachments = &colorAttachment;

  wgpu::CommandEncoderDescriptor encoderDesc{};
  auto encoder = _device.CreateCommandEncoder(&encoderDesc);
  auto pass = encoder.BeginRenderPass(&renderPassDesc);
  pass.SetPipeline(_pipeline);
  pass.Draw(3);
  pass.End();

  auto commands = encoder.Finish();
  _device.GetQueue().Submit(1, &commands);

  _canvasContext->present();
}

@end

@interface WebGPUMetalView : UIView
@end

@implementation WebGPUMetalView
+ (Class)layerClass {
  return [CAMetalLayer class];
}
@end

@interface WebGPUViewController : UIViewController
@end

@interface WebGPUViewController ()
@property(nonatomic, strong) WebGPUMetalView *metalView;
@property(nonatomic, strong) WebGPURenderer *renderer;
@property(nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation WebGPUViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.view.backgroundColor = UIColor.blackColor;

  self.metalView = [[WebGPUMetalView alloc] initWithFrame:self.view.bounds];
  self.metalView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                    UIViewAutoresizingFlexibleHeight;
  [self.view addSubview:self.metalView];

  CAMetalLayer *metalLayer = (CAMetalLayer *)self.metalView.layer;
  metalLayer.contentsScale = UIScreen.mainScreen.scale;

  CGSize size = self.metalView.bounds.size;
  int width = (int)lrint(size.width * metalLayer.contentsScale);
  int height = (int)lrint(size.height * metalLayer.contentsScale);
  self.renderer = [[WebGPURenderer alloc] initWithLayer:metalLayer
                                                   width:width
                                                  height:height];

  self.displayLink =
      [CADisplayLink displayLinkWithTarget:self selector:@selector(onFrame)];
  [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop
                         forMode:NSRunLoopCommonModes];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  CAMetalLayer *metalLayer = (CAMetalLayer *)self.metalView.layer;
  metalLayer.contentsScale = UIScreen.mainScreen.scale;
  CGSize size = self.metalView.bounds.size;
  int width = (int)lrint(size.width * metalLayer.contentsScale);
  int height = (int)lrint(size.height * metalLayer.contentsScale);
  [self.renderer resizeWithWidth:width height:height];
}

- (void)onFrame {
  [self.renderer drawFrame];
}

- (void)dealloc {
  [self.displayLink invalidate];
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  (void)application;
  (void)launchOptions;

  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = [WebGPUViewController new];
  [self.window makeKeyAndVisible];
  return YES;
}

@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil,
                             NSStringFromClass([AppDelegate class]));
  }
}
