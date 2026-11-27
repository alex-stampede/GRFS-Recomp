#include <filesystem>
#include <iostream>
#include <set>
#include <vector>

#include <rex/filesystem/devices/stfs_container_device.h>
#include <rex/filesystem/vfs.h>
#include <rex/kernel/init.h>
#include <rex/runtime.h>
#include <rex/system/kernel_state.h>
#include <rex/system/xam/content_device.h>
#include <rex/system/xam/content_manager.h>

int main(int argc, char** argv) {
  if (argc < 4) return 2;
  using rex::system::XContentType;
  constexpr uint32_t title_id = 0x55530833;
  constexpr auto marketplace = XContentType::kMarketplaceContent;
  std::vector<std::filesystem::path> packages;
  std::set<std::string> ids;
  for (int i = 3; i < argc; ++i) {
    const std::filesystem::path path(argv[i]);
    const std::string id = path.filename().string();
    const auto header = rex::filesystem::StfsContainerDevice::ReadPackageHeader(path);
    if (id.size() != sizeof(rex::system::xam::XCONTENT_DATA::file_name_raw) || id.find_first_not_of("0123456789ABCDEF") != std::string::npos ||
        !ids.insert(id).second || !header ||
        header->metadata.execution_info.title_id != title_id ||
        header->metadata.content_type.get() != marketplace) {
      std::cerr << "Unexpected STFS package: " << path << '\n';
      return 3;
    }
    packages.push_back(path);
  }

  rex::Runtime runtime(argv[1], argv[2]);
  if (runtime.Setup({.kernel_init = rex::kernel::InitializeKernel, .tool_mode = true}) != 0 ||
      runtime.LoadXexImage("game:\\Default.xex") != 0 ||
      runtime.kernel_state()->title_id() != title_id) {
    return 4;
  }
  auto* manager = runtime.kernel_state()->content_manager();
  unsigned installed = 0;
  for (const auto& path : packages) {
    if (const auto status = manager->InstallContent(path); status != 0) {
      std::cerr << "InstallContent failed: " << path << " status=" << status << '\n';
      return 5;
    }
    std::cout << "DLC_PROGRESS " << ++installed << std::endl;
  }

  const auto items = manager->ListContent(
      static_cast<uint32_t>(rex::system::xam::DummyDeviceId::HDD), 0, marketplace, title_id);
  for (const auto& item : items) {
    uint32_t license = 0;
    if (!ids.erase(item.file_name())) continue;
    if (manager->OpenContent("dlcprobe", 0, item, license) != 0) {
      return 7;
    }
    auto* ini = runtime.file_system()->ResolvePath("dlcprobe:\\dlc.ini");
    auto* content = runtime.file_system()->ResolvePath("dlcprobe:\\");
    if (!ini || !ini->size() || !content) return 8;
    unsigned archives = 0;
    for (const auto& dir : content->children()) {
      for (const auto& entry : dir->children()) {
        if (std::filesystem::path(entry->name()).extension() == ".big" && entry->size()) {
          std::cout << item.file_name() << ' ' << entry->name() << ' ' << entry->size() << '\n';
          ++archives;
        }
      }
    }
    if (!archives || manager->CloseContent("dlcprobe") != 0) return 9;
  }
  return ids.empty() ? 0 : 10;
}
