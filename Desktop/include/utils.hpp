#pragma once

#include <string>
#include <vector>

#include "nlohmann/json.hpp"

std::string read_file_strip_bom(const std::string& path);
std::vector<std::string> split_csv(const std::string& s);
std::string trim(std::string s);
std::vector<int> parse_indices(const std::string& s);
std::string sanitize_name(std::string s);

template <typename T>
T jvalue_or(const nlohmann::json& j, const char* key, const T& def) {
    if (!j.is_object()) return def;
    auto it = j.find(key);
    if (it == j.end() || it->is_null()) return def;
    try {
        return it->get<T>();
    } catch (...) {
        return def;
    }
}

inline std::string jstring_or(const nlohmann::json& j, const char* key, const std::string& def) {
    return jvalue_or<std::string>(j, key, def);
}
