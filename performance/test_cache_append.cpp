#include <cassert>
#include <cstdio>
#include <cstring>
#include <filesystem>
int main() {
 auto path=std::filesystem::temp_directory_path()/"grfs-cache-regression.bin";
 { FILE* f=fopen(path.c_str(),"wb"); assert(f); assert(fwrite("XEPSrecord1",1,11,f)==11); fclose(f); }
 for (int pass=0;pass<2;++pass) {
  FILE* f=fopen(path.c_str(),"a+b"); assert(f);
  rewind(f); char header[4]; assert(fread(header,1,4,f)==4); assert(!memcmp(header,"XEPS",4));
  assert(fwrite("more",1,4,f)==4); fclose(f);
  assert(std::filesystem::file_size(path)==15+pass*4);
 }
 std::filesystem::remove(path);
 puts("PASS: append-mode cache header survives two reopen/read/append sessions");
}
