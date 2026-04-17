#pragma once

#include <string>
#include <unordered_map>

class I18n {
public:
    bool load_xml(const std::string& path, std::string* error = nullptr);
    void clear();
    const char* tr(const char* key, const char* fallback);

private:
    std::unordered_map<std::string, std::string> strings_;
    std::unordered_map<std::string, std::string> fallback_;
};
