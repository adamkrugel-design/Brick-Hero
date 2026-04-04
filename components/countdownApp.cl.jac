sv import from ..services.recognition { recognize_lego_frame }
import from "@jac/runtime" { useRef }


def:pub CountdownApp() -> JsxElement {
    has camera_on: bool = False;
    has analyzing: bool = False;
    has status: str = "Camera ready to start";
    has permission: str = "Not requested";
    has captured_frame: str = "";
    has active_name: str = "Waiting for live analysis";
    has active_confidence: str = "0%";
    has active_notes: str = "Start the webcam and capture a frame to run Brickognize classification.";
    has provider: str = "Brickognize";
    has payload_text: str = "image/jpeg · 0 bytes";
    has candidate_text: str = "0 ranked matches returned from Brickognize";

    video_ref = useRef(None);
    canvas_ref = useRef(None);
    stream_ref = useRef(None);

    async def start_camera() -> None {
        try {
            media_devices = web.navigator.mediaDevices;
            if not media_devices {
                permission = "Unavailable";
                status = "This browser does not expose mediaDevices";
                return;
            }
            stream = await media_devices.getUserMedia({"video": True, "audio": False});
            stream_ref.current = stream;
            if video_ref.current {
                video_ref.current.srcObject = stream;
                await video_ref.current.play();
            }
            permission = "Granted";
            camera_on = True;
            status = "Live webcam stream active — hold a LEGO piece in frame";
        } except Exception as e {
            permission = "Denied";
            camera_on = False;
            status = "Unable to start webcam: " + str(e);
        }
    }

    def stop_camera() -> None {
        try {
            stream = stream_ref.current;
            if stream {
                tracks = stream.getTracks();
                for track in tracks {
                    track.stop();
                }
            }
        } except Exception {
        }
        if video_ref.current {
            video_ref.current.srcObject = None;
        }
        stream_ref.current = None;
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
                if result["active_match"] {
                    active_name = str(result["active_match"]["name"] or active_name);
                    active_confidence = str(result["active_match"]["confidence"] or active_confidence);
                    active_notes = str(result["active_match"]["notes"] or active_notes);
                }
                if result["telemetry"] {
                    provider = str(result["telemetry"]["provider"] or provider);
                    payload_text = str(result["telemetry"]["mime_type"] or "image/png") + " · " + str(result["telemetry"]["bytes"] or 0) + " bytes";
                    candidate_text = str(result["telemetry"]["candidate_count"] or 0) + " ranked matches returned from Brickognize";
                }
                status = "Brickognize classification complete — live snapshot analyzed";
            } else {
                status = str((result and result["error"]) or "Recognition failed");
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
        if not video_ref.current or not canvas_ref.current {
            status = "Camera surface not ready";
            return;
        }
        video = video_ref.current;
        canvas = canvas_ref.current;
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

    can with exit {
        try {
            stream = stream_ref.current;
            if stream {
                tracks = stream.getTracks();
                for track in tracks {
                    track.stop();
                }
            }
        } except Exception {
        }
    }

    return (
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
                            <video ref={video_ref} className="relative z-0 h-full min-h-80 w-full object-cover" autoPlay={True} muted={True} playsInline={True}></video>
                            {(not camera_on) and (
                                <div className="absolute inset-0 flex items-center justify-center px-6 py-8 text-center text-white">
                                    <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(0,229,255,0.18),transparent_45%),linear-gradient(180deg,rgba(8,17,31,0.88),rgba(2,6,23,1))]"></div>
                                    <div className="absolute inset-5 rounded-[1.25rem] border-2 border-dashed border-cyan-300/35"></div>
                                    <div className="relative z-10 max-w-md">
                                        <div className="retro-display mx-auto flex h-18 w-18 items-center justify-center rounded-full border border-cyan-300/40 bg-cyan-400/10 text-4xl text-cyan-100">◉</div>
                                        <p className="retro-display mt-4 text-xl font-bold text-cyan-100">Camera deck armed</p>
                                        <p className="mt-2 text-sm leading-6 text-cyan-100/75">Engage the webcam to stream a live feed into this retro scanner bay and classify LEGO parts in real time.</p>
                                    </div>
                                </div>
                            )}
                        </div>
                    </div>

                    <canvas ref={canvas_ref} className="hidden"></canvas>

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
                    <h2 className="retro-display mt-2 text-2xl font-extrabold text-cyan-100">Top likely match</h2>
                    <div className="mt-5 rounded-[1.25rem] border border-cyan-300/25 bg-cyan-400/6 p-4 shadow-soft">
                        <div className="flex items-start justify-between gap-3">
                            <div>
                                <p className="retro-display text-xs font-semibold tracking-[0.24em] text-cyan-300/80">Primary lock</p>
                                <h3 className="retro-display text-lg font-bold text-cyan-100">{active_name}</h3>
                            </div>
                            <span className="retro-display inline-flex rounded-full border border-cyan-300/30 bg-cyan-400 px-3 py-1 text-xs font-bold text-slate-950">{active_confidence}</span>
                        </div>
                        <p className="mt-3 text-sm text-cyan-100/75"><span className="font-semibold text-cyan-100">Source:</span> Brickognize model</p>
                        <p className="mt-2 text-sm text-cyan-100/70">{active_notes}</p>
                    </div>
                </div>

                <div className="retro-panel rounded-[2rem] p-6">
                    <p className="retro-display text-xs font-semibold tracking-[0.28em] text-cyan-300/80">Captured frame</p>
                    <h2 className="retro-display mt-2 text-2xl font-extrabold text-cyan-100">Latest snapshot</h2>
                    <div className="mt-5 overflow-hidden rounded-[1.5rem] border-2 border-cyan-300/25 bg-slate-950">
                        {(captured_frame != "") and (<img src={captured_frame} alt="Captured LEGO frame" className="h-64 w-full object-cover" />)}
                        {(captured_frame == "") and (<div className="flex h-64 items-center justify-center px-6 text-center text-sm text-cyan-100/60">Capture a frame from the live webcam feed to preview the exact image sent to Brickognize.</div>)}
                    </div>
                    <div className="mt-4 grid gap-3 sm:grid-cols-2">
                        <div className="rounded-2xl border border-cyan-300/20 bg-cyan-400/6 p-4 text-sm text-cyan-100/70">
                            <p className="retro-display text-xs text-cyan-100">Provider</p>
                            <p className="mt-1 text-base text-cyan-50">{provider}</p>
                        </div>
                        <div className="rounded-2xl border border-amber-300/20 bg-amber-300/8 p-4 text-sm text-cyan-100/70">
                            <p className="retro-display text-xs text-cyan-100">Payload</p>
                            <p className="mt-1 text-base text-cyan-50">{payload_text}</p>
                        </div>
                        <div className="rounded-2xl border border-cyan-300/20 bg-cyan-400/6 p-4 text-sm text-cyan-100/70 sm:col-span-2">
                            <p className="retro-display text-xs text-cyan-100">Candidate count</p>
                            <p className="mt-1 text-base text-cyan-50">{candidate_text}</p>
                        </div>
                    </div>
                </div>
            </section>
        </div>
    );
}
