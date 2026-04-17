#include <fstream>
#include <sstream>
#include <stdexcept>

#include "utils.hpp"

std::string read_file_strip_bom(const std::string& path) {
    std::ifstream f(path, std::ios::binary);
    if (!f.is_open()) {
        throw std::runtime_error("no pude abrir archivo: " + path);
    }
    std::string s((std::istreambuf_iterator<char>(f)), {});
    if (s.size() >= 3 &&
        static_cast<unsigned char>(s[0]) == 0xEF &&
        static_cast<unsigned char>(s[1]) == 0xBB &&
        static_cast<unsigned char>(s[2]) == 0xBF) {
        s.erase(0, 3);
    }
    return s;
}

std::vector<std::string> split_csv(const std::string& s) {
    std::vector<std::string> out;
    std::stringstream ss(s);
    std::string item;
    while (std::getline(ss, item, ',')) {
        if (!item.empty()) out.push_back(item);
    }
    return out;
}

std::string trim(std::string s) {
    const char* ws = " \t\r\n";
    s.erase(0, s.find_first_not_of(ws));
    s.erase(s.find_last_not_of(ws) + 1);
    return s;
}

std::vector<int> parse_indices(const std::string& s) {
    std::vector<int> out;
    if (s.empty()) return out;
    for (auto part : split_csv(s)) {
        part = trim(part);
        if (part.empty()) continue;
        auto dots = part.find("..");
        if (dots != std::string::npos) {
            int a = std::stoi(part.substr(0, dots));
            int b = std::stoi(part.substr(dots + 2));
            if (a <= b) {
                for (int i = a; i <= b; ++i) out.push_back(i);
            } else {
                for (int i = a; i >= b; --i) out.push_back(i);
            }
        } else {
            out.push_back(std::stoi(part));
        }
    }
    return out;
}

std::string sanitize_name(std::string s) {
    if (s.empty()) return "main";
    for (char& c : s) {
        if (c == ' ') c = '_';
        if (c == '/' || c == '\\' || c == ':' || c == '*' || c == '?' ||
            c == '"' || c == '<' || c == '>' || c == '|') {
            c = '_';
        }
    }
    return s;
}
