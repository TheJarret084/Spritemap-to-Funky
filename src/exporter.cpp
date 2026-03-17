#include <cmath>
#include <filesystem>
#include <iostream>
#include <unordered_map>

#include "nlohmann/json.hpp"

#include "exporter.hpp"
#include "parser.hpp"
#include "render.hpp"
#include "utils.hpp"

#include "stb/stb_image.h"
#include "stb/stb_image_write.h"

using json = nlohmann::json;

static void log_line(std::string* log_out, const std::string& msg, bool is_err) {
    if (log_out) {
        *log_out += msg;
        return;
    }
    if (is_err) {
        std::cerr << msg;
    } else {
        std::cout << msg;
    }
}

int run_export(
    const std::string& animation_path,
    const std::string& atlas_path,
    const std::string& out_dir,
    const std::string& xml_path,
    ProgressCallback progress_cb,
    std::string* log_out
) {
    json anim;
    json atlas_json;
    try {
        anim = json::parse(read_file_strip_bom(animation_path));
    } catch (const std::exception& e) {
        log_line(log_out, "error leyendo/parsing Animation.json (" + animation_path + "): " + e.what() + "\n", true);
        return 2;
    }
    try {
        atlas_json = json::parse(read_file_strip_bom(atlas_path));
    } catch (const std::exception& e) {
        log_line(log_out, "error leyendo/parsing spritemap1.json (" + atlas_path + "): " + e.what() + "\n", true);
        return 3;
    }

    std::unordered_map<std::string, Sprite> atlas;
    if (atlas_json.contains("ATLAS") && atlas_json["ATLAS"].contains("SPRITES")) {
        for (const auto& entry : atlas_json["ATLAS"]["SPRITES"]) {
            if (!entry.contains("SPRITE")) continue;
            const auto& s = entry["SPRITE"];
            Sprite spr;
            spr.x = jvalue_or<int>(s, "x", 0);
            spr.y = jvalue_or<int>(s, "y", 0);
            spr.w = jvalue_or<int>(s, "w", 0);
            spr.h = jvalue_or<int>(s, "h", 0);
            spr.rotated = jvalue_or<bool>(s, "rotated", false);
            atlas[jstring_or(s, "name", "")] = spr;
        }
    }

    std::string atlas_image = "spritemap1.png";
    if (atlas_json.contains("ATLAS") && atlas_json["ATLAS"].contains("meta")) {
        atlas_image = jstring_or(atlas_json["ATLAS"]["meta"], "image", "spritemap1.png");
    }
    std::filesystem::path atlas_png = std::filesystem::path(atlas_path).parent_path() / atlas_image;

    int aw = 0, ah = 0, ac = 0;
    unsigned char* atlas_pixels = stbi_load(atlas_png.string().c_str(), &aw, &ah, &ac, 4);
    if (!atlas_pixels) {
        log_line(log_out, "no pude cargar atlas PNG: " + atlas_png.string() + "\n", true);
        return 2;
    }

    Image atlas_img;
    atlas_img.w = aw;
    atlas_img.h = ah;
    atlas_img.pixels.assign(atlas_pixels, atlas_pixels + (aw * ah * 4));
    stbi_image_free(atlas_pixels);

    std::unordered_map<std::string, Symbol> symbols;
    if (anim.contains("SD") && anim["SD"].contains("S")) {
        for (const auto& s : anim["SD"]["S"]) {
            Symbol sym;
            sym.name = jstring_or(s, "SN", "");
            if (s.contains("TL")) sym.timeline = parse_timeline(s["TL"]);
            symbols[sym.name] = sym;
        }
    }

    Symbol main_sym;
    if (anim.contains("AN")) {
        main_sym.name = jstring_or(anim["AN"], "N", "main");
        if (anim["AN"].contains("TL")) main_sym.timeline = parse_timeline(anim["AN"]["TL"]);
    } else {
        main_sym.name = "main";
    }

    struct ExportJob {
        const Symbol* sym = nullptr;
        std::string out_name;
        std::vector<int> frames;
    };

    std::filesystem::create_directories(out_dir);

    std::vector<AnimDef> anim_defs;
    if (!xml_path.empty()) {
        try {
            anim_defs = parse_anim_xml(xml_path);
        } catch (const std::exception& e) {
            log_line(log_out, "error leyendo/parsing XML (" + xml_path + "): " + e.what() + "\n", true);
            return 4;
        }
        if (anim_defs.empty()) {
            log_line(log_out, "XML sin <anim> validos: " + xml_path + "\n", true);
            return 5;
        }
    }

    int progress_current = 0;
    int progress_total = 0;

    auto export_symbol = [&](const ExportJob& job) {
        const Symbol& sym = *job.sym;
        if (sym.timeline.total_frames <= 0) return;
        std::string safe_name = sanitize_name(job.out_name);
        std::filesystem::path anim_dir = std::filesystem::path(out_dir) / safe_name;
        std::filesystem::create_directories(anim_dir);

        std::vector<int> frame_list = job.frames;
        if (frame_list.empty()) {
            frame_list.reserve(sym.timeline.total_frames);
            for (int f = 0; f < sym.timeline.total_frames; ++f) frame_list.push_back(f);
        }

        Bounds bounds;
        Transform identity;
        for (int f : frame_list) {
            if (f < 0 || f >= sym.timeline.total_frames) continue;
            accumulate_bounds_symbol(sym, f, identity, symbols, atlas, bounds);
        }
        if (!bounds.initialized) return;

        int canvas_w = static_cast<int>(std::ceil(bounds.maxx - bounds.minx));
        int canvas_h = static_cast<int>(std::ceil(bounds.maxy - bounds.miny));
        if (canvas_w <= 0 || canvas_h <= 0) return;

        Transform offset;
        offset.tx = -bounds.minx;
        offset.ty = -bounds.miny;

        int out_idx = 0;
        for (int f : frame_list) {
            if (f < 0 || f >= sym.timeline.total_frames) continue;
            Image canvas;
            canvas.w = canvas_w;
            canvas.h = canvas_h;
            canvas.pixels.assign(canvas.w * canvas.h * 4, 0);

            render_symbol(sym, f, offset, symbols, atlas, atlas_img, canvas);

            char filename[256];
            std::snprintf(filename, sizeof(filename), "%s_%04d.png", safe_name.c_str(), out_idx++);
            std::filesystem::path out_path = anim_dir / filename;
            stbi_write_png(out_path.string().c_str(), canvas.w, canvas.h, 4, canvas.pixels.data(), canvas.w * 4);

            progress_current++;
            if (progress_cb) progress_cb(progress_current, progress_total, job.out_name);
        }
    };

    std::vector<ExportJob> jobs;
    if (!anim_defs.empty()) {
        for (const auto& def : anim_defs) {
            if (def.source_anim == main_sym.name) {
                jobs.push_back({&main_sym, def.name, def.indices});
                continue;
            }
            auto it = symbols.find(def.source_anim);
            if (it == symbols.end()) {
                // Fallback: some anim lists use `name` as the symbol id.
                auto it2 = symbols.find(def.name);
                if (it2 == symbols.end()) continue;
                jobs.push_back({&it2->second, def.source_anim, def.indices});
                continue;
            }
            jobs.push_back({&it->second, def.name, def.indices});
        }
    } else {
        jobs.push_back({&main_sym, main_sym.name, {}});
        for (const auto& kv : symbols) jobs.push_back({&kv.second, kv.second.name, {}});
    }

    for (const auto& job : jobs) {
        const Symbol& sym = *job.sym;
        int count = 0;
        if (job.frames.empty()) count = sym.timeline.total_frames;
        else {
            for (int f : job.frames) {
                if (f >= 0 && f < sym.timeline.total_frames) count++;
            }
        }
        progress_total += count;
    }

    if (progress_cb) progress_cb(progress_current, progress_total, "");

    for (const auto& job : jobs) {
        export_symbol(job);
    }

    log_line(log_out, "listo. salida en: " + out_dir + "\n", false);
    return 0;
}
