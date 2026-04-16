#include <cmath>
#include <filesystem>
#include <iostream>
#include <unordered_map>
#include <unordered_set>

#include "nlohmann/json.hpp"

#include "exporter.hpp"
#include "exporter_ase.hpp"
#include "math.hpp"
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
    std::string* log_out,
    const std::string& aseprite_path,
    bool export_ase,
    bool export_frames
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
            if (!sym.name.empty()) symbols[sym.name] = sym;
        }
    } else if (anim.contains("SYMBOL_DICTIONARY") && anim["SYMBOL_DICTIONARY"].contains("Symbols")) {
        for (const auto& s : anim["SYMBOL_DICTIONARY"]["Symbols"]) {
            Symbol sym;
            sym.name = jstring_or(s, "SYMBOL_name", "");
            if (s.contains("TIMELINE")) sym.timeline = parse_timeline(s["TIMELINE"]);
            if (!sym.name.empty()) symbols[sym.name] = sym;
        }
    }

    Symbol main_sym;
    if (anim.contains("AN")) {
        main_sym.name = jstring_or(anim["AN"], "N", "main");
        if (anim["AN"].contains("TL")) main_sym.timeline = parse_timeline(anim["AN"]["TL"]);
    } else if (anim.contains("ANIMATION")) {
        main_sym.name = jstring_or(anim["ANIMATION"], "SYMBOL_name", "main");
        if (anim["ANIMATION"].contains("TIMELINE")) main_sym.timeline = parse_timeline(anim["ANIMATION"]["TIMELINE"]);
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

        std::vector<std::string> layer_order;
        std::unordered_map<std::string, std::string> raw_to_safe;
        std::unordered_set<std::string> used_safe;

        auto register_layer = [&](const std::string& raw) -> std::string {
            auto it = raw_to_safe.find(raw);
            if (it != raw_to_safe.end()) return it->second;
            std::string base = sanitize_name(raw);
            if (base.empty()) base = "layer";
            std::string name = base;
            int suffix = 1;
            while (used_safe.count(name)) {
                name = base + "_" + std::to_string(suffix++);
            }
            raw_to_safe[raw] = name;
            used_safe.insert(name);
            layer_order.push_back(name);
            return name;
        };

        auto get_layer = [&](const std::string& raw) -> std::string {
            auto it = raw_to_safe.find(raw);
            if (it != raw_to_safe.end()) return it->second;
            return register_layer(raw);
        };

        auto visit_elements = [&](auto&& self,
                                  const Symbol& cur,
                                  int frame,
                                  const Transform& parent,
                                  const std::string& prefix,
                                  std::unordered_map<std::string, int>& occ,
                                  auto&& on_sprite) -> void {
            for (int li = static_cast<int>(cur.timeline.layers.size()) - 1; li >= 0; --li) {
                const auto& layer = cur.timeline.layers[li];
                const Frame* fr = nullptr;
                for (const auto& f : layer.frames) {
                    if (frame >= f.start && frame < f.start + f.duration) {
                        fr = &f;
                        break;
                    }
                }
                if (!fr) continue;
                for (const auto& e : fr->elements) {
                    Transform t = multiply(parent, e.transform);
                    std::string base = prefix + cur.name + "_L" + std::to_string(li) + "_" + e.name + "_" +
                        (e.type == Element::Type::AtlasSprite ? "A" : "S");
                    int idx = occ[base]++;
                    std::string raw = base;
                    if (idx > 0) raw += "_" + std::to_string(idx);

                    if (e.type == Element::Type::AtlasSprite) {
                        auto it = atlas.find(e.name);
                        if (it == atlas.end()) continue;
                        on_sprite(it->second, t, raw);
                    } else {
                        auto it = symbols.find(e.name);
                        if (it == symbols.end()) continue;
                        const Symbol& child = it->second;
                        int child_frame = resolve_child_frame(e, frame, fr->start, child.timeline.total_frames);
                        std::string child_prefix = raw + "__";
                        self(self, child, child_frame, t, child_prefix, occ, on_sprite);
                    }
                }
            }
        };

        if (export_ase) {
            for (int f : frame_list) {
                if (f < 0 || f >= sym.timeline.total_frames) continue;
                std::unordered_map<std::string, int> occ;
                visit_elements(visit_elements, sym, f, offset, "", occ,
                    [&](const Sprite&, const Transform&, const std::string& raw) {
                        register_layer(raw);
                    }
                );
            }
        }

        std::filesystem::path layers_dir = anim_dir / "_layers";
        if (export_ase) std::filesystem::create_directories(layers_dir);

        auto init_canvas = [&](Image& img) {
            if (!img.pixels.empty()) return;
            img.w = canvas_w;
            img.h = canvas_h;
            img.pixels.assign(img.w * img.h * 4, 0);
        };

        int out_idx = 0;
        for (int f : frame_list) {
            if (f < 0 || f >= sym.timeline.total_frames) continue;
            int frame_out = out_idx++;

            if (export_frames) {
                Image canvas;
                canvas.w = canvas_w;
                canvas.h = canvas_h;
                canvas.pixels.assign(canvas.w * canvas.h * 4, 0);

                render_symbol(sym, f, offset, symbols, atlas, atlas_img, canvas);

                char filename[256];
                std::snprintf(filename, sizeof(filename), "%s_%04d.png", safe_name.c_str(), frame_out);
                std::filesystem::path out_path = anim_dir / filename;
                stbi_write_png(out_path.string().c_str(), canvas.w, canvas.h, 4, canvas.pixels.data(), canvas.w * 4);
            }

            if (export_ase) {
                std::unordered_map<std::string, Image> layer_images;
                std::unordered_map<std::string, int> occ;

                visit_elements(visit_elements, sym, f, offset, "", occ,
                    [&](const Sprite& spr, const Transform& t, const std::string& raw) {
                        std::string layer_name = get_layer(raw);
                        Image& img = layer_images[layer_name];
                        init_canvas(img);
                        draw_sprite_affine(atlas_img, spr, t, img);
                    }
                );

                for (const auto& layer_name : layer_order) {
                    auto it = layer_images.find(layer_name);
                    Image img;
                    if (it != layer_images.end()) {
                        img = std::move(it->second);
                    } else {
                        init_canvas(img);
                    }

                    std::filesystem::path layer_dir = layers_dir / layer_name;
                    std::filesystem::create_directories(layer_dir);
                    char lname[256];
                    std::snprintf(lname, sizeof(lname), "%s_%04d.png", layer_name.c_str(), frame_out);
                    std::filesystem::path lpath = layer_dir / lname;
                    stbi_write_png(lpath.string().c_str(), img.w, img.h, 4, img.pixels.data(), img.w * 4);
                }
            }

            progress_current++;
            if (progress_cb) progress_cb(progress_current, progress_total, job.out_name);
        }

        if (export_ase && out_idx > 0 && !layer_order.empty()) {
            std::filesystem::path out_ase = std::filesystem::path(out_dir) / (safe_name + ".ase");
            export_ase_from_layers(layers_dir.string(), layer_order, out_idx, out_ase.string(), aseprite_path, log_out);
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
