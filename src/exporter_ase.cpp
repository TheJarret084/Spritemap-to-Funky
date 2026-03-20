#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>

#include "exporter_ase.hpp"

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

static std::string quote_arg(const std::string& s) {
    std::string out;
    out.reserve(s.size() + 2);
    out.push_back('"');
    for (char c : s) {
        if (c == '"') out += "\\\"";
        else out.push_back(c);
    }
    out.push_back('"');
    return out;
}

static int run_command(const std::string& cmd, std::string* log_out) {
    int code = std::system(cmd.c_str());
    if (code != 0) {
        log_line(log_out, "comando fallo (" + std::to_string(code) + "): " + cmd + "\n", true);
    }
    return code;
}

static std::string lua_escape(std::string s) {
    std::string out;
    out.reserve(s.size() + 8);
    for (char c : s) {
        if (c == '\\') out += "\\\\";
        else if (c == '"') out += "\\\"";
        else out.push_back(c);
    }
    return out;
}

static std::string to_lua_path(const std::string& s) {
    std::string out = s;
    for (char& c : out) {
        if (c == '\\') c = '/';
    }
    return out;
}

int export_ase_from_layers(
    const std::string& layers_dir,
    const std::vector<std::string>& layer_names,
    int frame_count,
    const std::string& out_ase,
    const std::string& aseprite_path,
    std::string* log_out
) {
    if (layer_names.empty() || frame_count <= 0) return 0;

    std::filesystem::path script_path = std::filesystem::path(layers_dir) / "_build_ase.lua";

    std::ostringstream lua;
    lua << "local out_path = \"" << lua_escape(to_lua_path(out_ase)) << "\"\n";
    lua << "local layers_dir = \"" << lua_escape(to_lua_path(layers_dir)) << "\"\n";
    lua << "local layer_names = {";
    for (size_t i = 0; i < layer_names.size(); ++i) {
        if (i) lua << ",";
        lua << "\"" << lua_escape(layer_names[i]) << "\"";
    }
    lua << "}\n";
    lua << "local frame_count = " << frame_count << "\n";
    lua << "local function img_path(layer, idx)\n";
    lua << "  return layers_dir .. '/' .. layer .. '/' .. layer .. '_' .. string.format('%04d', idx) .. '.png'\n";
    lua << "end\n";
    lua << "local first_img = Image{ fromFile = img_path(layer_names[1], 0) }\n";
    lua << "local spr = Sprite(first_img.width, first_img.height)\n";
    lua << "for i=2,frame_count do spr:newFrame() end\n";
    lua << "if #spr.layers > 0 then spr:deleteLayer(spr.layers[1]) end\n";
    lua << "for _, name in ipairs(layer_names) do\n";
    lua << "  local layer = spr:newLayer()\n";
    lua << "  layer.name = name\n";
    lua << "  for i=0,frame_count-1 do\n";
    lua << "    local img = Image{ fromFile = img_path(name, i) }\n";
    lua << "    spr:newCel(layer, spr.frames[i+1], img, Point(0,0))\n";
    lua << "  end\n";
    lua << "end\n";
    lua << "spr:saveAs(out_path)\n";

    std::ofstream f(script_path, std::ios::binary);
    if (!f.is_open()) {
        log_line(log_out, "no pude escribir script lua: " + script_path.string() + "\n", true);
        return 2;
    }
    f << lua.str();
    f.close();

    std::string exe = aseprite_path.empty() ? "aseprite" : aseprite_path;
    std::string cmd = quote_arg(exe) + " -b --script " + quote_arg(script_path.string());
    int ret = run_command(cmd, log_out);

    std::error_code ec;
    std::filesystem::remove(script_path, ec);

    if (ret == 0) {
        log_line(log_out, "aseprite: " + out_ase + "\n", false);
    }
    return ret;
}
