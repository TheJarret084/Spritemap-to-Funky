#pragma once

#include <functional>
#include <string>

using ProgressCallback = std::function<void(int current, int total, const std::string& anim)>;

// Returns 0 on success, non-zero on error.
int run_export(
    const std::string& animation_path,
    const std::string& atlas_path,
    const std::string& out_dir,
    const std::string& xml_path,
    ProgressCallback progress_cb = nullptr,
    std::string* log_out = nullptr,
    const std::string& aseprite_path = "",
    bool export_ase = false,
    bool export_frames = true
);
