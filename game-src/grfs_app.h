// grfs - ReXGlue Recompiled Project
//
// Customize your app by overriding virtual hooks from rex::ReXApp.

#pragma once

#include <rex/rex_app.h>
#include <rex/runtime.h>
#include <cstdio>
#include <cstdlib>
#include <rex/cvar.h>
#include <rex/input/input_system.h>
#include "grfs_pc_options.h"
#include <rex/ui/keybinds.h>
#include <rex/input/mnk/mnk_input_driver.h>
#include "grfs_frame_counter.h"

class GrfsApp : public rex::ReXApp {
 public:
  using rex::ReXApp::ReXApp;

  static std::unique_ptr<rex::ui::WindowedApp> Create(
      rex::ui::WindowedAppContext& ctx) {
    return std::unique_ptr<GrfsApp>(new GrfsApp(ctx, "grfs",
        PPCImageConfig));
  }

  // Store editable PC preferences with user data, outside the signed app.
  void OnConfigurePaths(rex::PathConfig& paths) override {
    std::filesystem::create_directories(paths.user_data_root);
    paths.config_path = paths.user_data_root / "grfs.toml";
    pc_config_ = paths.config_path;
  }

  void OnConfigureFonts(ImFontAtlas* atlas) override {
#if REX_PLATFORM_MAC
    // Read the system font on this Mac; no third-party font is redistributed.
    const auto path = "/System/Library/Fonts/Supplemental/Arial.ttf";
    if (std::filesystem::exists(path))
      pc_font_ = atlas->AddFontFromFileTTF(path, 16.0f);
#endif
  }

  void OnCreateDialogs(rex::ui::ImGuiDrawer* drawer) override {
    pc_drawer_ = drawer;
    pc_options_ = std::make_unique<grfs::options::Dialog>(drawer, pc_config_, pc_font_);
    // A registered empty ImGui dialog still forces continuous host repaints.
    // Keep the object alive, but attach it only while native Options is open.
    drawer->RemoveDialog(pc_options_.get());
    grfs::options::visibility_changed = [this, alive = pc_alive_] {
      app_context().CallInUIThreadDeferred([this, alive] {
        if (!alive->load()) return;
        if (!pc_options_) return;
        if (grfs::options::native_open.load()) pc_drawer_->AddDialog(pc_options_.get());
        else pc_drawer_->RemoveDialog(pc_options_.get());
      });
    };
    grfs::options::ApplyPerformanceHUD(rex::cvar::GetFlagByName("grfs_performance_hud") == "true");
    rex::ui::RegisterBind("bind_grfs_pc_options", "F5", "PC settings inside game Options", [] {
      if (grfs::options::native_open.load())
        grfs::options::panel_open = !grfs::options::panel_open.load();
    });
    rex::ui::RegisterBind("bind_grfs_mouse_capture", "F6",
        "Capture / release mouse camera (F6)", [] {
      if (!grfs::options::native_open.load())
        rex::input::mnk::SetMouseLookActive(!rex::input::mnk::IsMouseLookActive());
    });
  }

  void OnPostSetup() override {
    if (auto* input = static_cast<rex::input::InputSystem*>(runtime()->input_system())) {
      input->SetActiveCallback([this] {
        const auto& io = pc_drawer_->GetIO();
        return !grfs::options::panel_open.load() && !io.WantCaptureMouse && !io.WantCaptureKeyboard;
      });
    }
  }

  void OnShutdown() override {
    {
      std::lock_guard<std::mutex> lock(grfs::options::visibility_mutex);
      pc_alive_->store(false);
      grfs::options::visibility_changed = {};
    }
    grfs::options::ApplyPerformanceHUD(false);
    pc_options_.reset();
  }

  // Optional read-only snapshot for callback-table analysis. Disabled normally.
  void OnPostLoadXexImage() override {
    const char* output = std::getenv("REX_GRFS_IMAGE_DUMP");
    if (!output || !*output) return;
    if (auto* file = std::fopen(output, "wb")) {
      const auto& image = PPCImageConfig;
      const auto count = std::fwrite(runtime()->memory()->virtual_membase() +
          image.image_base, 1, image.image_size, file);
      std::fclose(file);
      std::fprintf(stderr, "[GRFS IMAGE DUMP] base=0x%08X bytes=%zu expected=%u\n",
          image.image_base, count, image.image_size);
    } else {
      std::perror("GRFS image dump");
    }
  }

 private:
  std::filesystem::path pc_config_;
  rex::ui::ImGuiDrawer* pc_drawer_ = nullptr;
  ImFont* pc_font_ = nullptr;
  std::unique_ptr<grfs::options::Dialog> pc_options_;
  std::shared_ptr<std::atomic<bool>> pc_alive_ = std::make_shared<std::atomic<bool>>(true);

  // Override virtual hooks for customization:
  // void OnPostInitLogging() override {}
  // void OnPreSetup(rex::RuntimeConfig& config) override {}
  // void OnLoadXexImage(std::string& xex_image) override {}
  // void OnPostLoadXexImage() override {}
  // void OnPostSetup() override {}
  // void OnCreateDialogs(rex::ui::ImGuiDrawer* drawer) override {}
  // std::unique_ptr<rex::ui::ImGuiDialog> CreateAchievementsOverlay() override;
  // std::unique_ptr<rex::ui::AchievementNotificationDialog>
  // CreateAchievementNotificationDialog() override;
  // void OnShutdown() override {}
  // void OnConfigurePaths(rex::PathConfig& paths) override {}
};


// Opt-in presets in F4 > GRFS. Existing controller settings stay unchanged
// until a preset is explicitly selected; Save to config persists the choice.
REXCVAR_DEFINE_COMMAND(grfs_pc_controls, ([] {
  const std::pair<const char*, const char*> values[] = {
    {"mnk_mode", "true"}, {"mnk_mouse", "true"},
    {"keybind_a", "Space,Semicolon"}, {"keybind_b", "C,Backspace"},
    {"keybind_x", "R"}, {"keybind_y", "Q"},
    {"keybind_left_trigger", "RMB"}, {"keybind_right_trigger", "LMB"},
    {"keybind_left_shoulder", "G"}, {"keybind_right_shoulder", "E"},
    {"keybind_lstick_press", "F"}, {"keybind_rstick_press", "MMB"},
    {"keybind_start", "Escape,Return"}, {"keybind_back", "Tab"}
  };
  for (const auto& [name, value] : values) rex::cvar::SetFlagByName(name, value);
  rex::input::mnk::SetMouseLookActive(true);
}), "GRFS/Controls", "Apply PC preset: WASD, mouse aim/fire, R reload; F6 releases mouse");

REXCVAR_DEFINE_COMMAND(grfs_language_english, [] {
  rex::cvar::SetFlagByName("user_language", "1");
}, "GRFS/Language", "English menus: save config and restart the game");
REXCVAR_DEFINE_COMMAND(grfs_language_spanish, [] {
  rex::cvar::SetFlagByName("user_language", "5");
}, "GRFS/Language", "Spanish menus: save config and restart the game");
REXCVAR_DEFINE_COMMAND(grfs_language_french, [] {
  rex::cvar::SetFlagByName("user_language", "4");
}, "GRFS/Language", "French menus: save config and restart the game");
