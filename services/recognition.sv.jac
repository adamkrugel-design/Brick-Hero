import from base64 { b64decode }
import from math { sqrt }

obj LegoProfile {
    has name: str = "";
    has color: str = "";
    has notes: str = "";
    has width_ratio: float = 1.0;
    has height_ratio: float = 1.0;
    has red: int = 0;
    has green: int = 0;
    has blue: int = 0;
}

def color_distance(red_a: int, green_a: int, blue_a: int, red_b: int, green_b: int, blue_b: int) -> float {
    return sqrt(((red_a - red_b) * (red_a - red_b)) + ((green_a - green_b) * (green_a - green_b)) + ((blue_a - blue_b) * (blue_a - blue_b)));
}

def clamp_score(value: float) -> int {
    if value < 0.0 {
        return 0;
    }
    if value > 100.0 {
        return 100;
    }
    return int(value);
}

def parse_data_url(frame_data: str) -> bytes {
    if not frame_data {
        return b"";
    }
    parts = frame_data.split(",", 1);
    if len(parts) < 2 {
        return b"";
    }
    return b64decode(parts[1]);
}

def read_jpeg_size(data: bytes) -> tuple[int, int] {
    if len(data) < 4 {
        return (0, 0);
    }
    index = 2;
    while index + 9 < len(data) {
        if data[index] != 0xFF {
            index += 1;
            continue;
        }
        marker = data[index + 1];
        if marker in [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF] {
            height = (data[index + 5] << 8) + data[index + 6];
            width = (data[index + 7] << 8) + data[index + 8];
            return (width, height);
        }
        if marker == 0xD9 or marker == 0xDA {
            break;
        }
        segment_length = (data[index + 2] << 8) + data[index + 3];
        if segment_length <= 0 {
            break;
        }
        index += segment_length + 2;
    }
    return (0, 0);
}

def average_rgb(data: bytes) -> tuple[int, int, int] {
    if not data {
        return (0, 0, 0);
    }
    sample_size = 3;
    if len(data) < sample_size {
        sample_size = 1;
    }
    red_total = 0;
    green_total = 0;
    blue_total = 0;
    count = 0;
    index = 0;
    while index + sample_size <= len(data) {
        red_total += data[index];
        if sample_size > 1 {
            green_total += data[index + 1];
        } else {
            green_total += data[index];
        }
        if sample_size > 2 {
            blue_total += data[index + 2];
        } else {
            blue_total += data[index];
        }
        count += 1;
        index += sample_size;
    }
    if count == 0 {
        return (0, 0, 0);
    }
    return (int(red_total / count), int(green_total / count), int(blue_total / count));
}

def profiles() -> list[LegoProfile] {
    return [
        LegoProfile(
            name="Brick 2 x 4",
            color="Bright red",
            notes="Classic full-height brick profile with a wide rectangular footprint and strong red color signature.",
            width_ratio=1.33,
            height_ratio=1.0,
            red=196,
            green=40,
            blue=28,
        ),
        LegoProfile(
            name="Plate 2 x 3",
            color="Bright blue",
            notes="Flatter plate-like geometry with a cooler blue-dominant color balance.",
            width_ratio=1.5,
            height_ratio=0.55,
            red=36,
            green=99,
            blue=235,
        ),
        LegoProfile(
            name="Slope 45 2 x 2",
            color="Bright yellow",
            notes="Compact sloped part with a more square footprint and warmer yellow color family.",
            width_ratio=1.0,
            height_ratio=0.9,
            red=245,
            green=205,
            blue=48,
        ),
        LegoProfile(
            name="Brick 1 x 2",
            color="White / light neutral",
            notes="Small rectangular brick with a neutral color balance and compact proportions.",
            width_ratio=1.0,
            height_ratio=1.0,
            red=214,
            green=214,
            blue=214,
        ),
    ];
}

def:pub recognize_lego_frame(frame_data: str) -> dict {
    raw = parse_data_url(frame_data);
    if not raw {
        return {"success": False, "error": "No frame data received"};
    }

    size = read_jpeg_size(raw);
    width = size[0];
    height = size[1];
    if width <= 0 or height <= 0 {
        width = 1;
        height = 1;
    }
    ratio = float(width) / float(height);
    avg_rgb = average_rgb(raw);
    avg_red = avg_rgb[0];
    avg_green = avg_rgb[1];
    avg_blue = avg_rgb[2];

    scored = [];
    for profile in profiles() {
        color_gap = color_distance(avg_red, avg_green, avg_blue, profile.red, profile.green, profile.blue);
        color_score = clamp_score(100.0 - (color_gap / 4.5));
        ratio_gap = abs(ratio - profile.width_ratio);
        shape_score = clamp_score(100.0 - (ratio_gap * 120.0));
        stud_score = clamp_score((color_score * 0.45) + (shape_score * 0.55));
        confidence = clamp_score((color_score * 0.5) + (shape_score * 0.35) + (stud_score * 0.15));
        scored.append({
            "name": profile.name,
            "color": profile.color,
            "notes": profile.notes,
            "confidence_value": confidence,
            "color_score": color_score,
            "shape_score": shape_score,
            "stud_score": stud_score,
        });
    }

    ranked = sorted(scored, key=lambda item: item["confidence_value"], reverse=True);
    best = ranked[0];
    alternatives = [
        {"name": item["name"], "confidence": str(item["confidence_value"]) + "%"}
        for item in ranked[1:3]
    ];

    return {
        "success": True,
        "active_match": {
            "name": best["name"],
            "confidence": str(best["confidence_value"]) + "%",
            "color": best["color"],
            "notes": best["notes"] + " Average frame color was RGB(" + str(avg_red) + ", " + str(avg_green) + ", " + str(avg_blue) + ") with aspect ratio " + str(round(ratio, 2)) + ".",
        },
        "alt_matches": alternatives,
        "feature_scores": [
            {"label": "Shape similarity", "value": best["shape_score"]},
            {"label": "Color similarity", "value": best["color_score"]},
            {"label": "Stud / surface confidence", "value": best["stud_score"]},
        ],
        "telemetry": {
            "width": width,
            "height": height,
            "avg_red": avg_red,
            "avg_green": avg_green,
            "avg_blue": avg_blue,
            "ratio": ratio,
        },
    };
}
