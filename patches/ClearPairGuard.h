#pragma once
#include <cstdint>
namespace grfs_clear_pair {
inline bool Independent32bpp2x(uint32_t pitch,uint32_t depth_base,uint32_t color_base,
 uint32_t x,uint32_t y,uint32_t width,uint32_t height,
 uint32_t tile_width,uint32_t tile_height,uint32_t tile_count){
 if(!pitch||!width||!height||!tile_width||!tile_height)return false;
 uint64_t right=uint64_t(x)+width-1,bottom=uint64_t(y)+height-1;
 uint64_t first=(uint64_t(y)*2/tile_height)*pitch+x/tile_width;
 uint64_t end=(bottom*2/tile_height)*pitch+right/tile_width+1;
 uint64_t d0=depth_base+first,d1=depth_base+end,c0=color_base+first,c1=color_base+end;
 return d1<=tile_count&&c1<=tile_count&&(d1<=c0||c1<=d0);
}
}
