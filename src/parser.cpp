#include <algorithm>
#include <regex>

#include "parser.hpp"
#include "utils.hpp"

using json = nlohmann::json;

std::vector<AnimDef> parse_anim_xml(const std::string& path) {
    std::vector<AnimDef> out;
    std::string xml = read_file_strip_bom(path);
    std::regex anim_tag(R"REGEX(<anim\s+[^>]*?/>)REGEX");
    std::regex attr_re(R"REGEX((\w+)="([^"]*)")REGEX");

    auto tags_begin = std::sregex_iterator(xml.begin(), xml.end(), anim_tag);
    auto tags_end = std::sregex_iterator();
    for (auto it = tags_begin; it != tags_end; ++it) {
        std::string tag = it->str();
        AnimDef def;
        auto attr_begin = std::sregex_iterator(tag.begin(), tag.end(), attr_re);
        auto attr_end = std::sregex_iterator();
        for (auto ait = attr_begin; ait != attr_end; ++ait) {
            std::string key = (*ait)[1].str();
            std::string val = (*ait)[2].str();
            if (key == "name") def.name = val;
            else if (key == "anim") def.source_anim = val;
            else if (key == "indices") def.indices = parse_indices(val);
        }
        if (!def.name.empty() && !def.source_anim.empty()) out.push_back(def);
    }
    return out;
}

Transform parse_m3d(const json& j) {
    Transform t;
    if (!j.is_array() || j.size() < 16) return t;
    // M3D is stored column-major (Matrix3D rawData style):
    // | m0 m4  m8  m12 |
    // | m1 m5  m9  m13 |
    // | m2 m6  m10 m14 |
    // | m3 m7  m11 m15 |
    // For 2D we use:
    // x' = a*x + c*y + tx
    // y' = b*x + d*y + ty
    t.a = j[0].get<double>();
    t.b = j[1].get<double>();
    t.c = j[4].get<double>();
    t.d = j[5].get<double>();
    t.tx = j[12].get<double>();
    t.ty = j[13].get<double>();
    return t;
}

Timeline parse_timeline(const json& tl) {
    Timeline timeline;
    if (!tl.contains("L")) return timeline;
    for (const auto& layer_json : tl["L"]) {
        Layer layer;
        if (!layer_json.contains("FR")) {
            timeline.layers.push_back(std::move(layer));
            continue;
        }
        for (const auto& fr_json : layer_json["FR"]) {
            Frame fr;
            fr.start = jvalue_or<int>(fr_json, "I", 0);
            fr.duration = jvalue_or<int>(fr_json, "DU", 1);
            if (fr_json.contains("E")) {
                for (const auto& e_json : fr_json["E"]) {
                    if (e_json.contains("ASI")) {
                        const auto& asi = e_json["ASI"];
                        Element e;
                        e.type = Element::Type::AtlasSprite;
                        e.name = jstring_or(asi, "N", "");
                        if (asi.contains("M3D")) e.transform = parse_m3d(asi["M3D"]);
                        fr.elements.push_back(std::move(e));
                    } else if (e_json.contains("SI")) {
                        const auto& si = e_json["SI"];
                        Element e;
                        e.type = Element::Type::SymbolInstance;
                        e.name = jstring_or(si, "SN", "");
                        e.first_frame = jvalue_or<int>(si, "FF", 0);
                        e.symbol_type = jstring_or(si, "ST", "");
                        e.loop = jstring_or(si, "LP", "");
                        if (si.contains("M3D")) e.transform = parse_m3d(si["M3D"]);
                        // NOTE: TRP (transform point) is intentionally ignored here.
                        // The Adobe Animate spritemap renderer
                        // relies only on M3D for placement; applying TRP shifts
                        // many symbols off their intended positions.
                        fr.elements.push_back(std::move(e));
                    }
                }
            }
            layer.frames.push_back(std::move(fr));
        }
        timeline.layers.push_back(std::move(layer));
    }

    int max_end = 0;
    for (const auto& layer : timeline.layers) {
        for (const auto& fr : layer.frames) {
            max_end = std::max(max_end, fr.start + fr.duration);
        }
    }
    timeline.total_frames = max_end;
    return timeline;
}
