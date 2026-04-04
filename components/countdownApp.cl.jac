sv import from ..services.recognition { recognize_lego_frame }

def:pub CountdownApp() -> JsxElement {
    has camera_on: bool = False;
    has analyzing: bool = False;
    has status: str = "Camera ready to start";
    has permission: str = "Not requested";
    has captured_frame: str = "";
    has telemetry: dict = {"width": 0, "height": 0, "avg_red": 0, "avg_green": 0, "avg_blue": 0, "ratio": 0.0};
    has active_match: dict = {
        "name": "Waiting for live analysis",
        "confidence": "0%",
        "color": "Unknown",
        "notes": "Start the webcam and capture a frame to run operational LEGO recognition."
    };
    has alt_matches: list = [];
    has feature_scores: list = [
        {"label": "Shape similarity", "value": 0},
        {"label": "Color similarity", "value": 0},
        {"label": "Stud / surface confidence", "value": 0}
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

    async def analyze_frame(frame_data: str) -> None {
        analyzing = True;
        status = "Running operational recognition on the captured frame...";
        try {
            result = await recognize_lego_frame(frame_data);
            if result and result["success"] {
                active_match = result["active_match"] or active_match;
                alt_matches = result["alt_matches"] or [];
                feature_scores = result["feature_scores"] or feature_scores;
                telemetry = result["telemetry"] or telemetry;
                status = "Operational recognition complete — results updated from backend analysis";
            } else {
                status = "Recognition failed: " + ((result and result["error"]) or "Unknown error");
            }
        } except Exception as e {
            status = "Recognition failed: " + str(e);
        }
        analyzing = False;
    }

    async def capture_frame() -> None {
        if not camera_on {
            status = "Start the webcam first";
            return;
        }
        if analyzing {
            status = "Recognition already in progress";
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
        await analyze_frame(frame_data);
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
                <p className="mt-4 max-w-2xl text-base leading-7 text-slate-600 sm:text-lg">Point a LEGO piece at your webcam, capture the current frame, and run a live backend recognition pass with instant part suggestions.</p>

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
                        <p className="text-3xl font-extrabold text-blue-600">Analyze</p>
                        <p className="mt-1 text-sm text-slate-600">Operational backend recognition</p>
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
                        <button className="inline-flex items-center justify-center rounded-xl border border-border bg-white px-5 py-3 text-sm font-bold text-foreground transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-60" onClick={capture_frame} disabled={analyzing}>{analyzing and "Analyzing..." or "Capture + recognize"}</button>
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
                        {captured_frame != "" and <img src={captured_frame} alt="Captured LEGO frame" className="h-64 w-full object-cover" />}
                        {captured_frame == "" and <div className="flex h-64 items-center justify-center px-6 text-center text-sm text-slate-500">Capture a frame from the live webcam feed to preview the exact image used for recognition.</div>}
                    </div>
                    <div className="mt-4 grid gap-3 sm:grid-cols-2">
                        <div className="rounded-2xl bg-slate-50 p-4 text-sm text-slate-600">
                            <p className="font-semibold text-foreground">Frame size</p>
                            <p className="mt-1">{str(telemetry["width"])} × {str(telemetry["height"])} px</p>
                        </div>
                        <div className="rounded-2xl bg-slate-50 p-4 text-sm text-slate-600">
                            <p className="font-semibold text-foreground">Average RGB</p>
                            <p className="mt-1">{str(telemetry["avg_red"])} / {str(telemetry["avg_green"])} / {str(telemetry["avg_blue"])} · ratio {str(round(telemetry["ratio"], 2))}</p>
                        </div>
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
