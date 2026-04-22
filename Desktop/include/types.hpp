#pragma once

#include <cstdint>
#include <string>
#include <vector>

struct Transform {
    double a = 1.0;
    double b = 0.0;
    double c = 0.0;
    double d = 1.0;
    double tx = 0.0;
    double ty = 0.0;
};

struct Sprite {
    int x = 0;
    int y = 0;
    int w = 0;
    int h = 0;
    bool rotated = false;
};

struct Element {
    enum class Type { AtlasSprite, SymbolInstance } type;
    std::string name;
    Transform transform;
    int first_frame = 0;
    std::string symbol_type;
    std::string loop;
};

struct Frame {
    int start = 0;
    int duration = 0;
    std::vector<Element> elements;
};

struct Layer {
    std::vector<Frame> frames;
};

struct Timeline {
    std::vector<Layer> layers;
    int total_frames = 0;
};

struct Symbol {
    std::string name;
    Timeline timeline;
};

struct AnimDef {
    std::string name;
    std::string source_anim;
    std::vector<int> indices;
};

struct Image {
    int w = 0;
    int h = 0;
    std::vector<uint8_t> pixels; // RGBA
};

struct Bounds {
    double minx = 0.0;
    double miny = 0.0;
    double maxx = 0.0;
    double maxy = 0.0;
    bool initialized = false;
};
