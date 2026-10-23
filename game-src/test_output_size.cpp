#include "grfs_output_size.h"
#include <cassert>
int main() {
 using grfs::LimitOutput;
 assert((LimitOutput(2560,1440,"1080") == std::pair<uint32_t,uint32_t>{1920,1080}));
 assert((LimitOutput(3420,2148,"1080") == std::pair<uint32_t,uint32_t>{1719,1080}));
 assert((LimitOutput(1920,1080,"720") == std::pair<uint32_t,uint32_t>{1280,720}));
 assert((LimitOutput(1920,1080,"900") == std::pair<uint32_t,uint32_t>{1600,900}));
 assert((LimitOutput(800,600,"1080") == std::pair<uint32_t,uint32_t>{800,600}));
 assert((LimitOutput(0,0,"1080") == std::pair<uint32_t,uint32_t>{0,0}));
 assert((LimitOutput(3420,2148,"native") == std::pair<uint32_t,uint32_t>{3420,2148}));
 assert((LimitOutput(3420,2148,"invalid") == std::pair<uint32_t,uint32_t>{3420,2148}));
}
