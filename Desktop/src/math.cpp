#include <cmath>

#include "math.hpp"

Transform multiply(const Transform& p, const Transform& l) {
    Transform r;
    r.a = p.a * l.a + p.c * l.b;
    r.b = p.b * l.a + p.d * l.b;
    r.c = p.a * l.c + p.c * l.d;
    r.d = p.b * l.c + p.d * l.d;
    r.tx = p.a * l.tx + p.c * l.ty + p.tx;
    r.ty = p.b * l.tx + p.d * l.ty + p.ty;
    return r;
}

bool invert(const Transform& t, Transform& inv) {
    double det = t.a * t.d - t.b * t.c;
    if (std::abs(det) < 1e-10) return false;
    double inv_det = 1.0 / det;
    inv.a = t.d * inv_det;
    inv.b = -t.b * inv_det;
    inv.c = -t.c * inv_det;
    inv.d = t.a * inv_det;
    inv.tx = (t.c * t.ty - t.d * t.tx) * inv_det;
    inv.ty = (t.b * t.tx - t.a * t.ty) * inv_det;
    return true;
}

Transform apply_pivot(const Transform& t, double px, double py) {
    if (px == 0.0 && py == 0.0) return t;
    Transform r = t;
    // Transform around pivot: T(p) * M * T(-p)
    r.tx = t.tx + px - (t.a * px + t.c * py);
    r.ty = t.ty + py - (t.b * px + t.d * py);
    return r;
}
