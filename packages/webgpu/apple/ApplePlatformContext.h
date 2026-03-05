#pragma once

#include "PlatformContext.h"
#include <optional>
#include <string>
#include <vector>

namespace rnwgpu {

class ApplePlatformContext : public PlatformContext {
public:
  using BlobResolver =
      std::function<std::optional<std::vector<uint8_t>>(
          const std::string &blobId, size_t offset, size_t size)>;

  explicit ApplePlatformContext(BlobResolver blobResolver = nullptr);
  ~ApplePlatformContext() = default;

  wgpu::Surface makeSurface(wgpu::Instance instance, void *surface, int width,
                            int height) override;

  ImageData createImageBitmap(std::string blobId, double offset,
                              double size) override;

  void createImageBitmapAsync(
      std::string blobId, double offset, double size,
      std::function<void(ImageData)> onSuccess,
      std::function<void(std::string)> onError) override;

  ImageData createImageBitmapFromData(std::span<const uint8_t> data) override;

  void createImageBitmapFromDataAsync(
      std::span<const uint8_t> data, std::function<void(ImageData)> onSuccess,
      std::function<void(std::string)> onError) override;

private:
  BlobResolver _blobResolver;
};

} // namespace rnwgpu
