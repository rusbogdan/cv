
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QObject>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

class PrintHelper : public QObject {
    Q_OBJECT
public:
    explicit PrintHelper(QObject *parent = nullptr) : QObject(parent) {}
    Q_INVOKABLE void print() {
#ifdef __EMSCRIPTEN__
        emscripten_run_script("window.print()");
#endif
    }
};

int main(int argc, char *argv[]) {
    qputenv("QML_XHR_ALLOW_FILE_READ", "1");

    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;

    QString apiBase;

#ifdef __EMSCRIPTEN__
    // qgetenv("API_BASE_URL") is unreliable for Module.ENV in Qt 6.6.3 WASM.
    // Read location.origin directly from JS — always correct, no race condition.
    const char* jsOrigin = emscripten_run_script_string("location.origin + '/api'");
    if (jsOrigin && jsOrigin[0] != '\0')
        apiBase = QString::fromUtf8(jsOrigin);
    if (apiBase.isEmpty())
        apiBase = QString::fromUtf8(qgetenv("API_BASE_URL"));
#else
    apiBase = qgetenv("API_BASE_URL");
#endif

    if (apiBase.isEmpty())
        apiBase = "/api";

    engine.rootContext()->setContextProperty("apiBaseUrl", apiBase);

    static PrintHelper printHelper;
    engine.rootContext()->setContextProperty("printHelper", &printHelper);

    engine.load(QUrl(QStringLiteral("qrc:/Cv/qml/Main.qml")));

    return app.exec();
}

#include "main.moc"
