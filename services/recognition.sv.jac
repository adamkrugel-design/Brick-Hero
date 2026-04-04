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


def item_part_id(item: any) -> str {
    for key in ["id", "part_num", "item_no"] {
        value = safe_get(item, key, "");
        if value {
            return str(value);
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
    if ">" in section {
        section = section.split(">", 1)[1];
    }
    section = section.strip();

    if not section {
        return {"label": "Unknown", "start": "", "end": "", "source": "BrickLink"};
    }

    if "-" in section {
        parts = section.split("-", 1);
        start_year = parts[0].strip();
        end_year = parts[1].strip();
        return {
            "label": start_year + "–" + end_year,
            "start": start_year,
            "end": end_year,
            "source": "BrickLink",
        };
    }

    return {"label": section, "start": section, "end": section, "source": "BrickLink"};
}


def fetch_bricklink_years(part_id: str, bricklink_url: str) -> dict {
    if not bricklink_url and not part_id {
        return {"label": "Unknown", "start": "", "end": "", "source": "BrickLink"};
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
            "label": "Unavailable",
            "start": "",
            "end": "",
            "source": "BrickLink",
            "error": "BrickLink lookup failed: " + str(e),
        };
    }

    if response.status_code < 200 or response.status_code >= 300 {
        return {
            "label": "Unavailable",
            "start": "",
            "end": "",
            "source": "BrickLink",
            "error": "BrickLink returned status " + str(response.status_code),
        };
    }

    return parse_years_released(response.text);
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

    years_released = fetch_bricklink_years(best_part_id, best_bricklink_url);

    return {
        "success": True,
        "active_match": {
            "name": best_name,
            "confidence": str(best_confidence_value) + "%",
            "notes": best_notes,
            "part_id": best_part_id,
            "bricklink_url": best_bricklink_url,
            "years_released": years_released,
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
