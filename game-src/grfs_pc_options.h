#pragma once

#include <atomic>
#include <fstream>
#include <string>
#include <functional>
#include <mutex>
#include <dlfcn.h>
#include <rex/cvar.h>
#include <rex/ui/imgui_dialog.h>
#include <rex/ui/keybinds.h>
#include <rex/input/mnk/mnk_input_driver.h>
#include <imgui.h>

// Guest callbacks only publish state. All ImGui work stays on the UI thread.
namespace grfs::options {
inline std::atomic<bool> native_open{false};
inline std::atomic<bool> panel_open{false};
inline std::atomic<bool> restore_mouse{false};
// Installed on startup; notifications queue attachment changes on the UI thread.
inline std::function<void()> visibility_changed;
inline std::function<bool()> restart_game;
inline std::mutex visibility_mutex;
inline void NotifyVisibility() {
  std::lock_guard<std::mutex> lock(visibility_mutex);
  if (visibility_changed) visibility_changed();
}
inline void ApplyPerformanceHUD(bool enabled) {
#if REX_PLATFORM_MAC
  using Setter = void (*)(int, int);
  static auto setter = reinterpret_cast<Setter>(dlsym(RTLD_DEFAULT, "GRFSSetPerformanceHUD"));
  if (setter) setter(enabled, rex::cvar::GetFlagByName("user_language") == "5");
#endif
}

inline void NotifyOpen() {
  if (!native_open.exchange(true)) {
    restore_mouse = rex::input::mnk::IsMouseLookActive();
    rex::input::mnk::SetMouseLookActive(false);
    REXLOG_INFO("[GRFS OPTIONS] opened");
    NotifyVisibility();
  }
}
inline void NotifyClose() {
  panel_open = false;
  if (native_open.exchange(false)) {
    rex::input::mnk::SetMouseLookActive(restore_mouse.load());
    REXLOG_INFO("[GRFS OPTIONS] closed");
    NotifyVisibility();
  }
}

class Dialog final : public rex::ui::ImGuiDialog {
 public:
  Dialog(rex::ui::ImGuiDrawer* drawer, std::filesystem::path config, ImFont* font)
      : ImGuiDialog(drawer), config_(std::move(config)),
        startup_language_(rex::cvar::GetFlagByName("user_language")), font_(font) {}

 private:
  std::filesystem::path config_;
  std::string startup_language_, capturing_, message_;
  int capture_frame_ = 0;
  bool dirty_ = false;
  ImFont* font_ = nullptr;

  struct Theme {
    Theme(ImFont* font) {
      ImGui::PushFont(font);
      const ImVec4 dark(0.025f, 0.055f, 0.075f, 0.98f);
      const ImVec4 cyan(0.28f, 0.78f, 0.88f, 1.0f);
      const std::pair<ImGuiCol, ImVec4> colors[] = {
        {ImGuiCol_WindowBg, dark}, {ImGuiCol_ChildBg, ImVec4(0.015f,0.035f,0.05f,0.8f)},
        {ImGuiCol_Text, ImVec4(0.9f,0.95f,0.97f,1)},
        {ImGuiCol_TextDisabled, ImVec4(0.48f,0.65f,0.71f,1)},
        {ImGuiCol_Border, ImVec4(0.15f,0.4f,0.47f,0.9f)},
        {ImGuiCol_TitleBg, dark}, {ImGuiCol_TitleBgActive, ImVec4(0.035f,0.15f,0.2f,1)},
        {ImGuiCol_FrameBg, ImVec4(0.06f,0.14f,0.18f,1)},
        {ImGuiCol_FrameBgHovered, ImVec4(0.09f,0.27f,0.33f,1)},
        {ImGuiCol_FrameBgActive, ImVec4(0.1f,0.32f,0.39f,1)},
        {ImGuiCol_Button, ImVec4(0.05f,0.19f,0.25f,1)},
        {ImGuiCol_ButtonHovered, ImVec4(0.12f,0.38f,0.46f,1)},
        {ImGuiCol_ButtonActive, ImVec4(0.16f,0.49f,0.58f,1)},
        {ImGuiCol_CheckMark, cyan}, {ImGuiCol_SliderGrab, cyan},
        {ImGuiCol_SliderGrabActive, ImVec4(0.75f,0.95f,1,1)},
        {ImGuiCol_Header, ImVec4(0.08f,0.29f,0.36f,1)},
        {ImGuiCol_HeaderHovered, ImVec4(0.12f,0.4f,0.49f,1)},
        {ImGuiCol_HeaderActive, ImVec4(0.16f,0.49f,0.58f,1)},
        {ImGuiCol_Separator, ImVec4(0.15f,0.4f,0.47f,0.8f)},
        {ImGuiCol_ScrollbarBg, ImVec4(0.02f,0.06f,0.08f,1)},
        {ImGuiCol_ScrollbarGrab, ImVec4(0.1f,0.3f,0.37f,1)},
        {ImGuiCol_ScrollbarGrabHovered, cyan}, {ImGuiCol_ScrollbarGrabActive, cyan},
        {ImGuiCol_ResizeGrip, ImVec4(0,0,0,0)}
      };
      count = int(std::size(colors));
      for (const auto& [key, value] : colors) ImGui::PushStyleColor(key, value);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(18, 16));
      ImGui::PushStyleVar(ImGuiStyleVar_FramePadding, ImVec2(10, 6));
      ImGui::PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(10, 9));
      ImGui::PushStyleVar(ImGuiStyleVar_FrameRounding, 0.0f);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, 0.0f);
    }
    ~Theme() { ImGui::PopStyleVar(5); ImGui::PopStyleColor(count); ImGui::PopFont(); }
    int count;
  };

  const char* Text(const char* english, const char* spanish) const {
    return rex::cvar::GetFlagByName("user_language") == "5" ? spanish : english;
  }
  void Set(const char* name, const std::string& value) {
    if (rex::cvar::SetFlagByName(name, value)) { dirty_ = true; message_.clear(); }
  }
  bool Save() {
    auto temporary = config_; temporary += ".tmp";
    try {
      std::ofstream file;
      file.exceptions(std::ios::badbit | std::ios::failbit);
      file.open(temporary);
      file << "# GRFS Recompiled preferences\n" << rex::cvar::SerializeToTOML();
      file.close();
      std::filesystem::rename(temporary, config_);
      dirty_ = false;
      message_ = Text("Settings saved.", "Ajustes guardados.");
      return true;
    } catch (const std::exception&) {
      std::error_code ec; std::filesystem::remove(temporary, ec);
      message_ = Text("Could not save settings. Please try again.",
                      "No se pudieron guardar los ajustes. Intenta de nuevo.");
      return false;
    }
  }
  static std::string KeyName(ImGuiKey key) {
    using VK = rex::ui::VirtualKey;
    if (key >= ImGuiKey_A && key <= ImGuiKey_Z)
      return std::string(1, char('A' + key - ImGuiKey_A));
    if (key >= ImGuiKey_0 && key <= ImGuiKey_9)
      return std::string(1, char('0' + key - ImGuiKey_0));
    if (key >= ImGuiKey_F1 && key <= ImGuiKey_F12)
      return "F" + std::to_string(1 + key - ImGuiKey_F1);
    switch (key) {
      case ImGuiKey_Space: return "Space";
      case ImGuiKey_Enter: return "Return";
      case ImGuiKey_Tab: return "Tab";
      case ImGuiKey_Backspace: return "Backspace";
      case ImGuiKey_UpArrow: return "Up";
      case ImGuiKey_DownArrow: return "Down";
      case ImGuiKey_LeftArrow: return "Left";
      case ImGuiKey_RightArrow: return "Right";
      case ImGuiKey_Semicolon: return "Semicolon";
      case ImGuiKey_Apostrophe: return "Quote";
      case ImGuiKey_Comma: return "Comma";
      case ImGuiKey_Period: return "Period";
      default: return {};
    }
  }
  void Capture(ImGuiIO& io) {
    if (capturing_.empty() || ImGui::GetFrameCount() <= capture_frame_) return;
    if (ImGui::IsKeyPressed(ImGuiKey_Escape)) { capturing_.clear(); return; }
    std::string key;
    for (int m = 0; m < 3; ++m)
      if (ImGui::IsMouseClicked(m)) key = m == 0 ? "LMB" : m == 1 ? "RMB" : "MMB";
    for (int k = ImGuiKey_NamedKey_BEGIN; key.empty() && k < ImGuiKey_NamedKey_END; ++k)
      if (ImGui::IsKeyPressed(ImGuiKey(k), false)) key = KeyName(ImGuiKey(k));
    if (key.empty()) return;
    if (key == "F4" || key == "F5" || key == "F6") {
      message_ = Text("F4, F5 and F6 are reserved for settings and mouse capture.",
                      "F4, F5 y F6 se reservan para ajustes y captura del raton.");
      return;
    }
    if (io.KeyAlt) key = "Alt+" + key;
    if (io.KeyCtrl) key = "Ctrl+" + key;
    if (io.KeyShift) key = "Shift+" + key;
    Set(capturing_.c_str(), key);
    capturing_.clear();
  }
  void OnDraw(ImGuiIO& io) override {
    if (!native_open.load()) { panel_open = false; capturing_.clear(); return; }
    Theme theme(font_);
    const float scale = std::max(1.0f, io.DisplaySize.y / 900.0f);
    ImGui::SetNextWindowPos(ImVec2(io.DisplaySize.x - 280 * scale, 80 * scale), ImGuiCond_Always);
    ImGui::SetNextWindowBgAlpha(0.95f);
    ImGui::Begin("##grfs_pc_entry", nullptr, ImGuiWindowFlags_AlwaysAutoResize |
        ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoSavedSettings |
        ImGuiWindowFlags_NoFocusOnAppearing | ImGuiWindowFlags_NoNav);
    if (ImGui::Button(Text("PC SETTINGS [F5]", "AJUSTES DE PC [F5]"), ImVec2(240 * scale, 38 * scale)))
      panel_open = !panel_open.load();
    ImGui::End();
    if (!panel_open.load()) return;
    ImGui::SetNextWindowPos(ImVec2(io.DisplaySize.x * 0.5f, io.DisplaySize.y * 0.5f),
                            ImGuiCond_Appearing, ImVec2(0.5f, 0.5f));
    ImGui::SetNextWindowSize(ImVec2(760 * scale, 610 * scale), ImGuiCond_Appearing);
    bool visible = true;
    ImGui::Begin(Text("GRFS // PC SETTINGS", "GRFS // AJUSTES DE PC"), &visible,
                  ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings);
    Capture(io);
    ImGui::TextColored(ImVec4(0.45f, 0.88f, 0.95f, 1), "%s", Text("LANGUAGE", "IDIOMA"));
    const char* names[] = {"English", "Español", "Français"};
    const char* ids[] = {"1", "5", "4"};
    auto language = rex::cvar::GetFlagByName("user_language");
    int choice = language == "5" ? 1 : language == "4" ? 2 : 0;
    if (ImGui::Combo(Text("Menu language", "Idioma de los menus"), &choice, names, 3))
      Set("user_language", ids[choice]);
    if (rex::cvar::GetFlagByName("user_language") != startup_language_)
      ImGui::TextWrapped("%s", Text("Save and restart the game to apply the menu language.",
                                    "Guarda y reinicia el juego para aplicar el idioma de los menus."));
    ImGui::TextWrapped("%s", Text("Audio and subtitles: use the original game options.",
                                  "Audio y subtitulos: usa las opciones originales del juego."));
    ImGui::Separator();
    const char* display_modes[] = {Text("Fullscreen", "Pantalla completa"), Text("Windowed", "Ventana")};
    int display_mode = rex::cvar::GetFlagByName("fullscreen") == "true" ? 0 : 1;
    if (ImGui::Combo(Text("Display mode", "Modo de pantalla"), &display_mode, display_modes, 2))
      Set("fullscreen", display_mode == 0 ? "true" : "false");
    const char* resolutions[] = {"1280 x 720", "1600 x 900", "1920 x 1080", "Native / Nativa"};
    const char* resolution_ids[] = {"720", "900", "1080", "native"};
    auto resolution = rex::cvar::GetFlagByName("grfs_output_resolution");
    int resolution_choice = resolution == "720" ? 0 : resolution == "900" ? 1 : resolution == "1080" ? 2 : 3;
    if (ImGui::Combo(Text("Output resolution limit", "Limite de resolucion de salida"),
                     &resolution_choice, resolutions, 4))
      Set("grfs_output_resolution", resolution_ids[resolution_choice]);
    ImGui::TextWrapped("%s", Text("Save and restart to apply. Works in native fullscreen. Preserves aspect ratio; does not change Xbox internal resolution.",
      "Guarda y reinicia para aplicar. Funciona en pantalla completa nativa. Conserva la proporcion; no cambia la resolucion interna de Xbox."));
    ImGui::Separator();
    const char* limits[] = {Text("Unlimited", "Sin limite"), "30 FPS", "60 FPS", "120 FPS"};
    const char* limit_ids[] = {"0", "30", "60", "120"};
    auto limit=rex::cvar::GetFlagByName("grfs_present_limit");
    int limit_choice=limit=="30"?1:limit=="60"?2:limit=="120"?3:0;
    if(ImGui::Combo(Text("Presentation FPS limit", "Limite de FPS de presentacion"),&limit_choice,limits,4))
      Set("grfs_present_limit",limit_ids[limit_choice]);
    ImGui::TextWrapped("%s",Text("Applies immediately. Save to remember. Limits presentation, not game speed or new frames generated.",
      "Se aplica al instante. Guarda para recordar. Limita la presentacion, no la velocidad del juego ni los cuadros nuevos que genera."));
    ImGui::Separator();
    bool hud = rex::cvar::GetFlagByName("grfs_performance_hud") == "true";
    if (ImGui::Checkbox(Text("Performance HUD", "HUD de rendimiento"), &hud)) {
      Set("grfs_performance_hud", hud ? "true" : "false");
      ApplyPerformanceHUD(hud);
    }
    ImGui::TextWrapped("%s", Text("Metal presentation statistics; may include repeated images. Save to remember.",
      "Estadisticas de presentacion Metal; pueden incluir imagenes repetidas. Guarda para recordar."));
    ImGui::Separator();
    bool mouse = rex::cvar::GetFlagByName("mnk_mouse") == "true";
    if (ImGui::Checkbox(Text("Mouse camera", "Camara con raton"), &mouse)) Set("mnk_mouse", mouse ? "true" : "false");
    float sensitivity = std::stof(rex::cvar::GetFlagByName("mnk_sensitivity"));
    if (ImGui::SliderFloat(Text("Sensitivity", "Sensibilidad"), &sensitivity, 0.1f, 10.0f, "%.2f"))
      Set("mnk_sensitivity", std::to_string(sensitivity));
    ImGui::TextWrapped("%s", Text("F6 captures / releases the mouse during gameplay.",
                                  "F6 captura o libera el raton durante la partida."));
    ImGui::Separator();
    if (ImGui::Button(Text("Apply PC preset", "Aplicar preset de PC"))) {
      rex::cvar::InvokeCommand("grfs_pc_controls", "");
      rex::input::mnk::SetMouseLookActive(false);
      dirty_ = true;
    }
    ImGui::SameLine();
    ImGui::TextDisabled("%s", Text("Click a binding; Esc cancels capture.", "Pulsa una tecla asignada; Esc cancela la captura."));
    const char* binds[][3] = {
      {"keybind_lstick_up", "Move forward", "Avanzar"},
      {"keybind_lstick_down", "Move backward", "Retroceder"},
      {"keybind_lstick_left", "Move left", "Mover a la izquierda"},
      {"keybind_lstick_right", "Move right", "Mover a la derecha"},
      {"keybind_a", "A / Cover / Confirm", "A / Cobertura / Confirmar"},
      {"keybind_b", "B / Back", "B / Volver"},
      {"keybind_x", "X / Reload", "X / Recargar"},
      {"keybind_y", "Y / Change weapon", "Y / Cambiar arma"},
      {"keybind_left_trigger", "Left trigger / Aim", "Gatillo izquierdo / Apuntar"},
      {"keybind_right_trigger", "Right trigger / Fire", "Gatillo derecho / Disparar"},
      {"keybind_left_shoulder", "Left shoulder", "Boton superior izquierdo"},
      {"keybind_right_shoulder", "Right shoulder", "Boton superior derecho"},
      {"keybind_lstick_press", "Left stick click", "Clic de stick izquierdo"},
      {"keybind_rstick_press", "Right stick click", "Clic de stick derecho"},
      {"keybind_start", "Start / Pause", "Start / Pausa"},
      {"keybind_back", "Back / Map", "Back / Mapa"},
      {"keybind_dpad_up", "D-pad up", "Cruceta arriba"},
      {"keybind_dpad_down", "D-pad down", "Cruceta abajo"},
      {"keybind_dpad_left", "D-pad left", "Cruceta izquierda"},
      {"keybind_dpad_right", "D-pad right", "Cruceta derecha"}
    };
    ImGui::BeginChild("bindings", ImVec2(0, -80 * scale), true);
    for (const auto& row : binds) {
      ImGui::PushID(row[0]);
      ImGui::TextUnformatted(Text(row[1], row[2]));
      ImGui::SameLine(300 * scale);
      auto value = rex::cvar::GetFlagByName(row[0]);
      if (value == "MMB") value = Text("Wheel click", "Clic de rueda");
      else if (value == "LMB") value = Text("Left mouse", "Clic izquierdo");
      else if (value == "RMB") value = Text("Right mouse", "Clic derecho");
      if (capturing_ == row[0]) value = Text("Press a key...", "Pulsa una tecla...");
      if (ImGui::Button(value.c_str(), ImVec2(190 * scale, 0))) {
        capturing_ = row[0]; capture_frame_ = ImGui::GetFrameCount();
      }
      ImGui::PopID();
    }
    ImGui::EndChild();
    if (ImGui::Button(Text("Save settings", "Guardar ajustes"))) Save();
    ImGui::SameLine();
    if (ImGui::Button(Text("Save and restart", "Guardar y reiniciar")) && Save()) {
      if (!restart_game || !restart_game())
        message_ = Text("Could not restart. Settings saved; close and reopen the launcher.",
                        "No se pudo reiniciar. Ajustes guardados; cierra y vuelve a abrir el launcher.");
    }
    ImGui::SameLine();
    if (ImGui::Button(Text("Back to game options", "Volver a opciones"))) visible = false;
    if (dirty_) { ImGui::SameLine(); ImGui::TextUnformatted(Text("Unsaved changes", "Cambios sin guardar")); }
    if (!message_.empty()) ImGui::TextWrapped("%s", message_.c_str());
    ImGui::End();
    if (!visible) { panel_open = false; capturing_.clear(); }
  }
};
}  // namespace grfs::options

REXCVAR_DEFINE_STRING(grfs_output_resolution, "1080", "GRFS/Display",
                     "Output size limit: 720, 900, 1080 or native; restart required");

REXCVAR_DEFINE_BOOL(grfs_performance_hud, false, "GRFS/Performance",
                   "Show guest swap rate and frame intervals; excludes UI redraws");

REXCVAR_DEFINE_COMMAND(grfs_notify_options_open, [] { grfs::options::NotifyOpen(); },
                       "GRFS/Internal", "Native options open notification").debug_only();
REXCVAR_DEFINE_COMMAND(grfs_notify_options_close, [] { grfs::options::NotifyClose(); },
                       "GRFS/Internal", "Native options close notification").debug_only();
REXCVAR_DEFINE_COMMAND_ARGS(grfs_notify_screen, [](std::string_view screen) {
  REXLOG_INFO("[GRFS SCREEN] {}", screen);
  if (screen == "Options.feu") grfs::options::NotifyOpen();
  else grfs::options::NotifyClose();
}, "GRFS/Internal", "Native menu screen notification").debug_only();

REXCVAR_DEFINE_INT32(grfs_present_limit, 0, "GRFS/Display",
    "Host presentation limit: 0 (unlimited), 30, 60 or 120; does not change guest timing")
    .lifecycle(rex::cvar::Lifecycle::kHotReload);
