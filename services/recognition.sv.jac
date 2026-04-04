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


def estimate_image_color(raw: bytes) -> dict {
    if not raw {
        return {"label": "Unknown", "source": "Image fallback", "rgb": ""};
    }

    sample_limit = len(raw);
    if sample_limit > 3072 {
        sample_limit = 3072;
    }
    if sample_limit < 3 {
        return {"label": "Unknown", "source": "Image fallback", "rgb": ""};
    }

    red_total = 0;
    green_total = 0;
    blue_total = 0;
    pixel_count = 0;
    idx = 0;
    while idx + 2 < sample_limit {
        red_total = red_total + int(raw[idx]);
        green_total = green_total + int(raw[idx + 1]);
        blue_total = blue_total + int(raw[idx + 2]);
        pixel_count = pixel_count + 1;
        idx = idx + 3;
    }

    if pixel_count == 0 {
        return {"label": "Unknown", "source": "Image fallback", "rgb": ""};
    }

    avg_red = int(round(red_total / pixel_count));
    avg_green = int(round(green_total / pixel_count));
    avg_blue = int(round(blue_total / pixel_count));
    rgb_text = str(avg_red) + ", " + str(avg_green) + ", " + str(avg_blue);

    palette = [
        {"label": "Black", "r": 27, "g": 42, "b": 52},
        {"label": "White", "r": 242, "g": 243, "b": 242},
        {"label": "Light Bluish Gray", "r": 160, "g": 165, "b": 169},
        {"label": "Dark Bluish Gray", "r": 99, "g": 95, "b": 98},
        {"label": "Red", "r": 196, "g": 40, "b": 27},
        {"label": "Blue", "r": 13, "g": 105, "b": 171},
        {"label": "Green", "r": 40, "g": 127, "b": 70},
        {"label": "Yellow", "r": 245, "g": 205, "b": 47},
        {"label": "Tan", "r": 228, "g": 205, "b": 158},
        {"label": "Brown", "r": 124, "g": 92, "b": 70},
        {"label": "Dark Tan", "r": 149, "g": 138, "b": 115},
        {"label": "Orange", "r": 218, "g": 133, "b": 65},
        {"label": "Dark Green", "r": 40, "g": 70, "b": 45},
        {"label": "Trans-Clear", "r": 236, "g": 236, "b": 236},
    ];

    best_label = "Unknown";
    best_distance = -1;
    for swatch in palette {
        distance = ((avg_red - swatch["r"]) * (avg_red - swatch["r"])) + ((avg_green - swatch["g"]) * (avg_green - swatch["g"])) + ((avg_blue - swatch["b"]) * (avg_blue - swatch["b"]));
        if best_distance < 0 or distance < best_distance {
            best_distance = distance;
            best_label = str(swatch["label"]);
        }
    }

    return {"label": best_label, "source": "Image fallback", "rgb": rgb_text};
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
    best_color = safe_get(bricklink_metadata, "color", {"label": "Unknown", "source": "BrickLink"});
    fallback_color = estimate_image_color(raw);
    color_label = str(safe_get(best_color, "label", "Unknown"));
    if color_label == "Unknown" or color_label == "Unavailable" or color_label == "" {
        best_color = fallback_color;
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
