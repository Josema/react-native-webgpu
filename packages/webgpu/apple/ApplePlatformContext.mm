#include "ApplePlatformContext.h"
#import "RNWGUIKit.h"

#include <TargetConditionals.h>
#include <utility>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

namespace rnwgpu {

void checkIfUsingSimulatorWithAPIValidation() {
#if TARGET_OS_SIMULATOR
  NSDictionary *environment = [[NSProcessInfo processInfo] environment];
  NSString *metalDeviceWrapperType = environment[@"METAL_DEVICE_WRAPPER_TYPE"];

  if ([metalDeviceWrapperType isEqualToString:@"1"]) {
    throw std::runtime_error(
        "To run this WebGPU project on the iOS simulator, disable Metal API "
        "validation in the scheme settings (uncheck 'Metal Validation').");
  }
#endif
}

ApplePlatformContext::ApplePlatformContext(BlobResolver blobResolver)
    : _blobResolver(std::move(blobResolver)) {
  checkIfUsingSimulatorWithAPIValidation();
}

wgpu::Surface ApplePlatformContext::makeSurface(wgpu::Instance instance,
                                                void *surface, int width,
                                                int height) {
  wgpu::SurfaceSourceMetalLayer metalSurfaceDesc;
  metalSurfaceDesc.layer = surface;
  wgpu::SurfaceDescriptor surfaceDescriptor;
  surfaceDescriptor.nextInChain = &metalSurfaceDesc;
  return instance.CreateSurface(&surfaceDescriptor);
}

ImageData ApplePlatformContext::createImageBitmap(std::string blobId,
                                                  double offset, double size) {
  if (_blobResolver == nullptr) {
    throw std::runtime_error(
        "Blob resolver is not configured for ApplePlatformContext");
  }

  auto resolved = _blobResolver(blobId, static_cast<size_t>(offset),
                                static_cast<size_t>(size));
  if (!resolved.has_value()) {
    throw std::runtime_error("Couldn't retrieve blob data");
  }

  return createImageBitmapFromData(*resolved);
}

void ApplePlatformContext::createImageBitmapAsync(
    std::string blobId, double offset, double size,
    std::function<void(ImageData)> onSuccess,
    std::function<void(std::string)> onError) {
  if (_blobResolver == nullptr) {
    onError("Blob resolver is not configured for ApplePlatformContext");
    return;
  }

  auto resolved = _blobResolver(blobId, static_cast<size_t>(offset),
                                static_cast<size_t>(size));
  if (!resolved.has_value()) {
    onError("Couldn't retrieve blob data");
    return;
  }

  createImageBitmapFromDataAsync(*resolved, std::move(onSuccess),
                                 std::move(onError));
}

ImageData ApplePlatformContext::createImageBitmapFromData(
    std::span<const uint8_t> data) {
  // This avoids a copy by assuming the UIImage/NSImage constructors
  // decode `nsData` eagerly before the memory for the wrapped `data`
  // is freed.
  //
  // Since we get the `CGImageRef` from `image` and then throw
  // it away, that's a fairly safe assumption.
  NSData *nsData = [NSData dataWithBytesNoCopy:const_cast<uint8_t *>(data.data())
                                        length:data.size()
                                  freeWhenDone:NO];

#if !TARGET_OS_OSX
  UIImage *image = [UIImage imageWithData:nsData];
#else
  NSImage *image = [[NSImage alloc] initWithData:nsData];
#endif
  if (!image) {
    throw std::runtime_error("Couldn't decode image");
  }

#if !TARGET_OS_OSX
  CGImageRef cgImage = image.CGImage;
#else
  CGImageRef cgImage = [image CGImageForProposedRect:NULL
                                             context:NULL
                                               hints:NULL];
#endif
  size_t width = CGImageGetWidth(cgImage);
  size_t height = CGImageGetHeight(cgImage);
  size_t bitsPerComponent = 8;
  size_t bytesPerRow = width * 4;

  ImageData result;
  result.width = static_cast<int>(width);
  result.height = static_cast<int>(height);
  result.data.resize(height * bytesPerRow);
  result.format = wgpu::TextureFormat::RGBA8Unorm;

  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(
      result.data.data(), width, height, bitsPerComponent, bytesPerRow,
      colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);

  CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);

  CGContextRelease(context);
  CGColorSpaceRelease(colorSpace);

  return result;
}

void ApplePlatformContext::createImageBitmapFromDataAsync(
    std::span<const uint8_t> data, std::function<void(ImageData)> onSuccess,
    std::function<void(std::string)> onError) {
  // Copy span data into shared_ptr so the dispatch_async block owns the memory
  auto ownedData =
      std::make_shared<std::vector<uint8_t>>(data.begin(), data.end());

  dispatch_async(
      dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
          try {
            auto result = createImageBitmapFromData(*ownedData);
            onSuccess(std::move(result));
          } catch (const std::exception &e) {
            onError(e.what());
          }
        }
      });
}

} // namespace rnwgpu
