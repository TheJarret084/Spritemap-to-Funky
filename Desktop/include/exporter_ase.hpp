#pragma once

#include <string>
#include <vector>

int export_ase_from_layers(
    const std::string& layers_dir,
    const std::vector<std::string>& layer_names,
    int frame_count,
    const std::string& out_ase,
    const std::string& aseprite_path,
    std::string* log_out
);
