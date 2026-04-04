import from base64 { b64decode }
import from requests { get, post }


def parse_data_url(frame_data: str) -> tuple[str, bytes] {
    if not frame_data {
        return ("image/jpeg", b"");
    }
    parts = frame_data.split(",", 1);
    if len(parts) < 2 {
        return ("image/jpeg", b"");
    }
    header = parts[0];
    mime_type = "image/jpeg";
    if ";" in header and ":" in header {
        mime_type = header.split(":", 1)[1].split(";", 1)[0];
    }
    try {
        decoded = b64decode(parts[1]);
        return (mime_type, decoded);
    } except Exception {
        return (mime_type, b"");
    }
}


def safe_get(source: any, key: str, fallback: any) -> any {
    if source == None {
        return fallback;
    }
    try {
        value = source.get(key);
        if value == None {
            return fallback;
        }
        return value;
    } except Exception {
        return fallback;
    }
}


def normalize_items(payload: any) -> list {
    if payload == None {
        return [];
    }
    try {
        payload_type = type(payload);
        if payload_type == list {
            return payload;
        }
        if payload_type == dict {
            for key in ["items", "predictions", "results"] {
                value = safe_get(payload, key, []);
                if type(value) == list {
                    return value;
                }
            }
        }
    } except Exception {
    }
    return [];
}


def item_name(item: any) -> str {
    for key in ["name", "label", "class_name", "id", "part_num"] {
        value = safe_get(item, key, "");
        if value {
            return str(value);
        }
    }
    return "Unknown part";
}


def item_confidence(item: any) -> int {
    for key in ["score", "confidence", "probability"] {
        value = safe_get(item, key, None);
        if value != None {
            try {
                numeric = float(value);
                if numeric <= 1.0 {
                    numeric = numeric * 100.0;
                }
                return int(round(numeric));
            } except Exception {
            }
        }
    }
    return 0;
}


def item_notes(item: any) -> str {
    for key in ["description", "category", "part_num", "id"] {
        value = safe_get(item, key, "");
        if value {
            return str(value);
        }
    }
    return "Trained Brickognize classification result.";
}


def bricklink_part_id_from_url(url: str) -> str {
    if not url {
        return "";
    }
    if "?P=" in url {
        part_section = url.split("?P=", 1)[1];
        return part_section.split("&", 1)[0].strip();
    }
    if "?S=" in url {
        part_section = url.split("?S=", 1)[1];
        return part_section.split("&", 1)[0].strip();
    }
    return "";
}


def item_part_id(item: any) -> str {
    external_sites = safe_get(item, "external_sites", []);
    if type(external_sites) == list {
        for site in external_sites {
            site_name = str(safe_get(site, "name", "")).lower();
            site_url = str(safe_get(site, "url", ""));
            if site_name == "bricklink" and site_url {
                bricklink_part_id = bricklink_part_id_from_url(site_url);
                if bricklink_part_id {
                    return bricklink_part_id;
                }
            }
        }
    }

    for key in ["part_num", "item_no", "id", "part_id"] {
        value = safe_get(item, key, "");
        if value {
            return str(value);
        }
    }

    identifiers = safe_get(item, "identifiers", None);
    if type(identifiers) == dict {
        for key in ["bricklink", "bricklink_id", "part_num", "item_no", "id"] {
            value = safe_get(identifiers, key, "");
            if value {
                return str(value);
            }
        }
    }

    return "";
}


def item_bricklink_url(item: any, part_id: str) -> str {
    external_sites = safe_get(item, "external_sites", []);
    if type(external_sites) == list {
        for site in external_sites {
            site_name = str(safe_get(site, "name", "")).lower();
            site_url = str(safe_get(site, "url", ""));
            if site_name == "bricklink" and site_url {
                return site_url;
            }
        }
    }
    if part_id {
        return "https://www.bricklink.com/v2/catalog/catalogitem.page?P=" + part_id;
    }
    return "";
}


def strip_tags(text: str) -> str {
    cleaned = "";
    inside_tag = False;
    for ch in text {
        if ch == "<" {
            inside_tag = True;
        } elif ch == ">" {
            inside_tag = False;
        } elif not inside_tag {
            cleaned = cleaned + ch;
        }
    }
    cleaned = cleaned.replace("&nbsp;", " ");
    cleaned = cleaned.replace("&amp;", "&");
    cleaned = cleaned.replace("\n", " ");
    cleaned = cleaned.replace("\r", " ");
    cleaned = cleaned.replace("\t", " ");
    while "  " in cleaned {
        cleaned = cleaned.replace("  ", " ");
    }
    return cleaned.strip();
}


def parse_bricklink_color(page_text: str) -> dict {
    if not page_text {
        return {"label": "Unknown", "source": "BrickLink"};
    }

    for marker in ["Color:", "Known Color:"] {
        if marker not in page_text {
            continue;
        }
        section = page_text.split(marker, 1)[1];
        for stop in ["Years Released:", "Year Released:", "Weight:", "Item Dim", "<br", "</td>"] {
            if stop in section {
                section = section.split(stop, 1)[0];
            }
        }
        cleaned = strip_tags(section);
        if cleaned and len(cleaned) <= 40 and "function" not in cleaned.lower() and "{" not in cleaned and "}" not in cleaned {
            return {"label": cleaned, "source": "BrickLink"};
        }
    }

    return {"label": "Unknown", "source": "BrickLink"};
}


def parse_years_released(page_text: str) -> dict {
    if not page_text {
        return {"label": "Unknown", "start": "", "end": "", "source": "BrickLink"};
    }

    marker = "Years Released:";
    if marker not in page_text {
        marker = "Year Released:";
    }
    if marker not in page_text {
        return {"label": "Unknown", "start": "", "end": "", "source": "BrickLink"};
    }

    section = page_text.split(marker, 1)[1];
    for stop in ["Weight:", "Item Dim", "<br", "</td>"] {
        if stop in section {
            section = section.split(stop, 1)[0];
        }
    }
    section = strip_tags(section);

    year_tokens = [];
    current = "";
    for ch in section {
        if ch >= "0" and ch <= "9" {
            current = current + ch;
        } else {
            if len(current) == 4 {
                year_tokens.append(current);
            }
            current = "";
        }
    }
    if len(current) == 4 {
        year_tokens.append(current);
    }

    if len(year_tokens) >= 2 {
        start_year = year_tokens[0];
        end_year = year_tokens[1];
        return {"label": start_year + "–" + end_year, "start": start_year, "end": end_year, "source": "BrickLink"};
    }
    if len(year_tokens) == 1 {
        return {"label": year_tokens[0], "start": year_tokens[0], "end": year_tokens[0], "source": "BrickLink"};
    }
    return {"label": "Unknown", "start": "", "end": "", "source": "BrickLink"};
}


def bricklink_color_palette() -> list {
    return [
        {"label": "Black", "r": 27, "g": 42, "b": 52, "family": "neutral"},
        {"label": "White", "r": 242, "g": 243, "b": 242, "family": "neutral"},
        {"label": "Light Bluish Gray", "r": 160, "g": 165, "b": 169, "family": "neutral"},
        {"label": "Dark Bluish Gray", "r": 99, "g": 95, "b": 98, "family": "neutral"},
        {"label": "Red", "r": 196, "g": 40, "b": 27, "family": "red"},
        {"label": "Dark Red", "r": 123, "g": 46, "b": 47, "family": "red"},
        {"label": "Blue", "r": 13, "g": 105, "b": 171, "family": "blue"},
        {"label": "Dark Blue", "r": 0, "g": 32, "b": 96, "family": "blue"},
        {"label": "Green", "r": 40, "g": 127, "b": 70, "family": "green"},
        {"label": "Dark Green", "r": 40, "g": 70, "b": 45, "family": "green"},
        {"label": "Lime", "r": 168, "g": 189, "b": 61, "family": "green"},
        {"label": "Yellow", "r": 245, "g": 205, "b": 47, "family": "yellow"},
        {"label": "Tan", "r": 228, "g": 205, "b": 158, "family": "tan"},
        {"label": "Dark Tan", "r": 149, "g": 138, "b": 115, "family": "tan"},
        {"label": "Brown", "r": 124, "g": 92, "b": 70, "family": "brown"},
        {"label": "Reddish Brown", "r": 105, "g": 64, "b": 40, "family": "brown"},
        {"label": "Orange", "r": 218, "g": 133, "b": 65, "family": "orange"},
        {"label": "Dark Orange", "r": 160, "g": 95, "b": 53, "family": "orange"},
        {"label": "Pink", "r": 255, "g": 152, "b": 220, "family": "pink"},
        {"label": "Purple", "r": 123, "g": 47, "b": 123, "family": "purple"},
        {"label": "Trans-Clear", "r": 236, "g": 236, "b": 236, "family": "neutral"},
    ];
}


def color_family_from_text(text: str) -> str {
    lowered = str(text).lower();
    if not lowered {
        return "";
    }
    if "light bluish gray" in lowered or "dark bluish gray" in lowered or "grey" in lowered or "gray" in lowered or "black" in lowered or "white" in lowered or "clear" in lowered {
        return "neutral";
    }
    if "dark red" in lowered or "red" in lowered {
        return "red";
    }
    if "dark blue" in lowered or "blue" in lowered {
        return "blue";
    }
    if "dark green" in lowered or "lime" in lowered or "green" in lowered {
        return "green";
    }
    if "yellow" in lowered {
        return "yellow";
    }
    if "dark tan" in lowered or "tan" in lowered or "beige" in lowered {
        return "tan";
    }
    if "reddish brown" in lowered or "brown" in lowered {
        return "brown";
    }
    if "dark orange" in lowered or "orange" in lowered {
        return "orange";
    }
    if "pink" in lowered {
        return "pink";
    }
    if "purple" in lowered {
        return "purple";
    }
    return "";
}


def nearest_bricklink_color(avg_red: int, avg_green: int, avg_blue: int, preferred_family: str = "") -> dict {
    palette = bricklink_color_palette();
    best_match = {"label": "Unknown", "r": avg_red, "g": avg_green, "b": avg_blue, "family": preferred_family};
    best_distance = -1;
    channel_max = avg_red;
    if avg_green > channel_max {
        channel_max = avg_green;
    }
    if avg_blue > channel_max {
        channel_max = avg_blue;
    }
    channel_min = avg_red;
    if avg_green < channel_min {
        channel_min = avg_green;
    }
    if avg_blue < channel_min {
        channel_min = avg_blue;
    }
    saturation = channel_max - channel_min;
    brightness = int(round((avg_red + avg_green + avg_blue) / 3));
    for swatch in palette {
        distance = ((avg_red - swatch["r"]) * (avg_red - swatch["r"])) + ((avg_green - swatch["g"]) * (avg_green - swatch["g"])) + ((avg_blue - swatch["b"]) * (avg_blue - swatch["b"]));
        swatch_max = swatch["r"];
        if swatch["g"] > swatch_max {
            swatch_max = swatch["g"];
        }
        if swatch["b"] > swatch_max {
            swatch_max = swatch["b"];
        }
        swatch_min = swatch["r"];
        if swatch["g"] < swatch_min {
            swatch_min = swatch["g"];
        }
        if swatch["b"] < swatch_min {
            swatch_min = swatch["b"];
        }
        swatch_saturation = swatch_max - swatch_min;
        swatch_brightness = int(round((swatch["r"] + swatch["g"] + swatch["b"]) / 3));
        brightness_gap = brightness - swatch_brightness;
        if brightness_gap < 0 {
            brightness_gap = 0 - brightness_gap;
        }
        distance = distance + (brightness_gap * 12);
        if saturation >= 45 and swatch_saturation < 20 {
            distance = distance + 22000;
        }
        if saturation >= 32 and swatch_saturation < 30 {
            distance = distance + 12000;
        }
        if saturation <= 14 and swatch_saturation > 85 {
            distance = distance + 9000;
        }
        if brightness <= 55 and swatch["label"] == "White" {
            distance = distance + 18000;
        }
        if brightness >= 220 and swatch["label"] == "Black" {
            distance = distance + 18000;
        }
        if saturation >= 26 and (swatch["label"] == "Light Bluish Gray" or swatch["label"] == "Dark Bluish Gray") {
            distance = distance + 16000;
        }
        if preferred_family != "" and swatch["family"] != preferred_family {
            distance = distance + 9000;
        }
        if avg_red >= avg_green + 18 and avg_red >= avg_blue + 18 and (swatch["family"] == "blue" or swatch["family"] == "green") {
            distance = distance + 9000;
        }
        if avg_blue >= avg_red + 18 and avg_blue >= avg_green + 18 and (swatch["family"] == "red" or swatch["family"] == "orange" or swatch["family"] == "brown") {
            distance = distance + 9000;
        }
        if avg_green >= avg_red + 18 and avg_green >= avg_blue + 18 and (swatch["family"] == "red" or swatch["family"] == "blue" or swatch["family"] == "brown") {
            distance = distance + 7000;
        }
        if best_distance < 0 or distance < best_distance {
            best_distance = distance;
            best_match = swatch;
        }
    }
    return best_match;
}


def estimate_image_color(raw: bytes, preferred_family: str = "") -> dict {
    if not raw {
        return {"label": "Unknown", "source": "Image fallback", "rgb": ""};
    }

    sample_limit = len(raw);
    if sample_limit > 12288 {
        sample_limit = 12288;
    }
    if sample_limit < 24 {
        return {"label": "Unknown", "source": "Image fallback", "rgb": ""};
    }

    red_total = 0;
    green_total = 0;
    blue_total = 0;
    pixel_count = 0;
    idx = 8;
    stride = 29;
    while idx + 2 < sample_limit {
        first = int(raw[idx]);
        second = int(raw[idx + 1]);
        third = int(raw[idx + 2]);
        channel_max = first;
        if second > channel_max {
            channel_max = second;
        }
        if third > channel_max {
            channel_max = third;
        }
        channel_min = first;
        if second < channel_min {
            channel_min = second;
        }
        if third < channel_min {
            channel_min = third;
        }
        if channel_max - channel_min > 18 {
            red_total = red_total + first;
            green_total = green_total + second;
            blue_total = blue_total + third;
            pixel_count = pixel_count + 1;
        }
        idx = idx + stride;
    }

    if pixel_count == 0 {
        return {"label": "Unknown", "source": "Image fallback", "rgb": ""};
    }

    avg_red = int(round(red_total / pixel_count));
    avg_green = int(round(green_total / pixel_count));
    avg_blue = int(round(blue_total / pixel_count));
    rgb_text = str(avg_red) + ", " + str(avg_green) + ", " + str(avg_blue);
    matched = nearest_bricklink_color(avg_red, avg_green, avg_blue, preferred_family);

    return {
        "label": str(matched["label"]),
        "source": "Image fallback → BrickLink match",
        "rgb": rgb_text,
        "bricklink_match": str(matched["label"]),
    };
}


def fetch_bricklink_metadata(part_id: str, bricklink_url: str) -> dict {
    if not bricklink_url and not part_id {
        return {
            "years_released": {"label": "Unknown", "start": "", "end": "", "source": "BrickLink"},
            "color": {"label": "Unknown", "source": "BrickLink"},
        };
    }

    target_url = bricklink_url;
    if not target_url {
        target_url = "https://www.bricklink.com/v2/catalog/catalogitem.page?P=" + part_id;
    }

    try {
        response = get(
            target_url,
            headers={
                "user-agent": "Mozilla/5.0 (compatible; JacCoder BrickLink lookup)",
                "accept": "text/html,application/xhtml+xml",
            },
            timeout=20,
        );
    } except Exception as e {
        return {
            "years_released": {"label": "Unavailable", "start": "", "end": "", "source": "BrickLink", "error": "BrickLink lookup failed: " + str(e)},
            "color": {"label": "Unavailable", "source": "BrickLink", "error": "BrickLink lookup failed: " + str(e)},
        };
    }

    if response.status_code < 200 or response.status_code >= 300 {
        return {
            "years_released": {"label": "Unavailable", "start": "", "end": "", "source": "BrickLink", "error": "BrickLink returned status " + str(response.status_code)},
            "color": {"label": "Unavailable", "source": "BrickLink", "error": "BrickLink returned status " + str(response.status_code)},
        };
    }

    return {
        "years_released": parse_years_released(response.text),
        "color": parse_bricklink_color(response.text),
    };
}


def:pub recognize_lego_frame(frame_data: str) -> dict {
    parsed = parse_data_url(frame_data);
    mime_type = parsed[0];
    raw = parsed[1];
    if not raw {
        return {"success": False, "error": "No frame data received"};
    }

    extension = ".jpg";
    if mime_type == "image/png" {
        extension = ".png";
    }

    try {
        response = post(
            "https://api.brickognize.com/predict/",
            headers={"accept": "application/json"},
            files={"query_image": ("capture" + extension, raw, mime_type)},
            timeout=30,
        );
    } except Exception as e {
        return {"success": False, "error": "Brickognize request failed: " + str(e)};
    }

    if response.status_code < 200 or response.status_code >= 300 {
        return {"success": False, "error": "Brickognize returned status " + str(response.status_code)};
    }

    try {
        payload = response.json();
    } except Exception as e {
        return {"success": False, "error": "Brickognize response was not valid JSON: " + str(e)};
    }

    items = normalize_items(payload);
    best_name = "Unknown part";
    best_confidence_value = 0;
    best_notes = "Trained Brickognize classification result.";
    best_part_id = "";
    best_bricklink_url = "";

    if len(items) > 0 {
        first = items[0];
        best_name = item_name(first);
        best_confidence_value = item_confidence(first);
        best_notes = item_notes(first);
        best_part_id = item_part_id(first);
        best_bricklink_url = item_bricklink_url(first, best_part_id);
    } else {
        best_name = str(safe_get(payload, "name", "Unknown part"));
        best_confidence_value = item_confidence(payload);
        best_notes = item_notes(payload);
        best_part_id = item_part_id(payload);
        best_bricklink_url = item_bricklink_url(payload, best_part_id);
    }

    bricklink_metadata = fetch_bricklink_metadata(best_part_id, best_bricklink_url);
    years_released = safe_get(bricklink_metadata, "years_released", {"label": "Unknown", "start": "", "end": "", "source": "BrickLink"});
    bricklink_color = safe_get(bricklink_metadata, "color", {"label": "Unknown", "source": "BrickLink"});
    bricklink_color_label = str(safe_get(bricklink_color, "label", "Unknown"));
    preferred_family = color_family_from_text(best_name + " " + best_notes + " " + bricklink_color_label);
    fallback_color = estimate_image_color(raw, preferred_family);
    best_color = fallback_color;
    if bricklink_color_label and bricklink_color_label != "Unknown" and bricklink_color_label != "Unavailable" {
        best_color["bricklink_variant"] = bricklink_color_label;
    } else {
        best_color["bricklink_variant"] = str(safe_get(fallback_color, "bricklink_match", safe_get(fallback_color, "label", "Unknown")));
    }
    best_color["label"] = str(safe_get(best_color, "bricklink_variant", safe_get(best_color, "label", "Unknown")));
    if str(safe_get(best_color, "label", "Unknown")) == "Unknown" and bricklink_color_label and bricklink_color_label != "Unavailable" {
        best_color["label"] = bricklink_color_label;
        best_color["source"] = "BrickLink";
        best_color["rgb"] = "";
    }

    return {
        "success": True,
        "active_match": {
            "name": best_name,
            "confidence": str(best_confidence_value) + "%",
            "notes": best_notes,
            "part_id": best_part_id,
            "specific_part_number": best_part_id,
            "bricklink_url": best_bricklink_url,
            "years_released": years_released,
            "color": best_color,
        },
        "telemetry": {
            "provider": "Brickognize",
            "candidate_count": len(items),
            "mime_type": mime_type,
            "bytes": len(raw),
        },
        "raw": payload,
    };
}
