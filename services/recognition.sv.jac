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

    if len(items) > 0 {
        first = items[0];
        best_name = item_name(first);
        best_confidence_value = item_confidence(first);
        best_notes = item_notes(first);
    } else {
        best_name = str(safe_get(payload, "name", "Unknown part"));
        best_confidence_value = item_confidence(payload);
        best_notes = item_notes(payload);
    }

    return {
        "success": True,
        "active_match": {
            "name": best_name,
            "confidence": str(best_confidence_value) + "%",
            "notes": best_notes,
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
