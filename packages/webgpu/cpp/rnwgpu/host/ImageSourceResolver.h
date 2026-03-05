#pragma once

#include <cstddef>
#include <optional>
#include <string>
#include <vector>

namespace rnwgpu::host {

class ImageSourceResolver {
public:
  virtual ~ImageSourceResolver() = default;

  virtual std::optional<std::vector<uint8_t>> resolveBlob(
      const std::string &blobId, size_t offset, size_t size) = 0;
};

} // namespace rnwgpu::host
