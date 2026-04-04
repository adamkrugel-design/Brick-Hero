"""LEGO piece image recognition demo."""

cl import from .components.countdownApp { CountdownApp }
cl import ".styles.global.css";

cl {
    def:pub app() -> JsxElement {
        return <CountdownApp />;
    }
}