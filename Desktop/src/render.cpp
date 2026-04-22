#include <algorithm>
#include <cmath>

#include "render.hpp"
#include "math.hpp"

static void blend_pixel(uint8_t* dst, const uint8_t* src) {
    float sr = src[0] / 255.0f;
    float sg = src[1] / 255.0f;
    float sb = src[2] / 255.0f;
    float sa = src[3] / 255.0f;

    float dr = dst[0] / 255.0f;
    float dg = dst[1] / 255.0f;
    float db = dst[2] / 255.0f;
    float da = dst[3] / 255.0f;

    float out_a = sa + da * (1.0f - sa);
    if (out_a <= 0.0f) {
        dst[0] = dst[1] = dst[2] = dst[3] = 0;
        return;
    }

    float out_r = (sr * sa + dr * da * (1.0f - sa)) / out_a;
    float out_g = (sg * sa + dg * da * (1.0f - sa)) / out_a;
    float out_b = (sb * sa + db * da * (1.0f - sa)) / out_a;

    dst[0] = static_cast<uint8_t>(std::clamp(out_r, 0.0f, 1.0f) * 255.0f);
    dst[1] = static_cast<uint8_t>(std::clamp(out_g, 0.0f, 1.0f) * 255.0f);
    dst[2] = static_cast<uint8_t>(std::clamp(out_b, 0.0f, 1.0f) * 255.0f);
    dst[3] = static_cast<uint8_t>(std::clamp(out_a, 0.0f, 1.0f) * 255.0f);
}

void draw_sprite_affine(const Image& atlas, const Sprite& spr, const Transform& t, Image& canvas) {
    int draw_w = spr.rotated ? spr.h : spr.w;
    int draw_h = spr.rotated ? spr.w : spr.h;
    if (draw_w <= 0 || draw_h <= 0) return;

    double x0 = t.a * 0 + t.c * 0 + t.tx;
    double y0 = t.b * 0 + t.d * 0 + t.ty;
    double x1 = t.a * draw_w + t.c * 0 + t.tx;
    double y1 = t.b * draw_w + t.d * 0 + t.ty;
    double x2 = t.a * 0 + t.c * draw_h + t.tx;
    double y2 = t.b * 0 + t.d * draw_h + t.ty;
    double x3 = t.a * draw_w + t.c * draw_h + t.tx;
    double y3 = t.b * draw_w + t.d * draw_h + t.ty;

    double minx = std::floor(std::min({x0, x1, x2, x3}));
    double maxx = std::ceil(std::max({x0, x1, x2, x3}));
    double miny = std::floor(std::min({y0, y1, y2, y3}));
    double maxy = std::ceil(std::max({y0, y1, y2, y3}));

    Transform inv;
    if (!invert(t, inv)) return;

    int ix0 = std::max(0, static_cast<int>(minx));
    int ix1 = std::min(canvas.w - 1, static_cast<int>(maxx));
    int iy0 = std::max(0, static_cast<int>(miny));
    int iy1 = std::min(canvas.h - 1, static_cast<int>(maxy));

    for (int y = iy0; y <= iy1; ++y) {
        for (int x = ix0; x <= ix1; ++x) {
            double sx = inv.a * x + inv.c * y + inv.tx;
            double sy = inv.b * x + inv.d * y + inv.ty;
            if (sx < 0.0 || sy < 0.0 || sx >= draw_w || sy >= draw_h) continue;

            int ax = 0;
            int ay = 0;
            if (!spr.rotated) {
                ax = spr.x + static_cast<int>(sx);
                ay = spr.y + static_cast<int>(sy);
            } else {
                // Assume atlas stored rotated 90 deg clockwise.
                ax = spr.x + (spr.w - 1 - static_cast<int>(sy));
                ay = spr.y + static_cast<int>(sx);
            }

            if (ax < 0 || ay < 0 || ax >= atlas.w || ay >= atlas.h) continue;
            const uint8_t* src = &atlas.pixels[(ay * atlas.w + ax) * 4];
            if (src[3] == 0) continue;
            uint8_t* dst = &canvas.pixels[(y * canvas.w + x) * 4];
            blend_pixel(dst, src);
        }
    }
}

int resolve_child_frame(const Element& e, int parent_frame, int instance_start, int child_total) {
    if (child_total <= 0) return 0;

    int rel = parent_frame - instance_start;
    if (rel < 0) rel = 0;
    int base = rel + e.first_frame;
    std::string loop = e.loop;
    for (char& c : loop) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    if (loop == "sf" || loop == "singleframe" || loop == "single_frame") {
        return std::clamp(e.first_frame, 0, child_total - 1);
    }
    if (loop == "po" || loop == "playonce" || loop == "play_once") {
        return std::min(base, child_total - 1);
    }
    // Default: loop
    if (base < 0) base = 0;
    return base % child_total;
}

void accumulate_bounds_symbol(
    const Symbol& sym,
    int frame,
    const Transform& parent,
    const std::unordered_map<std::string, Symbol>& symbols,
    const std::unordered_map<std::string, Sprite>& atlas,
    Bounds& bounds
) {
    for (const auto& layer : sym.timeline.layers) {
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
            if (e.type == Element::Type::AtlasSprite) {
                auto it = atlas.find(e.name);
                if (it == atlas.end()) continue;
                const Sprite& spr = it->second;
                int draw_w = spr.rotated ? spr.h : spr.w;
                int draw_h = spr.rotated ? spr.w : spr.h;

                double x0 = t.a * 0 + t.c * 0 + t.tx;
                double y0 = t.b * 0 + t.d * 0 + t.ty;
                double x1 = t.a * draw_w + t.c * 0 + t.tx;
                double y1 = t.b * draw_w + t.d * 0 + t.ty;
                double x2 = t.a * 0 + t.c * draw_h + t.tx;
                double y2 = t.b * 0 + t.d * draw_h + t.ty;
                double x3 = t.a * draw_w + t.c * draw_h + t.tx;
                double y3 = t.b * draw_w + t.d * draw_h + t.ty;

                double minx = std::min({x0, x1, x2, x3});
                double maxx = std::max({x0, x1, x2, x3});
                double miny = std::min({y0, y1, y2, y3});
                double maxy = std::max({y0, y1, y2, y3});

                if (!bounds.initialized) {
                    bounds.minx = minx; bounds.maxx = maxx;
                    bounds.miny = miny; bounds.maxy = maxy;
                    bounds.initialized = true;
                } else {
                    bounds.minx = std::min(bounds.minx, minx);
                    bounds.maxx = std::max(bounds.maxx, maxx);
                    bounds.miny = std::min(bounds.miny, miny);
                    bounds.maxy = std::max(bounds.maxy, maxy);
                }
            } else {
                auto it = symbols.find(e.name);
                if (it == symbols.end()) continue;
                const Symbol& child = it->second;
                int child_frame = resolve_child_frame(e, frame, fr->start, child.timeline.total_frames);
                accumulate_bounds_symbol(child, child_frame, t, symbols, atlas, bounds);
            }
        }
    }
}

void render_symbol(
    const Symbol& sym,
    int frame,
    const Transform& parent,
    const std::unordered_map<std::string, Symbol>& symbols,
    const std::unordered_map<std::string, Sprite>& atlas,
    const Image& atlas_img,
    Image& canvas
) {
    // Draw bottom layers first, top layers last.
    for (int li = static_cast<int>(sym.timeline.layers.size()) - 1; li >= 0; --li) {
        const auto& layer = sym.timeline.layers[li];
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
            if (e.type == Element::Type::AtlasSprite) {
                auto it = atlas.find(e.name);
                if (it == atlas.end()) continue;
                draw_sprite_affine(atlas_img, it->second, t, canvas);
            } else {
                auto it = symbols.find(e.name);
                if (it == symbols.end()) continue;
                const Symbol& child = it->second;
                int child_frame = resolve_child_frame(e, frame, fr->start, child.timeline.total_frames);
                render_symbol(child, child_frame, t, symbols, atlas, atlas_img, canvas);
            }
        }
    }
}
