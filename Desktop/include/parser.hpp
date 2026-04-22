#pragma once

#include <string>
#include <vector>

#include "nlohmann/json.hpp"

#include "types.hpp"

std::vector<AnimDef> parse_anim_xml(const std::string& path);
Transform parse_m3d(const nlohmann::json& j);
Timeline parse_timeline(const nlohmann::json& tl);
