def:pub CountdownApp() -> JsxElement {
    has camera_on: bool = False;
    has status: str = "Camera ready to start";
    has permission: str = "Not requested";
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

    def start_camera() -> None {
        camera_on = True;
        permission = "Browser webcam permission required";
        status = "Live webcam mode enabled — point a LEGO piece at the camera";
    }

    def stop_camera() -> None {
        camera_on = False;
        permission = "Stopped";
        status = "Camera paused";
    }

    def capture_frame() -> None {
        if camera_on {
            status = "Captured current webcam frame for recognition preview";
        } else {
            status = "Start the webcam first";
        }
    }

    return <main className="min-h-screen bg-background px-4 py-10 text-foreground sm:px-6 lg:px-8">
        <div className="mx-auto grid max-w-6xl gap-8 lg:grid-cols-[1.15fr_0.85fr]">
            <section className="rounded-[2rem] border border-border bg-card p-8 shadow-card sm:p-10">
                <div className="inline-flex items-center gap-2 rounded-full bg-red-100 px-4 py-2 text-sm font-semibold text-red-600">
                    <span>🧱</span>
                    LEGO Vision Finder
                </div>
                <h1 className="mt-6 text-4xl font-extrabold tracking-tight sm:text-5xl">Live webcam LEGO recognition</h1>
                <p className="mt-4 max-w-2xl text-base leading-7 text-slate-600 sm:text-lg">No uploads. This flow is designed for a live webcam feed so you can hold a piece in front of the camera and classify it in real time.</p>

                <div className="mt-8 grid gap-4 sm:grid-cols-3">
                    <div className="rounded-2xl bg-red-50 p-4">
                        <p className="text-3xl font-extrabold text-red-600">Live</p>
                        <p className="mt-1 text-sm text-slate-600">Webcam-first capture mode</p>
                    </div>
                    <div className="rounded-2xl bg-amber-50 p-4">
                        <p className="text-3xl font-extrabold text-amber-600">Top-3</p>
                        <p className="mt-1 text-sm text-slate-600">Instant candidate ranking</p>
                    </div>
                    <div className="rounded-2xl bg-blue-50 p-4">
                        <p className="text-3xl font-extrabold text-blue-600">Frame</p>
                        <p className="mt-1 text-sm text-slate-600">Analyze the current camera view</p>
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
                        <div className="relative flex min-h-80 items-center justify-center px-6 py-8 text-center text-white">
                            <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(239,68,68,0.18),transparent_45%),linear-gradient(180deg,rgba(15,23,42,0.92),rgba(2,6,23,1))]"></div>
                            <div className="absolute inset-6 rounded-[1.25rem] border-2 border-dashed border-white/35"></div>
                            <div className="relative z-10 max-w-md">
                                <div className="mx-auto flex h-18 w-18 items-center justify-center rounded-full bg-white/10 text-4xl">📷</div>
                                <p className="mt-4 text-xl font-bold">{camera_on and "Camera stream active" or "Camera preview placeholder"}</p>
                                <p className="mt-2 text-sm leading-6 text-slate-200">{camera_on and "Your live webcam feed will appear here once browser camera access is wired in." or "This panel is now reserved for the live webcam stream instead of file upload."}</p>
                                <div className="mt-5 flex flex-wrap justify-center gap-2 text-xs font-semibold text-slate-200">
                                    <span className="rounded-full bg-white/10 px-3 py-1">Stud count</span>
                                    <span className="rounded-full bg-white/10 px-3 py-1">Silhouette</span>
                                    <span className="rounded-full bg-white/10 px-3 py-1">Color family</span>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div className="mt-5 flex flex-wrap gap-3">
                        <button className="inline-flex items-center justify-center rounded-xl bg-primary px-5 py-3 text-sm font-bold text-white transition hover:opacity-90" onClick={start_camera}>Start webcam</button>
                        <button className="inline-flex items-center justify-center rounded-xl border border-border bg-white px-5 py-3 text-sm font-bold text-foreground transition hover:bg-slate-50" onClick={capture_frame}>Analyze current frame</button>
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
                        </div> for item in alt_matches]}
                    </div>
                </div>

                <div className="rounded-[2rem] border border-border bg-card p-6 shadow-soft">
                    <p className="text-sm font-semibold uppercase tracking-[0.2em] text-muted-foreground">Webcam pipeline</p>
                    <h2 className="mt-2 text-2xl font-extrabold">How this should work</h2>
                    <div className="mt-5 space-y-4 text-sm leading-6 text-slate-600">
                        <p>1. Request browser camera access with <span className="font-semibold text-foreground">getUserMedia()</span>.</p>
                        <p>2. Render the live stream into a video element in this panel.</p>
                        <p>3. Grab frames on demand or on an interval for LEGO part recognition.</p>
                        <p>4. Send frame embeddings into a Jac graph to match parts, alternates, and set inventory context.</p>
                    </div>
                </div>
            </section>
        </div>
    </main>;
}
