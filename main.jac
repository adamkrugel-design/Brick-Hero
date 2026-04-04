import from services.recognition { recognize_lego_frame }

cl import ".styles.global.css";
cl import from .components.countdownApp { CountdownApp }

cl {
    def:pub app() -> JsxElement {
        return <main className="min-h-screen bg-background px-6 py-10 text-foreground">
            <CountdownApp />
        </main>;
    }
}
