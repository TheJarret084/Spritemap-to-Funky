#pragma once

#include <string>

// Returns 0 on success, non-zero on error.
int run_export(
    const std::string& animation_path,
    const std::string& atlas_path,
    const std::string& out_dir,
    const std::string& xml_path,
    std::string* log_out
);
