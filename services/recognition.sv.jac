import from base64 { b64decode }
import from requests { get, post }
import from io { BytesIO }
import from PIL import Image


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


def parse_bricklink_color(page_text: str) -> dict {
    if not page_text {
        return {"label": "Unknown", "source": "BrickLink"};
    }

    markers = ["Color:", "Known Color:"];
    for marker in markers {
        if marker not in page_text {
            continue;
        }
        section = page_text.split(marker, 1)[1];
        section = section.split("Years Released:", 1)[0];
        section = section.split("Year Released:", 1)[0];
        section = section.split("Weight:", 1)[0];
        section = section.split("<br", 1)[0];
        section = section.split("</td>", 1)[0];
        section = section.replace("&nbsp;", " ");
        section = section.replace("&amp;", "&");

        cleaned = "";
        inside_tag = False;
        for ch in section {
            if ch == "<" {
                inside_tag = True;
                continue;
            }
            if ch == ">" {
                inside_tag = False;
                continue;
            }
            if not inside_tag {
                cleaned = cleaned + ch;
            }
        }

        cleaned = cleaned.replace("\n", " ");
        cleaned = cleaned.replace("\r", " ");
        while "  " in cleaned {
            cleaned = cleaned.replace("  ", " ");
        }
        cleaned = cleaned.strip();

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
    section = section.split("<br", 1)[0];
    section = section.replace("&nbsp;", " ");
    section = section.replace("</span>", "");
    section = section.replace("</div>", "");
    section = section.replace("<span id=\"yearReleasedSec\">", "");
    section = section.strip();

    if not section {
        return {"label": "Unknown", "start": "", "end": "", "source": "BrickLink"};
    }

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
        return {
            "label": start_year + "–" + end_year,
            "start": start_year,
            "end": end_year,
            "source": "BrickLink",
        };
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

    palette = [
        {"label": "Black", "rgb": (27, 42, 52)},
        {"label": "White", "rgb": (242, 243, 242)},
        {"label": "Light Bluish Gray", "rgb": (160, 165, 169)},
        {"label": "Dark Bluish Gray", "rgb": (99, 95, 98)},
        {"label": "Red", "rgb": (196, 40, 27)},
        {"label": "Dark Red", "rgb": (114, 14, 15)},
        {"label": "Blue", "rgb": (13, 105, 171)},
        {"label": "Dark Blue", "rgb": (0, 32, 96)},
        {"label": "Yellow", "rgb": (245, 205, 47)},
        {"label": "Bright Light Orange", "rgb": (248, 187, 61)},
        {"label": "Orange", "rgb": (218, 133, 65)},
        {"label": "Green", "rgb": (40, 127, 70)},
        {"label": "Dark Green", "rgb": (24, 70, 50)},
        {"label": "Tan", "rgb": (228, 205, 158)},
        {"label": "Dark Tan", "rgb": (149, 138, 115)},
        {"label": "Reddish Brown", "rgb": (105, 64, 40)},
        {"label": "Brown", "rgb": (124, 92, 70)},
        {"label": "Pink", "rgb": (255, 152, 220)},
        {"label": "Purple", "rgb": (123, 47, 123)},
        {"label": "Lavender", "rgb": (188, 166, 208)},
        {"label": "Sand Green", "rgb": (120, 144, 130)},
        {"label": "Sand Blue", "rgb": (96, 116, 161)},
        {"label": "Trans-Clear", "rgb": (236, 236, 236)},
    ];

    try {
        image = Image.open(BytesIO(raw)).convert("RGB");
        image.thumbnail((96, 96));
        width = image.width;
        height = image.height;
        if width <= 0 or height <= 0 {
            return {"label": "Unknown", "source": "Image fallback", "rgb": ""};
        }

        left = int(width * 0.2);
        top = int(height * 0.2);
        right = int(width * 0.8);
        bottom = int(height * 0.8);
        if right <= left or bottom <= top {
            left = 0;
            top = 0;
            right = width;
            bottom = height;
        }

        total_r = 0;
        total_g = 0;
        total_b = 0;
        count = 0;
        for y in range(top, bottom) {
            for x in range(left, right) {
                pixel = image.getpixel((x, y));
                r = int(pixel[0]);
                g = int(pixel[1]);
                b = int(pixel[2]);
                brightness = (r + g + b) / 3;
                spread = max(r, g, b) - min(r, g, b);
                if brightness > 245 and spread < 12 {
                    continue;
                }
                total_r = total_r + r;
                total_g = total_g + g;
                total_b = total_b + b;
                count = count + 1;
            }
        }

        if count == 0 {
            for y in range(height) {
                for x in range(width) {
                    pixel = image.getpixel((x, y));
                    total_r = total_r + int(pixel[0]);
                    total_g = total_g + int(pixel[1]);
                    total_b = total_b + int(pixel[2]);
                    count = count + 1;
                }
            }
        }

        if count == 0 {
            return {"label": "Unknown", "source": "Image fallback", "rgb": ""};
        }

        avg_r = int(round(total_r / count));
        avg_g = int(round(total_g / count));
        avg_b = int(round(total_b / count));

        best_label = "Unknown";
        best_distance = None;
        for entry in palette {
            target = entry["rgb"];
            distance = ((avg_r - target[0]) * (avg_r - target[0])) + ((avg_g - target[1]) * (avg_g - target[1])) + ((avg_b - target[2]) * (avg_b - target[2]));
            if best_distance == None or distance < best_distance {
                best_distance = distance;
                best_label = entry["label"];
            }
        }

        return {
            "label": best_label,
            "source": "Image fallback",
            "rgb": str(avg_r) + ", " + str(avg_g) + ", " + str(avg_b),
        };
    } except Exception as e {
        return {"label": "Unknown", "source": "Image fallback", "rgb": "", "error": str(e)};
    }
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
            "years_released": {
                "label": "Unavailable",
                "start": "",
                "end": "",
                "source": "BrickLink",
                "error": "BrickLink lookup failed: " + str(e),
            },
            "color": {
                "label": "Unavailable",
                "source": "BrickLink",
                "error": "BrickLink lookup failed: " + str(e),
            },
        };
    }

    if response.status_code < 200 or response.status_code >= 300 {
        return {
            "years_released": {
                "label": "Unavailable",
                "start": "",
                "end": "",
                "source": "BrickLink",
                "error": "BrickLink returned status " + str(response.status_code),
            },
            "color": {
                "label": "Unavailable",
                "source": "BrickLink",
                "error": "BrickLink returned status " + str(response.status_code),
            },
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
    } else {
        best_color["fallback"] = fallback_color;
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
