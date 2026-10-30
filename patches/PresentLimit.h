#pragma once
#include <cstdint>
namespace grfs::present {
inline unsigned ValidLimit(int value){return value==30||value==60||value==120?unsigned(value):0;}
inline uint64_t Delay(uint64_t now,uint64_t last,unsigned fps){
 if(!fps||!last||now<last)return 0;
 const uint64_t period=(1000000000ull+fps-1)/fps;
 const uint64_t elapsed=now-last;
 return elapsed<period?period-elapsed:0;
}
}
