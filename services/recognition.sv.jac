import from base64 { b64decode }
import from requests { post }


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
    return (mime_type, b64decode(parts[1]));
}


def safe_get(source: any, key: str) -> any {
    if source == None {
        return None;
    }
    try {
        return source.get(key);
    } except Exception {
        return None;
    }
}


def normalize_items(payload: any) -> list {
    if payload == None {
        return [];
    }
    if type(payload) == list {
        return payload;
    }
    if type(payload) == dict {
        for key in ["items", "predictions", "results"] {
            value = safe_get(payload, key);
            if type(value) == list {
                return value;
            }
        }
    }
    return [];
}


def item_name(item: any) -> str {
    for key in ["name", "label", "class_name", "id", "part_num"] {
        value = safe_get(item, key);
        if value {
            return str(value);
        }
    }
    return "Unknown part";
}


def item_confidence(item: any) -> int {
    for key in ["score", "confidence", "probability"] {
        value = safe_get(item, key);
        if value != None {
            try {
                numeric = float(value);
                if numeric <= 1.0 {
                    numeric = numeric * 100.0;
                }
                return int(round(numeric));
            } except Exception {
                pass;
            }
        }
    }
    return 0;
}


def item_image(item: any) -> str {
    for key in ["image", "image_url", "thumbnail", "thumbnail_url"] {
        value = safe_get(item, key);
        if value {
            return str(value);
        }
    }
    return "";
}


def item_external_url(item: any) -> str {
    for key in ["url", "external_url", "bricklink_url", "brickset_url"] {
        value = safe_get(item, key);
        if value {
            return str(value);
        }
    }
    return "";
}


def item_notes(item: any) -> str {
    for key in ["description", "category", "part_num", "id"] {
        value = safe_get(item, key);
        if value {
            return str(value);
        }
    }
    return "Trained Brickognize classification result.";
}


def sort_ranked(items: list) -> list {
    ordered = [];
    remaining = items;
    while len(remaining) > 0 {
        best = remaining[0];
        for item in remaining {
            if item["confidence_value"] > best["confidence_value"] {
                best = item;
            }
        }
        ordered.append(best);
        remaining = [item for item in remaining if item != best];
    }
    return ordered;
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

    ranked = [];
    for item in normalize_items(payload) {
        ranked.append({
            "name": item_name(item),
            "confidence_value": item_confidence(item),
            "image": item_image(item),
            "url": item_external_url(item),
            "notes": item_notes(item),
        });
    }

    if len(ranked) == 0 {
        fallback_name = safe_get(payload, "name");
        if not fallback_name {
            fallback_name = "Unknown part";
        }
        ranked = [{
            "name": str(fallback_name),
            "confidence_value": item_confidence(payload),
            "image": item_image(payload),
            "url": item_external_url(payload),
            "notes": item_notes(payload),
        }];
    }

    ranked = sort_ranked(ranked);
    best = ranked[0];
    alternatives = [
        {
            "name": item["name"],
            "confidence": str(item["confidence_value"]) + "%",
            "image": item["image"],
            "url": item["url"],
        }
        for item in ranked[1:4]
    ];

    return {
        "success": True,
        "active_match": {
            "name": best["name"],
            "confidence": str(best["confidence_value"]) + "%",
            "color": "Brickognize model",
            "notes": best["notes"],
            "image": best["image"],
            "url": best["url"],
        },
        "alt_matches": alternatives,
        "feature_scores": [
            {"label": "Model confidence", "value": best["confidence_value"]},
            {"label": "API response quality", "value": len(ranked) > 0 and 100 or 0},
            {"label": "Candidate depth", "value": min(len(ranked) * 25, 100)},
        ],
        "telemetry": {
            "provider": "Brickognize",
            "candidate_count": len(ranked),
            "mime_type": mime_type,
            "bytes": len(raw),
        },
        "raw": payload,
    };
}
