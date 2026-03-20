#include <algorithm>
#include <mutex>
#include <thread>
#include <atomic>
#include <cctype>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <ctime>
#include <string>
#include <vector>

#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif
#include <SDL2/SDL.h>

#include "imgui.h"
#include "backends/imgui_impl_sdl2.h"
#include "backends/imgui_impl_sdlrenderer2.h"

#include "nlohmann/json.hpp"

#include "exporter.hpp"
#include "parser.hpp"
#include "utils.hpp"
#include "i18n.hpp"

#include "stb/stb_image.h"

using json = nlohmann::json;

struct AnimItem {
    std::string name;
    std::string source;
    std::string indices;
};

struct Texture {
    SDL_Texture* tex = nullptr;
    int w = 0;
    int h = 0;
};

static bool InputTextString(const char* label, std::string& str) {
    if (str.capacity() < 256) str.reserve(256);
    ImGuiInputTextFlags flags = ImGuiInputTextFlags_CallbackResize;
    auto callback = [](ImGuiInputTextCallbackData* data) -> int {
        if (data->EventFlag == ImGuiInputTextFlags_CallbackResize) {
            auto* s = static_cast<std::string*>(data->UserData);
            s->resize(static_cast<size_t>(data->BufTextLen));
            data->Buf = s->data();
        }
        return 0;
    };
    return ImGui::InputText(label, str.data(), str.capacity() + 1, flags, callback, &str);
}

static std::string indices_to_string(const std::vector<int>& indices) {
    if (indices.empty()) return {};
    std::string out;
    for (size_t i = 0; i < indices.size(); ++i) {
        out += std::to_string(indices[i]);
        if (i + 1 < indices.size()) out += ",";
    }
    return out;
}

static std::vector<AnimItem> load_anims_from_xml(const std::string& path) {
    std::vector<AnimItem> out;
    for (const auto& def : parse_anim_xml(path)) {
        AnimItem item;
        item.name = def.name;
        item.source = def.source_anim;
        item.indices = indices_to_string(def.indices);
        out.push_back(item);
    }
    return out;
}

static std::vector<AnimItem> load_anims_from_animlist_json(const std::string& path) {
    std::vector<AnimItem> out;
    json data = json::parse(read_file_strip_bom(path));
    if (!data.contains("animations") || !data["animations"].is_array()) return out;
    for (const auto& anim : data["animations"]) {
        if (!anim.is_object()) continue;
        std::string anim_name = anim.value("anim", "");
        std::string symbol_name = anim.value("name", "");
        if (anim_name.empty()) anim_name = symbol_name;
        if (symbol_name.empty()) symbol_name = anim_name;
        if (anim_name.empty() || symbol_name.empty()) continue;

        std::string indices;
        if (anim.contains("indices") && anim["indices"].is_array()) {
            std::vector<int> idxs;
            for (const auto& v : anim["indices"]) {
                if (v.is_number_integer()) idxs.push_back(v.get<int>());
            }
            indices = indices_to_string(idxs);
        }
        out.push_back({anim_name, symbol_name, indices});
    }
    return out;
}

static std::vector<AnimItem> load_anims_from_json(const std::string& path) {
    std::vector<AnimItem> out;
    json data = json::parse(read_file_strip_bom(path));
    auto an = data.value("AN", json::object());
    std::string main_name = an.value("N", "main");
    if (!main_name.empty()) {
        out.push_back({main_name, main_name, ""});
    }
    for (const auto& sym : data.value("SD", json::object()).value("S", json::array())) {
        std::string sn = sym.value("SN", "");
        if (!sn.empty()) out.push_back({sn, sn, ""});
    }
    return out;
}

static std::string write_temp_xml(const std::vector<AnimItem>& items) {
    auto now = std::chrono::high_resolution_clock::now().time_since_epoch().count();
    std::filesystem::path p = std::filesystem::temp_directory_path() /
        ("spritemap_anims_" + std::to_string(now) + ".xml");
    std::ofstream f(p);
    f << "<character>\n";
    for (const auto& it : items) {
        f << "  <anim name=\"" << it.name << "\" anim=\"" << it.source << "\"";
        if (!it.indices.empty()) f << " indices=\"" << it.indices << "\"";
        f << "/>\n";
    }
    f << "</character>\n";
    return p.string();
}

static bool load_texture_from_png(SDL_Renderer* renderer, const std::string& path, Texture& out) {
    int w = 0, h = 0, comp = 0;
    unsigned char* data = stbi_load(path.c_str(), &w, &h, &comp, 4);
    if (!data) return false;
    SDL_Texture* tex = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32, SDL_TEXTUREACCESS_STATIC, w, h);
    if (!tex) {
        stbi_image_free(data);
        return false;
    }
    SDL_UpdateTexture(tex, nullptr, data, w * 4);
    SDL_SetTextureBlendMode(tex, SDL_BLENDMODE_BLEND);
    stbi_image_free(data);

    if (out.tex) SDL_DestroyTexture(out.tex);
    out.tex = tex;
    out.w = w;
    out.h = h;
    return true;
}

static SDL_Surface* load_png_surface(const char* path) {
    int w = 0, h = 0, comp = 0;
    unsigned char* data = stbi_load(path, &w, &h, &comp, 4);
    if (!data) return nullptr;
    SDL_Surface* surf = SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL_PIXELFORMAT_RGBA32);
    if (!surf) {
        stbi_image_free(data);
        return nullptr;
    }
    std::memcpy(surf->pixels, data, static_cast<size_t>(w) * static_cast<size_t>(h) * 4);
    stbi_image_free(data);
    return surf;
}

static void set_window_icon(SDL_Window* window) {
    std::vector<std::filesystem::path> bases;
    bases.push_back(std::filesystem::current_path());

    if (char* base = SDL_GetBasePath()) {
        std::filesystem::path p(base);
        SDL_free(base);
        bases.push_back(p);
        if (p.has_parent_path()) bases.push_back(p.parent_path());
        if (p.has_parent_path() && p.parent_path().has_parent_path()) {
            bases.push_back(p.parent_path().parent_path());
        }
    }

    std::vector<std::string> png_candidates;
    for (const auto& b : bases) {
        png_candidates.push_back((b / "assets" / "icon.png").string());
    }
    for (const auto& path : png_candidates) {
        SDL_Surface* icon = load_png_surface(path.c_str());
        if (!icon) continue;
        SDL_SetWindowIcon(window, icon);
        SDL_FreeSurface(icon);
        return;
    }

    std::vector<std::string> bmp_candidates;
    for (const auto& b : bases) {
        bmp_candidates.push_back((b / "assets" / "icon.bmp").string());
    }
    for (const auto& path : bmp_candidates) {
        SDL_Surface* icon = SDL_LoadBMP(path.c_str());
        if (!icon) continue;
        SDL_SetWindowIcon(window, icon);
        SDL_FreeSurface(icon);
        return;
    }
}

static std::string detect_system_lang() {
#ifdef _WIN32
    LANGID lang_id = GetUserDefaultUILanguage();
    switch (PRIMARYLANGID(lang_id)) {
        case LANG_SPANISH: return "es";
        case LANG_ENGLISH: return "en";
        default: break;
    }
#endif

    const char* envs[] = {"LC_ALL", "LC_MESSAGES", "LANG"};
    for (const char* e : envs) {
        const char* val = std::getenv(e);
        if (!val || !*val) continue;
        std::string s(val);
        size_t cut = s.find_first_of("._-@");
        if (cut != std::string::npos) s = s.substr(0, cut);
        for (auto& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
        if (s == "es" || s == "en") return s;
        if (s.size() >= 2) {
            std::string pref = s.substr(0, 2);
            if (pref == "es" || pref == "en") return pref;
        }
    }
    return {};
}

static std::string find_asset_path(const std::string& rel) {
    std::vector<std::filesystem::path> bases;
    bases.push_back(std::filesystem::current_path());

    if (char* base = SDL_GetBasePath()) {
        std::filesystem::path p(base);
        SDL_free(base);
        bases.push_back(p);
        if (p.has_parent_path()) bases.push_back(p.parent_path());
        if (p.has_parent_path() && p.parent_path().has_parent_path()) {
            bases.push_back(p.parent_path().parent_path());
        }
    }

    for (const auto& b : bases) {
        std::filesystem::path full = b / rel;
        std::error_code ec;
        if (std::filesystem::is_regular_file(full, ec)) return full.string();
    }
    return {};
}

static std::filesystem::path get_exe_dir() {
    if (char* base = SDL_GetBasePath()) {
        std::filesystem::path p(base);
        SDL_free(base);
        return p;
    }
    return std::filesystem::current_path();
}

static std::string timestamp_now() {
    std::time_t t = std::time(nullptr);
    std::tm tm{};
#ifdef _WIN32
    localtime_s(&tm, &t);
#else
    localtime_r(&t, &tm);
#endif
    char buf[32];
    if (std::strftime(buf, sizeof(buf), "%Y%m%d_%H%M%S", &tm) == 0) {
        return "unknown";
    }
    return buf;
}

static void write_log_file(const std::filesystem::path& logs_dir, const std::string& text) {
    std::error_code ec;
    std::filesystem::create_directories(logs_dir, ec);
    std::filesystem::path file = logs_dir / ("log_" + timestamp_now() + ".txt");
    std::ofstream f(file, std::ios::binary);
    if (f.is_open()) {
        if (!text.empty()) f << text;
        else f << "log vacio\n";
    }
}

static std::filesystem::path get_config_path() {
    std::filesystem::path base;
    if (char* pref = SDL_GetPrefPath("SpritemapToFunky", "SpritemapToFunky")) {
        base = pref;
        SDL_free(pref);
    } else {
        base = std::filesystem::current_path();
    }
    return base / "config.json";
}

enum class PickMode { None, AnimJson, AtlasJson, AtlasPng, Xml, AnimListJson, OutDir, LangXml };

struct PickerState {
    bool open = false;
    PickMode mode = PickMode::None;
    bool dir_only = false;
    std::vector<std::string> exts;
    std::filesystem::path cwd = std::filesystem::current_path();
    std::string selected;
    std::string filter;
    std::string path_input;
};

static bool has_ext(const std::filesystem::path& p, const std::vector<std::string>& exts) {
    if (exts.empty()) return true;
    std::string ext = p.extension().string();
    std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c){ return static_cast<char>(std::tolower(c)); });
    for (auto e : exts) {
        std::transform(e.begin(), e.end(), e.begin(), [](unsigned char c){ return static_cast<char>(std::tolower(c)); });
        if (ext == e) return true;
    }
    return false;
}

static bool filter_match(const std::string& name, const std::string& filter) {
    if (filter.empty()) return true;
    auto it = std::search(name.begin(), name.end(), filter.begin(), filter.end(),
        [](char a, char b){ return std::tolower(a) == std::tolower(b); });
    return it != name.end();
}

static bool draw_picker(PickerState& picker, std::string& chosen, I18n& i18n) {
    bool picked = false;
    auto tr = [&](const char* key, const char* fallback) { return i18n.tr(key, fallback); };
    std::string picker_title = std::string(tr("picker_title", "Seleccionar")) + "##picker";
    if (picker.open) {
        ImGui::OpenPopup(picker_title.c_str());
        picker.path_input = picker.cwd.string();
        picker.open = false;
    }

    if (ImGui::BeginPopupModal(picker_title.c_str(), nullptr, ImGuiWindowFlags_AlwaysAutoResize)) {
        ImGui::Text("%s", tr("picker_dir", "Directorio:"));
        ImGui::SameLine();
        ImGui::TextUnformatted(picker.cwd.string().c_str());

        if (ImGui::Button("..")) {
            if (picker.cwd.has_parent_path()) picker.cwd = picker.cwd.parent_path();
            picker.path_input = picker.cwd.string();
        }
        ImGui::SameLine();
        InputTextString(tr("picker_path", "Ruta"), picker.path_input);
        ImGui::SameLine();
        if (ImGui::Button(tr("picker_go", "Ir"))) {
            std::filesystem::path p = picker.path_input;
            std::error_code ec;
            if (std::filesystem::is_directory(p, ec)) {
                picker.cwd = p;
                picker.selected.clear();
                picker.filter.clear();
            }
        }

        InputTextString(tr("picker_filter", "Filtro"), picker.filter);

        ImGui::BeginChild("file_list", ImVec2(600, 300), true);
        std::vector<std::filesystem::directory_entry> entries;
        try {
            for (const auto& e : std::filesystem::directory_iterator(picker.cwd)) {
                entries.push_back(e);
            }
        } catch (...) {
        }
        std::sort(entries.begin(), entries.end(), [](const auto& a, const auto& b){
            if (a.is_directory() != b.is_directory()) return a.is_directory() > b.is_directory();
            return a.path().filename().string() < b.path().filename().string();
        });

        for (const auto& e : entries) {
            std::string name = e.path().filename().string();
            if (!filter_match(name, picker.filter)) continue;

            bool is_dir = e.is_directory();
            if (!is_dir && !picker.dir_only && !has_ext(e.path(), picker.exts)) continue;
            if (picker.dir_only && !is_dir) continue;

            std::string label = is_dir ? ("[DIR] " + name) : name;
            bool selected = (picker.selected == e.path().string());
            if (ImGui::Selectable(label.c_str(), selected)) {
                picker.selected = e.path().string();
            }
            if (is_dir && ImGui::IsItemHovered() && ImGui::IsMouseDoubleClicked(0)) {
                picker.cwd = e.path();
                picker.path_input = picker.cwd.string();
                picker.selected.clear();
                picker.filter.clear();
            }
        }
        ImGui::EndChild();

        if (picker.dir_only) {
            if (ImGui::Button(tr("picker_use_folder", "Usar esta carpeta"))) {
                chosen = picker.cwd.string();
                picked = true;
                ImGui::CloseCurrentPopup();
            }
        } else {
            if (ImGui::Button(tr("picker_select", "Seleccionar"))) {
                if (!picker.selected.empty()) {
                    chosen = picker.selected;
                    picked = true;
                    ImGui::CloseCurrentPopup();
                }
            }
            ImGui::SameLine();
            if (ImGui::Button(tr("picker_open_folder", "Abrir carpeta"))) {
                if (!picker.selected.empty()) {
                    std::error_code ec;
                    if (std::filesystem::is_directory(picker.selected, ec)) {
                        picker.cwd = picker.selected;
                        picker.path_input = picker.cwd.string();
                        picker.selected.clear();
                        picker.filter.clear();
                    }
                }
            }
        }
        ImGui::SameLine();
        if (ImGui::Button(tr("picker_cancel", "Cancelar"))) {
            ImGui::CloseCurrentPopup();
        }

        ImGui::EndPopup();
    }
    return picked;
}

int main(int, char**) {
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;

    SDL_Window* window = SDL_CreateWindow(
        "Spritemap to Funky",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        1200, 800,
        SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE
    );
    if (!window) return 2;
    set_window_icon(window);

    SDL_Renderer* renderer = SDL_CreateRenderer(
        window, -1,
        SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC
    );
    if (!renderer) return 3;

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    ImGui::StyleColorsDark();

    ImGui_ImplSDL2_InitForSDLRenderer(window, renderer);
    ImGui_ImplSDLRenderer2_Init(renderer);

    I18n i18n;

    std::string anim_json;
    std::string atlas_json;
    std::string atlas_png;
    std::string xml_path;
    std::string anims_json;
    std::string out_dir = "out";
    std::string aseprite_path = "aseprite";
    bool export_frames = true;
    bool export_ase = false;

    std::vector<AnimItem> anims;
    std::vector<bool> selected;
    std::string anim_filter;
    std::string log_text;
    std::mutex log_mutex;
    std::atomic<bool> export_running(false);
    std::atomic<int> export_current(0);
    std::atomic<int> export_total(0);
    std::string export_anim;
    std::thread export_thread;

    Texture atlas_tex;

    PickerState picker;

    std::string lang_xml;
    std::string lang_es = find_asset_path("assets/lang/es.xml");
    std::string lang_en = find_asset_path("assets/lang/en.xml");
    std::filesystem::path config_path = get_config_path();
    bool lang_auto = true;
    std::string lang_override;

    auto load_config = [&]() {
        std::ifstream f(config_path);
        if (!f.good()) return;
        try {
            json j;
            f >> j;
            lang_auto = j.value("lang_auto", true);
            lang_override = j.value("lang_path", "");
        } catch (...) {
        }
    };

    auto save_config = [&]() {
        try {
            std::error_code ec;
            std::filesystem::create_directories(config_path.parent_path(), ec);
            json j;
            j["lang_auto"] = lang_auto;
            j["lang_path"] = lang_override;
            std::ofstream f(config_path);
            if (f.good()) f << j.dump(2);
        } catch (...) {
        }
    };

    auto set_lang = [&](const std::string& path) -> bool {
        std::string err;
        if (path.empty()) {
            i18n.clear();
            lang_xml.clear();
            SDL_SetWindowTitle(window, i18n.tr("app_title", "Spritemap to Funky"));
            return true;
        }
        if (!i18n.load_xml(path, &err)) {
            log_text += std::string(i18n.tr("log_lang_load_failed", "No pude cargar idioma: ")) + path + "\n";
            return false;
        }
        lang_xml = path;
        SDL_SetWindowTitle(window, i18n.tr("app_title", "Spritemap to Funky"));
        return true;
    };

    load_config();

    auto apply_auto_lang = [&]() {
        std::string detected_lang = detect_system_lang();
        if (detected_lang == "es" && !lang_es.empty()) {
            set_lang(lang_es);
        } else if (detected_lang == "en" && !lang_en.empty()) {
            set_lang(lang_en);
        } else if (!lang_es.empty()) {
            set_lang(lang_es);
        } else if (!lang_en.empty()) {
            set_lang(lang_en);
        }
    };

    if (!lang_auto && !lang_override.empty() && std::filesystem::is_regular_file(lang_override)) {
        set_lang(lang_override);
    } else {
        lang_auto = true;
        lang_override.clear();
        save_config();
        apply_auto_lang();
    }

    auto tr = [&](const char* key, const char* fallback) { return i18n.tr(key, fallback); };

    auto refresh_anims = [&]() {
        anims.clear();
        if (!anims_json.empty() && std::filesystem::is_regular_file(anims_json)) {
            try { anims = load_anims_from_animlist_json(anims_json); } catch (...) { anims.clear(); }
        }
        if (anims.empty() && !xml_path.empty() && std::filesystem::is_regular_file(xml_path)) {
            try { anims = load_anims_from_xml(xml_path); } catch (...) { anims.clear(); }
        }
        if (anims.empty() && !anim_json.empty() && std::filesystem::is_regular_file(anim_json)) {
            try { anims = load_anims_from_json(anim_json); } catch (...) { anims.clear(); }
        }
        selected.assign(anims.size(), true);
    };

    auto picker_from_path = [&](const std::string& path) {
        std::filesystem::path p(path);
        std::error_code ec;
        if (!path.empty()) {
            if (std::filesystem::is_directory(p, ec)) {
                picker.cwd = p;
                return;
            }
            if (std::filesystem::is_regular_file(p, ec)) {
                picker.cwd = p.parent_path();
                return;
            }
        }
        picker.cwd = std::filesystem::current_path();
    };

    auto load_preview = [&]() {
        std::string img_path;
        if (!atlas_png.empty() && std::filesystem::is_regular_file(atlas_png)) {
            img_path = atlas_png;
        } else if (!atlas_json.empty() && std::filesystem::is_regular_file(atlas_json)) {
            try {
                json j = json::parse(read_file_strip_bom(atlas_json));
                std::string img = j["ATLAS"]["meta"].value("image", "spritemap1.png");
                std::filesystem::path p = std::filesystem::path(atlas_json).parent_path() / img;
                img_path = p.string();
            } catch (...) {
                log_text += std::string(tr("log_no_preview_atlas_json", "No pude leer spritemap1.json para preview.")) + "\n";
                return;
            }
        } else {
            log_text += std::string(tr("log_no_preview_both", "No hay atlas PNG ni spritemap1.json para preview.")) + "\n";
            return;
        }

        if (!load_texture_from_png(renderer, img_path, atlas_tex)) {
            log_text += std::string(tr("log_no_preview_load", "No pude cargar atlas para preview.")) + "\n";
        }
    };

    auto json_has_key = [&](const std::string& path, const std::string& key) -> bool {
        try {
            json j = json::parse(read_file_strip_bom(path));
            return j.contains(key);
        } catch (...) {
            return false;
        }
    };

    auto assign_json_by_content = [&](const std::string& path) {
        try {
            json j = json::parse(read_file_strip_bom(path));
            if (j.contains("ATLAS")) {
                atlas_json = path;
                return;
            }
            if (j.contains("AN") && j.contains("SD")) {
                anim_json = path;
                refresh_anims();
                return;
            }
            if (j.contains("animations")) {
                anims_json = path;
                refresh_anims();
                return;
            }
        } catch (...) {
        }
        // Fallback by filename
        std::string lower = path;
        std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c){ return std::tolower(c); });
        if (lower.find("animation") != std::string::npos) {
            anim_json = path;
            refresh_anims();
            return;
        }
        if (lower.find("spritemap") != std::string::npos) {
            atlas_json = path;
            return;
        }
        // Default to anim list
        anims_json = path;
        refresh_anims();
    };

    auto assign_path = [&](const std::string& p) {
        std::filesystem::path path(p);
        std::error_code ec;
        if (std::filesystem::is_directory(path, ec)) {
            for (const auto& e : std::filesystem::directory_iterator(path, ec)) {
                if (ec) break;
                auto file = e.path();
                auto name = file.filename().string();
                auto ext = file.extension().string();
                std::string lower = name;
                std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c){ return std::tolower(c); });

                if (lower == "animation.json") {
                    anim_json = file.string();
                    continue;
                }
                if (lower == "spritemap1.json") {
                    atlas_json = file.string();
                    continue;
                }
                if (lower == "spritemap1.png") {
                    atlas_png = file.string();
                    continue;
                }
                if (ext == ".xml") {
                    if (xml_path.empty()) xml_path = file.string();
                    continue;
                }
                if (ext == ".json") {
                    if (json_has_key(file.string(), "animations")) {
                        anims_json = file.string();
                    }
                }
            }
            refresh_anims();
            return;
        }

        std::string ext = path.extension().string();
        std::string lower_ext = ext;
        std::transform(lower_ext.begin(), lower_ext.end(), lower_ext.begin(), [](unsigned char c){ return std::tolower(c); });
        if (lower_ext == ".xml") {
            xml_path = p;
            refresh_anims();
            return;
        }
        if (lower_ext == ".png") {
            atlas_png = p;
            load_preview();
            return;
        }
        if (lower_ext == ".json") {
            assign_json_by_content(p);
            return;
        }
    };

    bool done = false;
    while (!done) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            ImGui_ImplSDL2_ProcessEvent(&event);
            if (event.type == SDL_QUIT) done = true;
            if (event.type == SDL_DROPFILE) {
                if (event.drop.file) {
                    assign_path(event.drop.file);
                    SDL_free(event.drop.file);
                }
            }
        }

        if (export_thread.joinable() && !export_running.load()) {
            export_thread.join();
        }

        ImGui_ImplSDLRenderer2_NewFrame();
        ImGui_ImplSDL2_NewFrame();
        ImGui::NewFrame();

        auto open_picker = [&](PickMode mode, bool dir_only, const std::vector<std::string>& exts, const std::string& path) {
            picker.mode = mode;
            picker.dir_only = dir_only;
            picker.exts = exts;
            picker.selected.clear();
            picker.filter.clear();
            picker_from_path(path);
            picker.open = true;
        };

        auto do_export = [&]() {
            std::vector<AnimItem> selected_anims;
            for (size_t i = 0; i < anims.size(); ++i) {
                if (selected[i]) selected_anims.push_back(anims[i]);
            }
            if (selected_anims.empty()) {
                log_text += std::string(tr("log_no_anim_selected", "Selecciona al menos una animacion.")) + "\n";
                return;
            }

            std::string temp_xml;
            std::string use_xml = xml_path;
            if (!anims_json.empty() && std::filesystem::is_regular_file(anims_json)) {
                temp_xml = write_temp_xml(selected_anims);
                use_xml = temp_xml;
            } else if (!xml_path.empty() && std::filesystem::is_regular_file(xml_path)) {
                if (selected_anims.size() != anims.size()) {
                    temp_xml = write_temp_xml(selected_anims);
                    use_xml = temp_xml;
                }
            } else {
                temp_xml = write_temp_xml(selected_anims);
                use_xml = temp_xml;
            }

            std::string final_out = out_dir;
            if (final_out.empty()) {
                std::string base;
                if (!anims_json.empty()) base = std::filesystem::path(anims_json).stem().string();
                else if (!xml_path.empty()) base = std::filesystem::path(xml_path).stem().string();
                else if (!anim_json.empty()) base = std::filesystem::path(anim_json).parent_path().filename().string();
                if (base.empty()) base = "project";
                final_out = (std::filesystem::path("out") / base).string();
            }

            if (export_running.load()) {
                log_text += std::string(tr("log_export_running", "Export en progreso...")) + "\n";
                return;
            }

            export_running = true;
            export_current = 0;
            export_total = 0;
            export_anim.clear();

            export_thread = std::thread([=, &log_text, &log_mutex, &export_running, &export_current, &export_total, &export_anim]() {
                std::string log;
                auto cb = [&](int cur, int total, const std::string& anim) {
                    export_current = cur;
                    export_total = total;
                    if (!anim.empty()) export_anim = anim;
                };
                int code = run_export(anim_json, atlas_json, final_out, use_xml, cb, &log, aseprite_path, export_ase, export_frames);
                if (!temp_xml.empty()) {
                    std::error_code ec;
                    std::filesystem::remove(temp_xml, ec);
                }
                std::lock_guard<std::mutex> lock(log_mutex);
                log_text += log;
                if (code != 0) {
                    log_text += std::string(tr("log_export_failed_code", "Export fallo con codigo: ")) + std::to_string(code) + "\n";
                    std::string fail_log = log;
                    if (!fail_log.empty() && fail_log.back() != '\n') fail_log += "\n";
                    fail_log += std::string(tr("log_export_failed_code", "Export fallo con codigo: ")) + std::to_string(code) + "\n";
                    write_log_file(get_exe_dir() / "logs", fail_log);
                }
                export_running = false;
            });
        };

        ImGui::SetNextWindowPos(ImVec2(10, 10), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowSize(ImVec2(1180, 760), ImGuiCond_FirstUseEver);
        if (ImGui::Begin(tr("app_title", "Spritemap to Funky"), nullptr, ImGuiWindowFlags_MenuBar | ImGuiWindowFlags_NoCollapse)) {
            if (ImGui::BeginMenuBar()) {
                if (ImGui::BeginMenu(tr("menu_file", "Archivo"))) {
                    if (ImGui::MenuItem(tr("menu_open_anim_json", "Abrir Animation.json"))) open_picker(PickMode::AnimJson, false, {".json"}, anim_json);
                    if (ImGui::MenuItem(tr("menu_open_atlas_json", "Abrir spritemap1.json"))) open_picker(PickMode::AtlasJson, false, {".json"}, atlas_json);
                    if (ImGui::MenuItem(tr("menu_open_atlas_png", "Abrir atlas PNG (preview)"))) open_picker(PickMode::AtlasPng, false, {".png"}, atlas_png);
                    if (ImGui::MenuItem(tr("menu_open_anims_xml", "Abrir anims.xml (codename)"))) open_picker(PickMode::Xml, false, {".xml"}, xml_path);
                    if (ImGui::MenuItem(tr("menu_open_anims_json", "Abrir anims.json (psych)"))) open_picker(PickMode::AnimListJson, false, {".json"}, anims_json);
                    if (ImGui::MenuItem(tr("menu_choose_out", "Elegir salida"))) open_picker(PickMode::OutDir, true, {}, out_dir);
                    if (ImGui::MenuItem(tr("menu_exit", "Salir"))) done = true;
                    ImGui::EndMenu();
                }
                if (ImGui::BeginMenu(tr("menu_actions", "Acciones"))) {
                    if (ImGui::MenuItem(tr("menu_refresh_anims", "Refrescar anims"))) refresh_anims();
                    if (ImGui::MenuItem(tr("menu_load_preview", "Cargar preview"))) load_preview();
                    if (ImGui::MenuItem(tr("menu_export", "Exportar"))) do_export();
                    ImGui::EndMenu();
                }
                if (ImGui::BeginMenu(tr("menu_language", "Idioma"))) {
                    bool es_active = !lang_es.empty() && (lang_xml == lang_es);
                    bool en_active = !lang_en.empty() && (lang_xml == lang_en);
                    if (ImGui::MenuItem(tr("menu_lang_auto", "Auto (sistema)"), nullptr, lang_auto)) {
                        lang_auto = true;
                        lang_override.clear();
                        save_config();
                        apply_auto_lang();
                    }
                    if (ImGui::MenuItem(tr("menu_lang_es", "Espanol"), nullptr, es_active, !lang_es.empty())) {
                        lang_auto = false;
                        lang_override = lang_es;
                        save_config();
                        set_lang(lang_es);
                    }
                    if (ImGui::MenuItem(tr("menu_lang_en", "English"), nullptr, en_active, !lang_en.empty())) {
                        lang_auto = false;
                        lang_override = lang_en;
                        save_config();
                        set_lang(lang_en);
                    }
                    if (ImGui::MenuItem(tr("menu_lang_load", "Cargar XML..."))) {
                        open_picker(PickMode::LangXml, false, {".xml"}, lang_xml);
                    }
                    if (!lang_xml.empty()) {
                        if (ImGui::MenuItem(tr("menu_lang_reload", "Recargar XML"))) set_lang(lang_xml);
                    }
                    ImGui::EndMenu();
                }
                ImGui::EndMenuBar();
            }

            ImGui::BeginChild("toolbar", ImVec2(0, 34), false);
            if (ImGui::Button(tr("toolbar_anim_json", "Animation.json"))) open_picker(PickMode::AnimJson, false, {".json"}, anim_json);
            ImGui::SameLine();
            if (ImGui::Button(tr("toolbar_atlas_json", "spritemap1.json"))) open_picker(PickMode::AtlasJson, false, {".json"}, atlas_json);
            ImGui::SameLine();
            if (ImGui::Button(tr("toolbar_atlas_png", "Atlas PNG"))) open_picker(PickMode::AtlasPng, false, {".png"}, atlas_png);
            ImGui::SameLine();
            if (ImGui::Button(tr("toolbar_anims_xml", "anims.xml"))) open_picker(PickMode::Xml, false, {".xml"}, xml_path);
            ImGui::SameLine();
            if (ImGui::Button(tr("toolbar_anims_json", "anims.json"))) open_picker(PickMode::AnimListJson, false, {".json"}, anims_json);
            ImGui::SameLine();
            if (ImGui::Button(tr("toolbar_out", "Salida"))) open_picker(PickMode::OutDir, true, {}, out_dir);
            ImGui::SameLine();
            if (ImGui::Button(tr("toolbar_refresh", "Refrescar"))) refresh_anims();
            ImGui::SameLine();
            if (ImGui::Button(tr("toolbar_preview", "Preview"))) load_preview();
            ImGui::SameLine();
            if (ImGui::Button(tr("toolbar_export", "Exportar"))) do_export();
            ImGui::EndChild();

            ImGui::Separator();

            if (ImGui::BeginTable("layout", 2, ImGuiTableFlags_Resizable | ImGuiTableFlags_BordersInnerV)) {
                ImGui::TableSetupColumn("Left", ImGuiTableColumnFlags_WidthFixed, 430.0f);
                ImGui::TableSetupColumn("Right", ImGuiTableColumnFlags_WidthStretch);

                ImGui::TableNextColumn();
                ImGui::BeginChild("left", ImVec2(0, 0), false);

                ImGui::Text("%s", tr("section_inputs", "Entradas"));
                ImGui::Separator();

                InputTextString(tr("label_anim_json", "Animation.json"), anim_json);
                ImGui::SameLine();
                if (ImGui::Button("...##anim")) open_picker(PickMode::AnimJson, false, {".json"}, anim_json);

                InputTextString(tr("label_atlas_json", "spritemap1.json"), atlas_json);
                ImGui::SameLine();
                if (ImGui::Button("...##atlas")) open_picker(PickMode::AtlasJson, false, {".json"}, atlas_json);

                InputTextString(tr("label_atlas_png", "Atlas PNG (preview)"), atlas_png);
                ImGui::SameLine();
                if (ImGui::Button("...##atlaspng")) open_picker(PickMode::AtlasPng, false, {".png"}, atlas_png);

                InputTextString(tr("label_anims_xml", "anims.xml (codename)"), xml_path);
                InputTextString(tr("label_anims_json", "anims.json (psych)"), anims_json);
                ImGui::SameLine();
                if (ImGui::Button("...##animsjson")) open_picker(PickMode::AnimListJson, false, {".json"}, anims_json);

                ImGui::SameLine();
                if (ImGui::Button("...##xml")) open_picker(PickMode::Xml, false, {".xml"}, xml_path);

                InputTextString(tr("label_out", "Salida"), out_dir);
                ImGui::SameLine();
                if (ImGui::Button("...##out")) open_picker(PickMode::OutDir, true, {}, out_dir);

                ImGui::Checkbox(tr("label_export_frames", "Exportar frames PNG"), &export_frames);
                ImGui::Checkbox(tr("label_export_ase", "Exportar .ase"), &export_ase);
                InputTextString(tr("label_aseprite_cli", "Aseprite CLI"), aseprite_path);

                ImGui::Separator();
                ImGui::Text("%s", tr("section_anims", "Animaciones"));
                ImGui::Separator();

                InputTextString(tr("label_filter", "Filtro"), anim_filter);
                ImGui::SameLine();
                if (ImGui::Button(tr("button_all", "Todo"))) std::fill(selected.begin(), selected.end(), true);
                ImGui::SameLine();
                if (ImGui::Button(tr("button_none", "Nada"))) std::fill(selected.begin(), selected.end(), false);

                ImGui::BeginChild("anim_list", ImVec2(0, 0), true);
                for (size_t i = 0; i < anims.size(); ++i) {
                    std::string label = anims[i].name + "  ->  " + anims[i].source;
                    if (!filter_match(label, anim_filter)) continue;
                    bool is_selected = selected[i];
                    if (ImGui::Selectable(label.c_str(), is_selected)) {
                        selected[i] = !is_selected;
                    }
                }
                ImGui::EndChild();

                ImGui::EndChild();

                ImGui::TableNextColumn();
                ImGui::BeginChild("right", ImVec2(0, 0), false);

                ImGui::Text("%s", tr("section_preview", "Preview"));
                ImGui::Separator();

                float right_h = ImGui::GetContentRegionAvail().y;
                float preview_h = std::max(200.0f, right_h * 0.62f);
                ImGui::BeginChild("preview", ImVec2(0, preview_h), true);
                if (atlas_tex.tex) {
                    ImVec2 avail = ImGui::GetContentRegionAvail();
                    float scale = 1.0f;
                    if (atlas_tex.w > 0 && atlas_tex.h > 0) {
                        scale = std::min(avail.x / atlas_tex.w, avail.y / atlas_tex.h);
                        scale = std::min(scale, 1.0f);
                    }
                    ImGui::Image((ImTextureID)atlas_tex.tex, ImVec2(atlas_tex.w * scale, atlas_tex.h * scale));
                } else {
                    ImGui::Text("%s", tr("text_no_preview", "Sin preview cargado."));
                }
                ImGui::EndChild();

                if (export_running.load()) {
                    int total = export_total.load();
                    int cur = export_current.load();
                    float frac = 0.0f;
                    if (total > 0) frac = static_cast<float>(cur) / static_cast<float>(total);
                    std::string label = tr("label_exporting", "Exportando");
                    if (!export_anim.empty()) label += ": " + export_anim;
                    ImGui::ProgressBar(frac, ImVec2(-1, 0), label.c_str());
                    ImGui::Spacing();
                }

                ImGui::Text("%s", tr("section_log", "Log"));
                ImGui::Separator();
                ImGui::BeginChild("log", ImVec2(0, 0), true);
                {
                    std::lock_guard<std::mutex> lock(log_mutex);
                    ImGui::TextUnformatted(log_text.c_str());
                }
                ImGui::EndChild();

                ImGui::EndChild();
                ImGui::EndTable();
            }
        }
        ImGui::End();

        std::string chosen;
        if (draw_picker(picker, chosen, i18n)) {
            switch (picker.mode) {
                case PickMode::AnimJson: anim_json = chosen; refresh_anims(); break;
                case PickMode::AtlasJson: atlas_json = chosen; break;
                case PickMode::AtlasPng: atlas_png = chosen; load_preview(); break;
                case PickMode::Xml: xml_path = chosen; refresh_anims(); break;
                case PickMode::AnimListJson: anims_json = chosen; refresh_anims(); break;
                case PickMode::OutDir: out_dir = chosen; break;
                case PickMode::LangXml:
                    lang_auto = false;
                    lang_override = chosen;
                    save_config();
                    set_lang(chosen);
                    break;
                default: break;
            }
        }

        ImGui::Render();
        SDL_SetRenderDrawColor(renderer, 18, 18, 18, 255);
        SDL_RenderClear(renderer);
        ImGui_ImplSDLRenderer2_RenderDrawData(ImGui::GetDrawData(), renderer);
        SDL_RenderPresent(renderer);
    }

    if (export_thread.joinable()) export_thread.join();

    if (atlas_tex.tex) SDL_DestroyTexture(atlas_tex.tex);

    ImGui_ImplSDLRenderer2_Shutdown();
    ImGui_ImplSDL2_Shutdown();
    ImGui::DestroyContext();

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}
