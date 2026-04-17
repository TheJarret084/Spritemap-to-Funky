#pragma once

#include <unordered_map>

#include "types.hpp"

void draw_sprite_affine(const Image& atlas, const Sprite& spr, const Transform& t, Image& canvas);
int resolve_child_frame(const Element& e, int parent_frame, int instance_start, int child_total);

void accumulate_bounds_symbol(
    const Symbol& sym,
    int frame,
    const Transform& parent,
    const std::unordered_map<std::string, Symbol>& symbols,
    const std::unordered_map<std::string, Sprite>& atlas,
    Bounds& bounds
);

void render_symbol(
    const Symbol& sym,
    int frame,
    const Transform& parent,
    const std::unordered_map<std::string, Symbol>& symbols,
    const std::unordered_map<std::string, Sprite>& atlas,
    const Image& atlas_img,
    Image& canvas
);
