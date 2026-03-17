#pragma once

#include "types.hpp"

Transform multiply(const Transform& parent, const Transform& local);
bool invert(const Transform& t, Transform& inv);
Transform apply_pivot(const Transform& t, double px, double py);
