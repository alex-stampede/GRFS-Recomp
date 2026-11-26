#include <functional>
#include <fstream>
#include <iostream>
#include <vector>
#include <rex/filesystem/devices/stfs_container_device.h>
#include <rex/filesystem/entry.h>
#include <rex/filesystem/file.h>

int main(int argc, char** argv) {
  if (argc != 3) return 2;
  rex::filesystem::StfsContainerDevice package("update:", argv[1]);
  if (!package.Initialize()) return 3;
  auto* root = package.ResolvePath("");
  if (!root) return 4;
  std::filesystem::create_directories(argv[2]);
  std::function<bool(rex::filesystem::Entry*,std::filesystem::path)> extract;
  extract = [&](auto* dir, auto dest) {
    std::filesystem::create_directories(dest);
    for (const auto& entry : dir->children()) {
      const std::filesystem::path name(entry->name());
      if (name.empty() || name != name.filename() || name=="." || name=="..") return false;
      if (!entry->children().empty()) {
        if (!extract(entry.get(), dest/name)) return false;
        continue;
      }
      rex::filesystem::File* file = nullptr;
      if (entry->Open(rex::filesystem::FileAccess::kFileReadData, &file)) return false;
      std::vector<uint8_t> bytes(entry->size());
      size_t length=0;
      const auto status=file->ReadSync(bytes,0,&length);
      file->Destroy();
      if (status || length!=bytes.size()) return false;
      std::ofstream output(dest/name,std::ios::binary);
      output.write(reinterpret_cast<const char*>(bytes.data()),length);
      if (!output) return false;
    }
    return true;
  };
  return extract(root,argv[2]) ? 0 : 6;
}
