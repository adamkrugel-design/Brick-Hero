sv import from ..services.recognition { recognize_lego_frame }


def:pub AltMatchCard(props: dict) -> JsxElement {
    name = str(props["name"] or "Unknown part");
    confidence = str(props["confidence"] or "0%");
    image = str(props["image"] or "");
    url = str(props["url"] or "");

    return (
        <div className="rounded-[1.25rem] border border-fuchsia-300/20 bg-fuchsia-400/6 p-4 shadow-soft">
            <div className="flex items-start justify-between gap-3">
                <div>
                    <p className="retro-display text-xs font-semibold tracking-[0.24em] text-fuchsia-200/80">Secondary lock</p>
                    <h3 className="retro-display text-lg font-bold text-cyan-100">{name}</h3>
                </div>
                <span className="retro-display inline-flex rounded-full border border-fuchsia-300/30 bg-fuchsia-500 px-3 py-1 text-xs font-bold text-white">{confidence}</span>
            </div>
            {image != "" and <img src={image} alt={name} className="mt-3 h-28 w-full rounded-xl border border-fuchsia-300/20 object-contain bg-slate-950/80 p-2" />}
            {url != "" and <a href={url} target="_blank" className="mt-3 inline-flex text-xs font-semibold uppercase tracking-[0.22em] text-fuchsia-200 hover:text-white">Open reference ↗</a>}
        </div>
    );
}


def:pub FeatureScoreRow(props: dict) -> JsxElement {
    label = str(props["label"] or "Signal");
    value = int(props["value"] or 0);
    width_style = {"width": str(value) + "%"};

    return (
        <div>
            <div className="mb-2 flex items-center justify-between gap-3 text-sm">
                <span className="retro-display text-xs font-semibold text-cyan-100">{label}</span>
                <span className="text-cyan-100/70">{str(value)}%</span>
            </div>
            <div className="h-3 overflow-hidden rounded-full border border-cyan-300/20 bg-slate-950">
                <div className="h-full rounded-full bg-gradient-to-r from-cyan-400 via-fuchsia-500 to-amber-300" style={width_style}></div>
            </div>
        </div>
    );
}


def:pub CountdownApp() -> JsxElement {
    has camera_on: bool = False;
    has analyzing: bool = False;
    has status: str = "Camera ready to start";
    has permission: str = "Not requested";
    has captured_frame: str = "";
    has telemetry: dict = {"provider": "Brickognize", "candidate_count": 0, "mime_type": "image/jpeg", "bytes": 0};
    has active_match: dict = {
        "name": "Waiting for live analysis",
        "confidence": "0%",
        "color": "Unknown",
        "notes": "Start the webcam and capture a frame to run Brickognize classification.",
        "image": "",
        "url": ""
    };
    has alt_matches: list = [];
    has feature_scores: list = [
        {"label": "Model confidence", "value": 0},
        {"label": "API response quality", "value": 0},
        {"label": "Candidate depth", "value": 0}
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
        status = "Sending captured snapshot to Brickognize...";
        try {
            result = await recognize_lego_frame(frame_data);
            if result and result["success"] {
                active_match = result["active_match"] or active_match;
                alt_matches = result["alt_matches"] or [];
                feature_scores = result["feature_scores"] or feature_scores;
                telemetry = result["telemetry"] or telemetry;
                status = "Brickognize classification complete — live snapshot analyzed";
            } else {
                status = "Recognition failed: " + ((result and result["error"]) or "Unknown error");
            }
        except Exception as e {
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
        frame_data = canvas.toDataURL("image/png");
        captured_frame = frame_data;
        await analyze_frame(frame_data);
    }

    can with exit {
        stop_tracks();
    }

    return <main className="min-h-screen bg-background px-4 py-8 text-foreground sm:px-6 lg:px-8">
        <div className="mx-auto grid max-w-7xl gap-8 lg:grid-cols-[1.15fr_0.85fr]">
            <section className="retro-panel rounded-[2rem] p-8 sm:p-10">
                <div className="flex flex-wrap items-center gap-3">
                    <div className="retro-chip retro-display inline-flex items-center gap-2 rounded-full px-4 py-2 text-xs font-bold text-accent">
                        <span className="retro-led text-primary">●</span>
                        Brickognize uplink
                    </div>
                    <div className="rounded-full border border-cyan-300/30 bg-cyan-400/10 px-4 py-2 text-xs font-semibold uppercase tracking-[0.28em] text-cyan-200">Sector 1997</div>
                </div>

                <h1 className="retro-display mt-6 text-4xl font-extrabold leading-tight text-cyan-100 sm:text-5xl">LEGO cyber scanner deck</h1>
                <p className="mt-4 max-w-2xl text-lg leading-7 text-cyan-50/75">A sci-fi, 90s-inspired recognition console styled like printed LEGO computer bricks: glowing bezels, chunky control pads, and a live camera viewport wired to trained part classification.</p>

                <div className="mt-8 grid gap-4 sm:grid-cols-3">
                    <div className="retro-panel rounded-[1.4rem] p-4">
                        <p className="retro-display text-3xl font-extrabold text-primary">Live</p>
                        <p className="mt-1 text-sm text-cyan-100/70">Analog-feel webcam stream</p>
                    </div>
                    <div className="retro-panel rounded-[1.4rem] p-4">
                        <p className="retro-display text-3xl font-extrabold text-secondary">Snap</p>
                        <p className="mt-1 text-sm text-cyan-100/70">Frame capture on command</p>
                    </div>
                    <div className="retro-panel rounded-[1.4rem] p-4">
                        <p className="retro-display text-3xl font-extrabold text-accent">Classify</p>
                        <p className="mt-1 text-sm text-cyan-100/70">Operational model response</p>
                    </div>
                </div>

                <div className="retro-panel mt-8 rounded-[1.7rem] p-6">
                    <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                        <div>
                            <p className="retro-display text-xs font-semibold tracking-[0.28em] text-cyan-300/80">Live input</p>
                            <h2 className="retro-display mt-2 text-2xl font-bold text-cyan-100">Optic feed viewport</h2>
                        </div>
                        <span className="rounded-full border border-cyan-300/30 bg-cyan-400/10 px-4 py-2 text-xs font-semibold uppercase tracking-[0.24em] text-cyan-100">{permission}</span>
                    </div>

                    <div className="mt-5 overflow-hidden rounded-[1.6rem] border-2 border-cyan-300/35 bg-slate-950 shadow-[0_0_0_2px_rgba(0,229,255,0.08)]">
                        <div className="relative min-h-80 bg-black">
                            <div className="pointer-events-none absolute inset-0 z-10 bg-[linear-gradient(180deg,rgba(255,255,255,0.03),rgba(255,255,255,0)),repeating-linear-gradient(180deg,rgba(0,229,255,0.08)_0px,rgba(0,229,255,0.08)_1px,transparent_2px,transparent_6px)]"></div>
                            <video id="lego-webcam-video" className="relative z-0 h-full min-h-80 w-full object-cover" autoPlay={True} muted={True} playsInline={True}></video>
                            {not camera_on and <div className="absolute inset-0 flex items-center justify-center px-6 py-8 text-center text-white">
                                <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(0,229,255,0.18),transparent_45%),linear-gradient(180deg,rgba(8,17,31,0.88),rgba(2,6,23,1))]"></div>
                                <div className="absolute inset-5 rounded-[1.25rem] border-2 border-dashed border-cyan-300/35"></div>
                                <div className="relative z-10 max-w-md">
                                    <div className="retro-display mx-auto flex h-18 w-18 items-center justify-center rounded-full border border-cyan-300/40 bg-cyan-400/10 text-4xl text-cyan-100">◉</div>
                                    <p className="retro-display mt-4 text-xl font-bold text-cyan-100">Camera deck armed</p>
                                    <p className="mt-2 text-sm leading-6 text-cyan-100/75">Engage the webcam to stream a live feed into this retro scanner bay and classify LEGO parts in real time.</p>
                                </div>
                            </div>}
                        </div>
                    </div>

                    <canvas id="lego-capture-canvas" className="hidden"></canvas>

                    <div className="mt-5 flex flex-wrap gap-3">
                        <button className="retro-display inline-flex items-center justify-center rounded-xl border border-cyan-300/40 bg-cyan-400 px-5 py-3 text-sm font-bold text-slate-950 transition hover:brightness-110" onClick={start_camera}>Start webcam</button>
                        <button className="retro-display inline-flex items-center justify-center rounded-xl border border-fuchsia-300/40 bg-fuchsia-500 px-5 py-3 text-sm font-bold text-white transition hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-60" onClick={capture_frame} disabled={analyzing}>{analyzing and "Analyzing..." or "Capture + recognize"}</button>
                        <button className="retro-display inline-flex items-center justify-center rounded-xl border border-amber-300/40 bg-amber-300 px-5 py-3 text-sm font-bold text-slate-950 transition hover:brightness-110" onClick={stop_camera}>Stop webcam</button>
                    </div>

                    <div className="mt-4 rounded-2xl border border-cyan-300/25 bg-cyan-400/8 px-4 py-3 text-sm text-cyan-50/90">
                        <span className="retro-display mr-2 text-xs text-cyan-200">Status</span>{status}
                    </div>
                </div>
            </section>

            <section className="flex flex-col gap-6">
                <div className="retro-panel rounded-[2rem] p-6">
                    <p className="retro-display text-xs font-semibold tracking-[0.28em] text-cyan-300/80">Recognition results</p>
                    <h2 className="retro-display mt-2 text-2xl font-extrabold text-cyan-100">Top likely matches</h2>
                    <div className="mt-5 space-y-4">
                        <div className="rounded-[1.25rem] border border-cyan-300/25 bg-cyan-400/6 p-4 shadow-soft">
                            <div className="flex items-start justify-between gap-3">
                                <div>
                                    <p className="retro-display text-xs font-semibold tracking-[0.24em] text-cyan-300/80">Primary lock</p>
                                    <h3 className="retro-display text-lg font-bold text-cyan-100">{str(active_match["name"] or "Unknown part")}</h3>
                                </div>
                                <span className="retro-display inline-flex rounded-full border border-cyan-300/30 bg-cyan-400 px-3 py-1 text-xs font-bold text-slate-950">{str(active_match["confidence"] or "0%")}</span>
                            </div>
                            {str(active_match["image"] or "") != "" and <img src={str(active_match["image"])} alt={str(active_match["name"] or "Detected part")} className="mt-3 h-32 w-full rounded-xl border border-cyan-300/20 object-contain bg-slate-950/80 p-2" />}
                            <p className="mt-3 text-sm text-cyan-100/75"><span className="font-semibold text-cyan-100">Source:</span> {str(active_match["color"] or "Brickognize model")}</p>
                            <p className="mt-2 text-sm text-cyan-100/70">{str(active_match["notes"] or "")}</p>
                            {str(active_match["url"] or "") != "" and <a href={str(active_match["url"])} target="_blank" className="mt-3 inline-flex text-xs font-semibold uppercase tracking-[0.22em] text-cyan-200 hover:text-white">Open reference ↗</a>}
                        </div>
                        {[
                            <AltMatchCard
                                key={str(item["name"] or "alt")}
                                name={str(item["name"] or "Unknown part")}
                                confidence={str(item["confidence"] or "0%")}
                                image={str(item["image"] or "")}
                                url={str(item["url"] or "")}
                            /> for item in alt_matches if item
                        ]}
                    </div>
                </div>

                <div className="retro-panel rounded-[2rem] p-6">
                    <p className="retro-display text-xs font-semibold tracking-[0.28em] text-cyan-300/80">Captured frame</p>
                    <h2 className="retro-display mt-2 text-2xl font-extrabold text-cyan-100">Latest snapshot</h2>
                    <div className="mt-5 overflow-hidden rounded-[1.5rem] border-2 border-cyan-300/25 bg-slate-950">
                        {captured_frame != "" and <img src={captured_frame} alt="Captured LEGO frame" className="h-64 w-full object-cover" />}
                        {captured_frame == "" and <div className="flex h-64 items-center justify-center px-6 text-center text-sm text-cyan-100/60">Capture a frame from the live webcam feed to preview the exact image sent to Brickognize.</div>}
                    </div>
                    <div className="mt-4 grid gap-3 sm:grid-cols-2">
                        <div className="rounded-2xl border border-cyan-300/20 bg-cyan-400/6 p-4 text-sm text-cyan-100/70">
                            <p className="retro-display text-xs text-cyan-100">Provider</p>
                            <p className="mt-1 text-base text-cyan-50">{str(telemetry["provider"] or "Brickognize")}</p>
                        </div>
                        <div className="rounded-2xl border border-amber-300/20 bg-amber-300/8 p-4 text-sm text-cyan-100/70">
                            <p className="retro-display text-xs text-cyan-100">Payload</p>
                            <p className="mt-1 text-base text-cyan-50">{str(telemetry["mime_type"] or "image/png")} · {str(telemetry["bytes"] or 0)} bytes</p>
                        </div>
                        <div className="rounded-2xl border border-cyan-300/20 bg-cyan-400/6 p-4 text-sm text-cyan-100/70 sm:col-span-2">
                            <p className="retro-display text-xs text-cyan-100">Candidate count</p>
                            <p className="mt-1 text-base text-cyan-50">{str(telemetry["candidate_count"] or 0)} ranked matches returned from Brickognize</p>
                        </div>
                    </div>
                </div>

                <div className="retro-panel rounded-[2rem] p-6">
                    <p className="retro-display text-xs font-semibold tracking-[0.28em] text-cyan-300/80">Feature confidence</p>
                    <h2 className="retro-display mt-2 text-2xl font-extrabold text-cyan-100">Recognition signals</h2>
                    <div className="mt-5 space-y-4">
                        {[
                            <FeatureScoreRow
                                key={str(feature["label"] or "signal")}
                                label={str(feature["label"] or "Signal")}
                                value={int(feature["value"] or 0)}
                            /> for feature in feature_scores if feature
                        ]}
                    </div>
                </div>
            </section>
        </div>
    </main>;
}
