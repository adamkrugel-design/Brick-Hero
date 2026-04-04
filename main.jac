import from services.recognition { recognize_lego_frame }

cl import from .components.countdownApp { CountdownApp }
cl import ".styles.global.css";

cl {
    def:pub app() -> JsxElement {
        return <CountdownApp />;
    }
}
