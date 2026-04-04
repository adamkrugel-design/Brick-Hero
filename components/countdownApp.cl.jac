sv import from ..services.recognition { recognize_lego_frame }


def:pub CountdownApp() -> JsxElement {
    has analyzing: bool = False;
    has status: str = "Camera ready";
    has permission: str = "Idle";
    has camera_active: bool = False;
    has captured_frame: str = "";
    has active_name: str = "No result yet";
    has active_confidence: str = "0%";
    has active_notes: str = "Start the webcam and capture a snapshot to identify a LEGO part.";
    has active_part_id: str = "—";
    has active_years: str = "Unknown";
    has active_years_source: str = "BrickLink";
    has active_bricklink_url: str = "";
    has provider: str = "Brickognize";
    has payload_text: str = "image/png · 0 bytes";
    has candidate_text: str = "0 matches returned";

    def get_video() -> any {
        return document.getElementById("scanner-video");
    }

    def get_canvas() -> any {
        return document.getElementById("scanner-canvas");
    }

    def clear_stream() -> None {
        stream = globalThis.__legoScannerStream;
        if stream {
            for track in stream.getTracks() {
                track.stop();
            }
        }
        video = get_video();
        if video {
            try {
                video.pause();
            } except Exception {
            }
            video.srcObject = None;
        }
        globalThis.__legoScannerStream = None;
        camera_active = False;
    }

    async def start_camera() -> None {
        try {
            permission = "Requesting";
            status = "Requesting webcam access...";
            camera_active = False;

            media_devices = navigator.mediaDevices;
            if not media_devices or not media_devices.getUserMedia {
                permission = "Unavailable";
                status = "This browser does not support webcam access";
                return;
            }

            clear_stream();

            video = get_video();
            if not video {
                permission = "Unavailable";
                status = "Video element not found";
                return;
            }

            video.muted = True;
            video.autoplay = True;
            video.playsInline = True;
            video.setAttribute("autoplay", "true");
            video.setAttribute("muted", "true");
            video.setAttribute("playsinline", "true");

            stream = await media_devices.getUserMedia({"video": True, "audio": False});
            if not stream {
                permission = "Unavailable";
                status = "Unable to create webcam stream";
                return;
            }

            tracks = stream.getVideoTracks();
            if not tracks or len(tracks) == 0 {
                clear_stream();
                permission = "Unavailable";
                status = "No video track available";
                return;
            }

            video.srcObject = stream;
            globalThis.__legoScannerStream = stream;

            try {
                await video.play();
            } except Exception {
            }

            permission = "Granted";
            camera_active = True;
            status = "Webcam active";
        } except Exception as e {
            clear_stream();
            permission = "Denied";
            status = "Unable to start webcam: " + str(e);
        }
    }

    def stop_camera() -> None {
        clear_stream();
        permission = "Stopped";
        status = "Camera stopped";
    }

    async def analyze_frame(frame_data: str) -> None {
        analyzing = True;
        status = "Analyzing snapshot...";
        try {
            result = await recognize_lego_frame(frame_data);
            if result and result["success"] {
                match_info = result["active_match"] or {};
                telemetry = result["telemetry"] or {};
                years_info = match_info["years_released"] or {};
                active_name = str(match_info["name"] or "Unknown part");
                active_confidence = str(match_info["confidence"] or "0%");
                active_notes = str(match_info["notes"] or "Recognition complete.");
                active_part_id = str(match_info["part_id"] or "—");
                active_years = str(years_info["label"] or "Unknown");
                active_years_source = str(years_info["source"] or "BrickLink");
                active_bricklink_url = str(match_info["bricklink_url"] or "");
                provider = str(telemetry["provider"] or "Brickognize");
                payload_text = str(telemetry["mime_type"] or "image/png") + " · " + str(telemetry["bytes"] or 0) + " bytes";
                candidate_text = str(telemetry["candidate_count"] or 0) + " matches returned";
                status = "Analysis complete";
            } else {
                status = str((result and result["error"]) or "Recognition failed");
            }
        } except Exception as e {
            status = "Recognition failed: " + str(e);
        }
        analyzing = False;
    }

    async def capture_frame() -> None {
        if analyzing {
            status = "Recognition already in progress";
            return;
        }
        video = get_video();
        canvas = get_canvas();
        if not video or not canvas {
            status = "Camera surface not ready";
            return;
        }
        if not video.srcObject or not camera_active {
            status = "Start the webcam first";
            return;
        }
        width = int(video.videoWidth or 640);
        height = int(video.videoHeight or 480);
        canvas.width = width;
        canvas.height = height;
        context = canvas.getContext("2d");
        if not context {
            status = "Unable to capture snapshot";
            return;
        }
        context.drawImage(video, 0, 0, width, height);
        frame_data = canvas.toDataURL("image/png");
        captured_frame = frame_data;
        await analyze_frame(frame_data);
    }

    return (
        <div className="mx-auto grid max-w-6xl gap-6 lg:grid-cols-[1.2fr_0.8fr]">
            <section className="rounded-3xl border border-border bg-card p-6 shadow-card sm:p-8">
                <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                        <p className="text-sm font-medium text-muted-foreground">LEGO recognition</p>
                        <h1 className="mt-1 text-3xl font-semibold text-foreground sm:text-4xl">Minimal scanner</h1>
                    </div>
                    <div className="rounded-full border border-border bg-muted px-3 py-1 text-sm text-muted-foreground">{permission}</div>
                </div>

                <p className="mt-4 max-w-2xl text-sm leading-6 text-muted-foreground">Use the webcam, capture a snapshot, and send the image to Brickognize for part recognition plus BrickLink release-year lookup.</p>

                <div className="mt-6 overflow-hidden rounded-2xl border border-border bg-black">
                    <div className="relative min-h-80 bg-neutral-950">
                        <video id="scanner-video" className="h-full min-h-80 w-full object-cover" autoPlay={True} muted={True} playsInline={True}></video>
                        {(not camera_active) and (
                            <div className="absolute inset-0 flex items-center justify-center bg-black/60 px-6 text-center text-sm text-white/80">
                                Start the webcam to preview the live camera feed.
                            </div>
                        )}
                    </div>
                </div>

                <canvas id="scanner-canvas" className="hidden"></canvas>

                <div className="mt-5 flex flex-wrap gap-3">
                    <button className="rounded-xl bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground transition hover:opacity-90 focus:outline-none focus:ring-2 focus:ring-primary/30" onClick={start_camera}>Start webcam</button>
                    <button className="rounded-xl border border-border bg-card px-4 py-2.5 text-sm font-medium text-foreground transition hover:bg-card-hover focus:outline-none focus:ring-2 focus:ring-primary/20 disabled:cursor-not-allowed disabled:opacity-60" onClick={capture_frame} disabled={analyzing or (not camera_active)}>{analyzing and "Analyzing..." or "Capture snapshot"}</button>
                    <button className="rounded-xl border border-border bg-muted px-4 py-2.5 text-sm font-medium text-foreground transition hover:bg-accent focus:outline-none focus:ring-2 focus:ring-primary/20" onClick={stop_camera}>Stop webcam</button>
                </div>

                <div className="mt-4 rounded-2xl border border-border bg-muted px-4 py-3 text-sm text-muted-foreground">
                    <span className="mr-2 font-medium text-foreground">Status:</span>{status}
                </div>
            </section>

            <section className="flex flex-col gap-6">
                <div className="rounded-3xl border border-border bg-card p-6 shadow-soft">
                    <p className="text-sm font-medium text-muted-foreground">Result</p>
                    <h2 className="mt-1 text-2xl font-semibold text-foreground">Top match</h2>
                    <div className="mt-4 rounded-2xl border border-border bg-muted p-4">
                        <div className="flex items-start justify-between gap-3">
                            <div>
                                <p className="text-xs uppercase tracking-wide text-muted-foreground">Detected part</p>
                                <h3 className="mt-1 text-lg font-semibold text-foreground">{active_name}</h3>
                            </div>
                            <span className="rounded-full bg-card px-3 py-1 text-sm font-medium text-foreground">{active_confidence}</span>
                        </div>
                        <p className="mt-3 text-sm leading-6 text-muted-foreground">{active_notes}</p>
                        <div className="mt-4 grid gap-3 sm:grid-cols-2">
                            <div className="rounded-2xl border border-border bg-card p-4 text-sm text-muted-foreground">
                                <p className="font-medium text-foreground">Part ID</p>
                                <p className="mt-1">{active_part_id}</p>
                            </div>
                            <div className="rounded-2xl border border-border bg-card p-4 text-sm text-muted-foreground">
                                <p className="font-medium text-foreground">Years released</p>
                                <p className="mt-1">{active_years}</p>
                                <p className="mt-1 text-xs">Source: {active_years_source}</p>
                            </div>
                        </div>
                        {(active_bricklink_url != "") and (
                            <a href={active_bricklink_url} target="_blank" rel="noreferrer" className="mt-4 inline-flex rounded-xl border border-border bg-card px-4 py-2 text-sm font-medium text-foreground transition hover:bg-card-hover">
                                Open on BrickLink
                            </a>
                        )}
                    </div>
                </div>

                <div className="rounded-3xl border border-border bg-card p-6 shadow-soft">
                    <p className="text-sm font-medium text-muted-foreground">Snapshot</p>
                    <h2 className="mt-1 text-2xl font-semibold text-foreground">Latest capture</h2>
                    <div className="mt-4 overflow-hidden rounded-2xl border border-border bg-muted">
                        {(captured_frame != "") and (<img src={captured_frame} alt="Captured LEGO frame" className="h-64 w-full object-cover" />)}
                        {(captured_frame == "") and (<div className="flex h-64 items-center justify-center px-6 text-center text-sm text-muted-foreground">No snapshot captured yet.</div>)}
                    </div>
                    <div className="mt-4 grid gap-3">
                        <div className="rounded-2xl border border-border bg-muted p-4 text-sm text-muted-foreground">
                            <p className="font-medium text-foreground">Provider</p>
                            <p className="mt-1">{provider}</p>
                        </div>
                        <div className="rounded-2xl border border-border bg-muted p-4 text-sm text-muted-foreground">
                            <p className="font-medium text-foreground">Payload</p>
                            <p className="mt-1">{payload_text}</p>
                        </div>
                        <div className="rounded-2xl border border-border bg-muted p-4 text-sm text-muted-foreground">
                            <p className="font-medium text-foreground">Matches</p>
                            <p className="mt-1">{candidate_text}</p>
                        </div>
                    </div>
                </div>
            </section>
        </div>
    );
}
