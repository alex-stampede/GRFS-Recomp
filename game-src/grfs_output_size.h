#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <string_view>
#include <utility>
namespace grfs {
inline std::pair<uint32_t,uint32_t> LimitOutput(uint32_t w, uint32_t h, std::string_view limit) {
  uint32_t caph = limit == "720" ? 720 : limit == "900" ? 900 : limit == "1080" ? 1080 : 0;
  if (!caph || !w || !h) return {w,h};
  const double scale = std::min({1.0, double(caph * 16 / 9) / w, double(caph) / h});
  return {std::max(1u, uint32_t(std::floor(w * scale))),
          std::max(1u, uint32_t(std::floor(h * scale)))};
}
}
