#include "i18n.hpp"

#include <cctype>
#include <regex>

#include "utils.hpp"

static std::string trim_copy(const std::string& s) {
    size_t start = 0;
    while (start < s.size() && std::isspace(static_cast<unsigned char>(s[start]))) start++;
    size_t end = s.size();
    while (end > start && std::isspace(static_cast<unsigned char>(s[end - 1]))) end--;
    return s.substr(start, end - start);
}

static void replace_all(std::string& s, const std::string& from, const std::string& to) {
    if (from.empty()) return;
    size_t pos = 0;
    while ((pos = s.find(from, pos)) != std::string::npos) {
        s.replace(pos, from.size(), to);
        pos += to.size();
    }
}

static std::string decode_xml_entities(std::string s) {
    replace_all(s, "&quot;", "\"");
    replace_all(s, "&apos;", "'");
    replace_all(s, "&lt;", "<");
    replace_all(s, "&gt;", ">");
    replace_all(s, "&amp;", "&");
    return s;
}

static std::string unescape_backslash(std::string s) {
    replace_all(s, "\\n", "\n");
    replace_all(s, "\\t", "\t");
    return s;
}

bool I18n::load_xml(const std::string& path, std::string* error) {
    strings_.clear();
    if (path.empty()) {
        if (error) *error = "empty path";
        return false;
    }

    std::string xml;
    try {
        xml = read_file_strip_bom(path);
    } catch (const std::exception& e) {
        if (error) *error = e.what();
        return false;
    }

    std::regex string_tag(R"REGEX(<string\s+[^>]*?>[\s\S]*?</string>)REGEX");
    std::regex attr_re(R"REGEX((\w+)="([^"]*)")REGEX");

    auto tags_begin = std::sregex_iterator(xml.begin(), xml.end(), string_tag);
    auto tags_end = std::sregex_iterator();
    for (auto it = tags_begin; it != tags_end; ++it) {
        std::string tag = it->str();
        std::string key;

        auto attr_begin = std::sregex_iterator(tag.begin(), tag.end(), attr_re);
        auto attr_end = std::sregex_iterator();
        for (auto ait = attr_begin; ait != attr_end; ++ait) {
            std::string k = (*ait)[1].str();
            std::string v = (*ait)[2].str();
            if (k == "key" || k == "id" || k == "name") key = v;
        }
        if (key.empty()) continue;

        size_t gt = tag.find('>');
        size_t end = tag.rfind("</string>");
        if (gt == std::string::npos || end == std::string::npos || end <= gt) continue;
        std::string value = tag.substr(gt + 1, end - gt - 1);
        value = trim_copy(unescape_backslash(decode_xml_entities(value)));
        strings_[key] = value;
    }

    if (strings_.empty()) {
        if (error) *error = "no <string> entries";
        return false;
    }
    return true;
}

void I18n::clear() {
    strings_.clear();
}

const char* I18n::tr(const char* key, const char* fallback) {
    if (!key) return "";
    auto it = strings_.find(key);
    if (it != strings_.end()) return it->second.c_str();

    auto fit = fallback_.find(key);
    if (fit == fallback_.end()) {
        auto res = fallback_.emplace(key, fallback ? fallback : "");
        return res.first->second.c_str();
    }
    return fit->second.c_str();
}
