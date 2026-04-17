#include <iostream>
#include <string>

#include "exporter.hpp"


int main(int argc, char** argv) {
    if (argc < 3) {
        std::cerr << "uso: spritemap_export Animation.json spritemap1.json [out_dir] [anims.xml]\n";
        return 1;
    }

    std::string animation_path = argv[1];
    std::string atlas_path = argv[2];
    std::string out_dir = (argc >= 4) ? argv[3] : "out";
    std::string xml_path = (argc >= 5) ? argv[4] : "";

    return run_export(animation_path, atlas_path, out_dir, xml_path, nullptr, nullptr, "", false, true);
}
