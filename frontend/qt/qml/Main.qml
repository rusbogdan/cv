
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    visible: true
    width: 1000
    height: 700
    title: "CV"
    color: "#ffffff"

    // Inter variants loaded here so they outlive IntroPage
    FontLoader { id: interRegular; source: "qrc:/qt/qml/Cv/fonts/Inter_18pt-Regular.ttf" }
    FontLoader { id: interBold;    source: "qrc:/qt/qml/Cv/fonts/Inter_18pt-Bold.ttf" }
    FontLoader { id: interItalic;  source: "qrc:/qt/qml/Cv/fonts/Inter_18pt-Italic.ttf" }

    font.family: interRegular.name.length > 0 ? interRegular.name : "Inter"
    font.pixelSize: 14

    // ── Intro ────────────────────────────────────────────────────────────────
    IntroPage {
        id: intro
        anchors.fill: parent
        z: 10
        visible: true
        onDone: {
            visible = false
            cvPage.startLoad()
        }
    }

    // ── Main CV page ─────────────────────────────────────────────────────────
    CvPage {
        id: cvPage
        anchors.fill: parent
        apiBase: apiBaseUrl
        onNavigateUnderTheHood: stack.push(underComp)
        function startLoad() { loadCv() }
    }

    // ── Under the Hood ───────────────────────────────────────────────────────
    StackView {
        id: stack
        anchors.fill: parent
    }

    Component {
        id: underComp
        UnderTheHood {
            apiBase: apiBaseUrl
            onBack: stack.clear()
        }
    }
}
