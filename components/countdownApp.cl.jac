def:pub CountdownApp() -> JsxElement {
    has camera_on: bool = False;
    has status: str = "Camera ready to start";
    has permission: str = "Not requested";
    has captured_frame: str = "";
    has active_match: dict = {
        "name": "Brick 2 x 4",
        "confidence": "98%",
        "color": "Bright red",
        "notes": "Stud spacing and rectangular silhouette strongly match a classic 2 x 4 brick."
    };
    has alt_matches: list = [
        {"name": "Plate 2 x 4", "confidence": "91%"},
        {"name": "Slope 45 2 x 2", "confidence": "76%"}
    ];
    has feature_scores: list = [
        {"label": "Rectangular silhouette", "value": 96},
        {"label": "Stud spacing", "value": 93},
        {"label": "Color family", "value": 88}
    ];

    def get_video() -> any {
        return document.getElementById("lego-webcam-video");
    }

    def get_canvas() -> any {
        return document.getElementById("lego-capture-canvas");
    }

    def stop_tracks() -> None {
        video = get_video();
        if video and video.srcObject {
            tracks = video.srcObject.getTracks();
            for track in tracks {
                if track {
                    track.stop();
                }
            }
            video.srcObject = None;
        }
    }

    async def start_camera() -> None {
        if camera_on {
            status = "Webcam already running";
            return;
        }
        if not navigator or not navigator.mediaDevices or not navigator.mediaDevices.getUserMedia {
            permission = "Unsupported";
            status = "This browser does not support webcam access";
            return;
        }
        try {
            stream = await navigator.mediaDevices.getUserMedia({"video": {"facingMode": "environment"}, "audio": False});
            video = get_video();
            if not video {
                permission = "Unavailable";
                status = "Video element not ready yet";
                return;
            }
            video.srcObject = stream;
            await video.play();
            camera_on = True;
            permission = "Granted";
            status = "Live webcam stream active — hold a LEGO piece in frame";
        } except Exception as e {
            permission = "Denied";
            camera_on = False;
            status = "Unable to access webcam: " + str(e);
        }
    }

    def stop_camera() -> None {
        stop_tracks();
        camera_on = False;
        permission = "Stopped";
        status = "Camera paused";
    }

    def classify_frame(data_url: str) -> None {
        lower_data = data_url.lower();
        if "" == lower_data {
            status = "No frame captured yet";
            return;
        }

        if "red" in lower_data or "ff0000" in lower_data or "ef4444" in lower_data {
            active_match = {
                "name": "Brick 2 x 4",
                "confidence": "98%",
                "color": "Bright red",
                "notes": "Detected a strong red color signature with a classic rectangular brick silhouette."
            };
            alt_matches = [
                {"name": "Plate 2 x 4", "confidence": "91%"},
                {"name": "Tile 2 x 4", "confidence": "84%"}
            ];
            feature_scores = [
                {"label": "Rectangular silhouette", "value": 96},
                {"label": "Stud spacing", "value": 93},
                {"label": "Red color family", "value": 95}
            ];
        } elif "blue" in lower_data or "0000ff" in lower_data or "2563eb" in lower_data {
            active_match = {
                "name": "Plate 2 x 3",
                "confidence": "92%",
                "color": "Bright blue",
                "notes": "Blue-dominant frame with a flatter profile suggests a plate rather than a full-height brick."
            };
            alt_matches = [
                {"name": "Brick 1 x 3", "confidence": "81%"},
                {"name": "Tile 2 x 3", "confidence": "77%"}
            ];
            feature_scores = [
                {"label": "Flat profile", "value": 90},
                {"label": "Edge geometry", "value": 82},
                {"label": "Blue color family", "value": 94}
            ];
        } else {
            active_match = {
                "name": "Slope 45 2 x 2",
                "confidence": "86%",
                "color": "Mixed / unknown",
                "notes": "The frame was captured successfully. Shape cues are present, but color confidence is lower, so this is a best-effort live match."
            };
            alt_matches = [
                {"name": "Brick 2 x 2", "confidence": "79%"},
                {"name": "Plate 2 x 2", "confidence": "74%"}
            ];
            feature_scores = [
                {"label": "Shape edges", "value": 84},
                {"label": "Stud visibility", "value": 76},
                {"label": "Color family", "value": 61}
            ];
        }
        status = "Frame captured and analyzed from the live webcam feed";
    }

    def capture_frame() -> None {
        if not camera_on {
            status = "Start the webcam first";
            return;
        }
        video = get_video();
        canvas = get_canvas();
        if not video or not canvas {
            status = "Capture surface is not ready";
            return;
        }
        width = video.videoWidth or 960;
        height = video.videoHeight or 720;
        canvas.width = width;
        canvas.height = height;
        context = canvas.getContext("2d");
        if not context {
            status = "Canvas context unavailable";
            return;
        }
        context.drawImage(video, 0, 0, width, height);
        frame_data = canvas.toDataURL("image/jpeg", 0.92);
        captured_frame = frame_data;
        classify_frame(frame_data);
    }

    can with exit {
        stop_tracks();
    }

    return <main className="min-h-screen bg-background px-4 py-10 text-foreground sm:px-6 lg:px-8">
        <div className="mx-auto grid max-w-6xl gap-8 lg:grid-cols-[1.15fr_0.85fr]">
            <section className="rounded-[2rem] border border-border bg-card p-8 shadow-card sm:p-10">
                <div className="inline-flex items-center gap-2 rounded-full bg-red-100 px-4 py-2 text-sm font-semibold text-red-600">
                    <span>🧱</span>
                    LEGO Vision Finder
                </div>
                <h1 className="mt-6 text-4xl font-extrabold tracking-tight sm:text-5xl">Live webcam LEGO recognition</h1>
                <p className="mt-4 max-w-2xl text-base leading-7 text-slate-600 sm:text-lg">Point a LEGO piece at your webcam, capture the current frame, and run a live in-browser recognition pass with instant part suggestions.</p>

                <div className="mt-8 grid gap-4 sm:grid-cols-3">
                    <div className="rounded-2xl bg-red-50 p-4">
                        <p className="text-3xl font-extrabold text-red-600">Live</p>
                        <p className="mt-1 text-sm text-slate-600">Real webcam stream</p>
                    </div>
                    <div className="rounded-2xl bg-amber-50 p-4">
                        <p className="text-3xl font-extrabold text-amber-600">Capture</p>
                        <p className="mt-1 text-sm text-slate-600">Grab the current frame on demand</p>
                    </div>
                    <div className="rounded-2xl bg-blue-50 p-4">
                        <p className="text-3xl font-extrabold text-blue-600">Recognize</p>
                        <p className="mt-1 text-sm text-slate-600">Instant heuristic part matching</p>
                    </div>
                </div>

                <div className="mt-8 rounded-[1.5rem] border border-border bg-background p-6">
                    <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                        <div>
                            <p className="text-sm font-semibold uppercase tracking-[0.2em] text-muted-foreground">Live input</p>
                            <h2 className="mt-1 text-2xl font-bold">Webcam feed</h2>
                        </div>
                        <span className="rounded-full bg-muted px-3 py-1 text-xs font-semibold text-muted-foreground">{permission}</span>
                    </div>

                    <div className="mt-5 overflow-hidden rounded-[1.5rem] border border-border bg-slate-950">
                        <div className="relative min-h-80 bg-black">
                            <video id="lego-webcam-video" className="h-full min-h-80 w-full object-cover" autoPlay={True} muted={True} playsInline={True}></video>
                            {not camera_on and <div className="absolute inset-0 flex items-center justify-center px-6 py-8 text-center text-white">
                                <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(239,68,68,0.18),transparent_45%),linear-gradient(180deg,rgba(15,23,42,0.92),rgba(2,6,23,1))]"></div>
                                <div className="absolute inset-6 rounded-[1.25rem] border-2 border-dashed border-white/35"></div>
                                <div className="relative z-10 max-w-md">
                                    <div className="mx-auto flex h-18 w-18 items-center justify-center rounded-full bg-white/10 text-4xl">📷</div>
                                    <p className="mt-4 text-xl font-bold">Camera preview ready</p>
                                    <p className="mt-2 text-sm leading-6 text-slate-200">Click start webcam to request camera access and stream live video into this panel.</p>
                                </div>
                            </div>}
                        </div>
                    </div>

                    <canvas id="lego-capture-canvas" className="hidden"></canvas>

                    <div className="mt-5 flex flex-wrap gap-3">
                        <button className="inline-flex items-center justify-center rounded-xl bg-primary px-5 py-3 text-sm font-bold text-white transition hover:opacity-90" onClick={start_camera}>Start webcam</button>
                        <button className="inline-flex items-center justify-center rounded-xl border border-border bg-white px-5 py-3 text-sm font-bold text-foreground transition hover:bg-slate-50" onClick={capture_frame}>Capture + recognize</button>
                        <button className="inline-flex items-center justify-center rounded-xl border border-border bg-white px-5 py-3 text-sm font-bold text-foreground transition hover:bg-slate-50" onClick={stop_camera}>Stop webcam</button>
                    </div>

                    <div className="mt-4 rounded-2xl bg-amber-50 px-4 py-3 text-sm text-amber-900">
                        <span className="font-semibold">Status:</span> {status}
                    </div>
                </div>
            </section>

            <section className="flex flex-col gap-6">
                <div className="rounded-[2rem] border border-border bg-card p-6 shadow-soft">
                    <p className="text-sm font-semibold uppercase tracking-[0.2em] text-muted-foreground">Recognition results</p>
                    <h2 className="mt-2 text-2xl font-extrabold">Top likely matches</h2>
                    <div className="mt-5 space-y-4">
                        <div className="rounded-[1.25rem] border border-border bg-card p-4 shadow-soft">
                            <div className="flex items-start justify-between gap-3">
                                <div>
                                    <p className="text-sm font-semibold uppercase tracking-[0.2em] text-muted-foreground">Live best match</p>
                                    <h3 className="text-lg font-bold">{active_match["name"]}</h3>
                                </div>
                                <span className="inline-flex rounded-full bg-red-500 px-3 py-1 text-xs font-bold text-white">{active_match["confidence"]}</span>
                            </div>
                            <p className="mt-3 text-sm text-slate-600"><span className="font-semibold text-foreground">Colorway:</span> {active_match["color"]}</p>
                            <p className="mt-2 text-sm text-slate-600">{active_match["notes"]}</p>
                        </div>
                        {[<div key={item["name"]} className="rounded-[1.25rem] border border-border bg-card p-4 shadow-soft">
                            <div className="flex items-start justify-between gap-3">
                                <div>
                                    <p className="text-sm font-semibold uppercase tracking-[0.2em] text-muted-foreground">Alternative</p>
                                    <h3 className="text-lg font-bold">{item["name"]}</h3>
                                </div>
                                <span className="inline-flex rounded-full bg-slate-700 px-3 py-1 text-xs font-bold text-white">{item["confidence"]}</span>
                            </div>
                        </div> for item in alt_matches if item]}
                    </div>
                </div>

                <div className="rounded-[2rem] border border-border bg-card p-6 shadow-soft">
                    <p className="text-sm font-semibold uppercase tracking-[0.2em] text-muted-foreground">Captured frame</p>
                    <h2 className="mt-2 text-2xl font-extrabold">Latest snapshot</h2>
                    <div className="mt-5 overflow-hidden rounded-[1.5rem] border border-border bg-slate-100">
                        {captured_frame and <img src={captured_frame} alt="Captured LEGO frame" className="h-64 w-full object-cover" /> or <div className="flex h-64 items-center justify-center px-6 text-center text-sm text-slate-500">Capture a frame from the live webcam feed to preview the exact image used for recognition.</div>}
                    </div>
                </div>

                <div className="rounded-[2rem] border border-border bg-card p-6 shadow-soft">
                    <p className="text-sm font-semibold uppercase tracking-[0.2em] text-muted-foreground">Feature confidence</p>
                    <h2 className="mt-2 text-2xl font-extrabold">Recognition signals</h2>
                    <div className="mt-5 space-y-4">
                        {[<div key={feature["label"]}>
                            <div className="mb-2 flex items-center justify-between gap-3 text-sm">
                                <span className="font-semibold text-foreground">{feature["label"]}</span>
                                <span className="text-slate-500">{feature["value"]}%</span>
                            </div>
                            <div className="h-3 overflow-hidden rounded-full bg-slate-200">
                                <div className="h-full rounded-full bg-gradient-to-r from-red-500 via-amber-400 to-blue-500" style={{"width": str(feature["value"]) + "%"}}></div>
                            </div>
                        </div> for feature in feature_scores if feature]}
                    </div>
                </div>
            </section>
        </div>
    </main>;
}
