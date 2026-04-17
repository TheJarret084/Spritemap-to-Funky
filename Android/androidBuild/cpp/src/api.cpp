#ifndef STATIC_LINK
#define IMPLEMENT_API
#endif

#if defined(HX_WINDOWS) || defined(HX_MACOS) || defined(HX_LINUX)
#define NEKO_COMPATIBLE
#endif

#include <hx/CFFIPrime.h>

#include <chrono>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

#include "nlohmann/json.hpp"

#include "exporter.hpp"
#include "parser.hpp"
#include "utils.hpp"

using json = nlohmann::json;

namespace {

struct AnimItem {
    std::string name;
    std::string source;
    std::vector<int> indices;
};

static std::string legacy_buffer;

static std::string to_string(HxString value) {
    return value.c_str() ? std::string(value.c_str(), value.size()) : std::string();
}

static HxString to_hx_string(const std::string& value) {
    return HxString(value.c_str(), static_cast<int>(value.size()));
}

static bool file_exists(const std::string& path) {
    if (path.empty()) return false;
    std::error_code ec;
    return std::filesystem::exists(path, ec);
}

static std::string join_lines(const std::vector<std::string>& lines) {
    std::string out;
    for (const auto& line : lines) {
        if (line.empty()) continue;
        if (!out.empty()) out += "\n";
        out += line;
    }
    return out;
}

static json make_error(const std::string& message, const std::vector<std::string>& logs = {}) {
    json result;
    result["ok"] = false;
    result["log"] = logs.empty() ? message : (join_lines(logs) + "\n" + message);
    return result;
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

static std::vector<AnimItem> load_anims_from_xml_file(const std::string& path) {
    std::vector<AnimItem> out;
    for (const auto& def : parse_anim_xml(path)) {
        out.push_back({def.name, def.source_anim, def.indices});
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

        std::vector<int> indices;
        if (anim.contains("indices") && anim["indices"].is_array()) {
            for (const auto& entry : anim["indices"]) {
                if (entry.is_number_integer()) indices.push_back(entry.get<int>());
            }
        }

        out.push_back({anim_name, symbol_name, indices});
    }

    return out;
}

static std::vector<AnimItem> load_anims_from_animation_json(const std::string& path) {
    std::vector<AnimItem> out;
    json data = json::parse(read_file_strip_bom(path));

    auto an = data.value("AN", json::object());
    std::string main_name = an.value("N", "main");
    if (!main_name.empty()) {
        out.push_back({main_name, main_name, {}});
    }

    for (const auto& symbol : data.value("SD", json::object()).value("S", json::array())) {
        std::string symbol_name = symbol.value("SN", "");
        if (!symbol_name.empty()) out.push_back({symbol_name, symbol_name, {}});
    }

    return out;
}

static std::string resolve_preview_path(const std::string& atlas_json, const std::string& atlas_png) {
    if (file_exists(atlas_png)) return atlas_png;
    if (!file_exists(atlas_json)) return {};

    json data = json::parse(read_file_strip_bom(atlas_json));
    std::string image = "spritemap1.png";
    if (data.contains("ATLAS") && data["ATLAS"].contains("meta")) {
        image = data["ATLAS"]["meta"].value("image", image);
    }
    return (std::filesystem::path(atlas_json).parent_path() / image).string();
}

static std::string resolve_output_dir(
    const std::string& animation_json,
    const std::string& anims_xml,
    const std::string& anims_json,
    const std::string& output_dir
) {
    if (!output_dir.empty()) return output_dir;

    std::string base;
    if (!anims_json.empty()) {
        base = std::filesystem::path(anims_json).stem().string();
    } else if (!anims_xml.empty()) {
        base = std::filesystem::path(anims_xml).stem().string();
    } else if (!animation_json.empty()) {
        base = std::filesystem::path(animation_json).parent_path().filename().string();
    }

    if (base.empty()) base = "project";
    return (std::filesystem::path("out") / base).string();
}

static std::string write_temp_xml(const std::vector<AnimItem>& items) {
    auto now = std::chrono::high_resolution_clock::now().time_since_epoch().count();
    std::filesystem::path path = std::filesystem::temp_directory_path() /
        ("spritemap_haxe_" + std::to_string(now) + ".xml");

    std::ofstream file(path);
    file << "<character>\n";
    for (const auto& item : items) {
        file << "  <anim name=\"" << item.name << "\" anim=\"" << item.source << "\"";
        if (!item.indices.empty()) file << " indices=\"" << indices_to_string(item.indices) << "\"";
        file << "/>\n";
    }
    file << "</character>\n";
    return path.string();
}

static std::vector<AnimItem> load_selected_items(const json& request) {
    std::vector<AnimItem> out;
    if (!request.contains("selected") || !request["selected"].is_array()) return out;

    for (const auto& item : request["selected"]) {
        if (!item.is_object()) continue;
        std::string name = item.value("name", "");
        std::string source = item.value("source", "");
        if (name.empty() || source.empty()) continue;

        std::vector<int> indices;
        if (item.contains("indices") && item["indices"].is_array()) {
            for (const auto& entry : item["indices"]) {
                if (entry.is_number_integer()) indices.push_back(entry.get<int>());
            }
        }

        out.push_back({name, source, indices});
    }

    return out;
}

static json describe_request(const json& request) {
    std::vector<std::string> logs;

    const std::string animation_json = request.value("animationJson", "");
    const std::string atlas_json = request.value("atlasJson", "");
    const std::string atlas_png = request.value("atlasPng", "");
    const std::string anims_xml = request.value("animsXml", "");
    const std::string anims_json = request.value("animsJson", "");
    const std::string output_dir = request.value("outputDir", "");

    std::vector<AnimItem> items;

    if (file_exists(anims_json)) {
        items = load_anims_from_animlist_json(anims_json);
        if (!items.empty()) logs.push_back("Usando anims.json para poblar la lista.");
    }
    if (items.empty() && file_exists(anims_xml)) {
        items = load_anims_from_xml_file(anims_xml);
        if (!items.empty()) logs.push_back("Usando anims.xml para poblar la lista.");
    }
    if (items.empty() && file_exists(animation_json)) {
        items = load_anims_from_animation_json(animation_json);
        if (!items.empty()) logs.push_back("Usando Animation.json para poblar la lista.");
    }

    json response;
    response["ok"] = true;
    response["previewPath"] = resolve_preview_path(atlas_json, atlas_png);
    response["outputDir"] = resolve_output_dir(animation_json, anims_xml, anims_json, output_dir);
    response["animations"] = json::array();

    for (const auto& item : items) {
        response["animations"].push_back({
            {"name", item.name},
            {"source", item.source},
            {"indices", item.indices}
        });
    }

    if (items.empty()) logs.push_back("No encontré animaciones todavía.");
    response["log"] = join_lines(logs);
    return response;
}

static json export_request(const json& request) {
    const std::string animation_json = request.value("animationJson", "");
    const std::string atlas_json = request.value("atlasJson", "");
    const std::string anims_xml = request.value("animsXml", "");
    const std::string anims_json = request.value("animsJson", "");
    const std::string output_dir = request.value("outputDir", "");
    const bool export_frames = request.value("exportFrames", true);
    const bool export_ase = request.value("exportAse", false);
    const std::string aseprite_path = request.value("asepritePath", "aseprite");

    if (!file_exists(animation_json)) {
        return make_error("Falta Animation.json.");
    }
    if (!file_exists(atlas_json)) {
        return make_error("Falta spritemap1.json.");
    }
    if (!export_frames && !export_ase) {
        return make_error("No hay ningún formato de export activo.");
    }

    std::vector<AnimItem> selected = load_selected_items(request);
    if (selected.empty()) {
        return make_error("Selecciona al menos una animación.");
    }

    std::string xml_to_use = anims_xml;
    std::string temp_xml;
    std::string final_output = resolve_output_dir(animation_json, anims_xml, anims_json, output_dir);

    if (!selected.empty()) {
        temp_xml = write_temp_xml(selected);
        xml_to_use = temp_xml;
    }

    std::string log_text;
    int progress_current = 0;
    int progress_total = 0;

    auto progress = [&](int current, int total, const std::string&) {
        progress_current = current;
        progress_total = total;
    };

    int code = run_export(
        animation_json,
        atlas_json,
        final_output,
        xml_to_use,
        progress,
        &log_text,
        aseprite_path,
        export_ase,
        export_frames
    );

    if (!temp_xml.empty()) {
        std::error_code ec;
        std::filesystem::remove(temp_xml, ec);
    }

    json response;
    response["ok"] = (code == 0);
    response["outputDir"] = final_output;
    response["filesWritten"] = progress_current;
    response["totalFrames"] = progress_total;
    response["errorCode"] = code;
    response["log"] = log_text;
    return response;
}

} // namespace

HxString backend_describe(HxString request_json) {
    try {
        json request = json::parse(to_string(request_json));
        return to_hx_string(describe_request(request).dump());
    } catch (const std::exception& error) {
        return to_hx_string(make_error(std::string("Describe falló: ") + error.what()).dump());
    } catch (...) {
        return to_hx_string(make_error("Describe falló con error desconocido.").dump());
    }
}
DEFINE_PRIME1(backend_describe);

HxString backend_export(HxString request_json) {
    try {
        json request = json::parse(to_string(request_json));
        return to_hx_string(export_request(request).dump());
    } catch (const std::exception& error) {
        return to_hx_string(make_error(std::string("Export falló: ") + error.what()).dump());
    } catch (...) {
        return to_hx_string(make_error("Export falló con error desconocido.").dump());
    }
}
DEFINE_PRIME1(backend_export);

extern "C" {

const char* procesar_json(const char* input) {
    try {
        json parsed = json::parse(input ? input : "{}");
        legacy_buffer = describe_request(parsed).dump();
        return legacy_buffer.c_str();
    } catch (...) {
        legacy_buffer = R"({"ok":false,"log":"procesar_json falló."})";
        return legacy_buffer.c_str();
    }
}

const char* procesar_imagen(const char* path) {
    legacy_buffer = std::string("OK_IMG: ") + (path ? path : "");
    return legacy_buffer.c_str();
}

const char* exportar(const char* input, const char* output) {
    legacy_buffer = std::string("Use backend_export. input=") + (input ? input : "") + " output=" + (output ? output : "");
    return legacy_buffer.c_str();
}

}
