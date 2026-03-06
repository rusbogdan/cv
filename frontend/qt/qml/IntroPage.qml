
import QtQuick

Item {
    id: introRoot
    signal done()

    // ── 12 font variant loaders ──────────────────────────────────────────────
    FontLoader { id: fl0;  source: "qrc:/qt/qml/Cv/fonts/Inter_18pt-Thin.ttf" }
    FontLoader { id: fl1;  source: "qrc:/qt/qml/Cv/fonts/WorkSans-ThinItalic.ttf" }
    FontLoader { id: fl2;  source: "qrc:/qt/qml/Cv/fonts/DMSans_18pt-ExtraLight.ttf" }
    FontLoader { id: fl3;  source: "qrc:/qt/qml/Cv/fonts/Nunito-ExtraLightItalic.ttf" }
    FontLoader { id: fl4;  source: "qrc:/qt/qml/Cv/fonts/Sora-Light.ttf" }
    FontLoader { id: fl5;  source: "qrc:/qt/qml/Cv/fonts/SpaceGrotesk-Regular.ttf" }
    FontLoader { id: fl6;  source: "qrc:/qt/qml/Cv/fonts/Outfit-Medium.ttf" }
    FontLoader { id: fl7;  source: "qrc:/qt/qml/Cv/fonts/RobotoMono-Bold.ttf" }
    FontLoader { id: fl8;  source: "qrc:/qt/qml/Cv/fonts/Inter_18pt-BoldItalic.ttf" }
    FontLoader { id: fl9;  source: "qrc:/qt/qml/Cv/fonts/WorkSans-ExtraBold.ttf" }
    FontLoader { id: fl10; source: "qrc:/qt/qml/Cv/fonts/Nunito-Black.ttf" }
    FontLoader { id: fl11; source: "qrc:/qt/qml/Cv/fonts/DMSans_18pt-BlackItalic.ttf" }

    // Per-step: weight (numeric) + italic — consecutive steps differ by >= 1 attribute
    readonly property var cycleAttrs: [
        { weight: 100, italic: false },
        { weight: 100, italic: true  },
        { weight: 200, italic: false },
        { weight: 200, italic: true  },
        { weight: 300, italic: false },
        { weight: 400, italic: false },
        { weight: 500, italic: false },
        { weight: 700, italic: false },
        { weight: 700, italic: true  },
        { weight: 800, italic: false },
        { weight: 900, italic: false },
        { weight: 900, italic: true  }
    ]

    property var cycleFontNames: []
    function buildFontList() {
        var loaders = [fl0, fl1, fl2, fl3, fl4, fl5, fl6, fl7, fl8, fl9, fl10, fl11]
        var names = []
        for (var i = 0; i < loaders.length; i++)
            names.push(loaders[i].name || "Inter")
        cycleFontNames = names
    }

    // ── Slides: 1 animated keyword each ──────────────────────────────────────
    readonly property var slides: [
        { before: "Hello ",      key: "@Randstad", after: "!", dur: 2000 },
        { before: "I'm ",        key: "Bogdan Rus",    after: " @ timel.es",  dur: 2400 },
        { before: "Following is my ", key: "CV", after: " rendering with a similar stack as yours",  dur: 4000 }
    ]

    // body = 7/96 of screen height; key = 30% larger than body
    readonly property int bodySize: Math.max(16, Math.round(introRoot.height * 7 / 96))
    readonly property int keySize:  Math.max(20, Math.round(bodySize * 1.3))

    property int    slideIdx:    0
    property string keyFont:     "Inter"
    property int    keyWeight:   100
    property bool   keyItalic:   false
    property real   keyDisplaySize: keySize   // varies ±30% on each font switch

    readonly property real landingX: introRoot.width * 0.2
    readonly property real travelX:  100

    // ── Background ──────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: "#ffffff" }

    // ── Slide content ─────────────────────────────────────────────────────────
    // Absolute positioning so font-size cycling on the keyword never shifts
    // the surrounding "before" / "after" text.
    Item {
        id: slideItem
        width:   introRoot.width * 0.6
        height:  introRoot.height
        x:       introRoot.landingX + introRoot.travelX
        y:       0
        opacity: 0.0

        // Fixed vertical anchors: beforeText sits above centre, afterText below.
        // keyText is vertically centred between them; its height may vary but
        // that only changes its own bounding box, not the neighbours.

        // Reserve a fixed band for the keyword so size changes never move neighbours.
        // Max keyword height ≈ 130% of keySize (the upper end of the random range).
        readonly property real centerY:      introRoot.height / 2
        readonly property real keyBandHalf:  Math.ceil(introRoot.keySize * 1.3 / 2) + 4

        Text {
            id: beforeText
            width:               parent.width
            text:                slides[slideIdx].before
            font.pixelSize:      introRoot.bodySize
            color:               "#24292f"
            wrapMode:            Text.Wrap
            horizontalAlignment: Text.AlignLeft
            visible:             slides[slideIdx].before !== ""
            y:                   slideItem.centerY - slideItem.keyBandHalf - implicitHeight
        }
        Text {
            id: keyText
            width:               parent.width
            text:                slides[slideIdx].key
            font.family:         introRoot.keyFont
            font.pixelSize:      introRoot.keyDisplaySize
            font.weight:         introRoot.keyWeight
            font.italic:         introRoot.keyItalic
            color:               "#1a7f37"
            wrapMode:            Text.Wrap
            horizontalAlignment: Text.AlignLeft
            y:                   slideItem.centerY - implicitHeight / 2
        }
        Text {
            id: afterText
            width:               parent.width
            text:                slides[slideIdx].after
            font.pixelSize:      introRoot.bodySize
            color:               "#24292f"
            wrapMode:            Text.Wrap
            horizontalAlignment: Text.AlignLeft
            visible:             slides[slideIdx].after !== ""
            y:                   slideItem.centerY + slideItem.keyBandHalf
        }
    }

    // ── Font-cycle timer — runs for the entire slide duration ─────────────────
    Timer {
        id: cycleTimer
        interval: 140   // 140ms between font switches
        repeat:   true
        property int count: 0
        onTriggered: {
            count++
            if (cycleFontNames.length > 0) {
                var i = count % cycleFontNames.length
                introRoot.keyFont        = cycleFontNames[i]
                introRoot.keyWeight      = cycleAttrs[i].weight
                introRoot.keyItalic      = cycleAttrs[i].italic
                // ±30% size variance on each switch (range: 70%–130% of base)
                introRoot.keyDisplaySize = Math.round(introRoot.keySize * (0.9 + Math.random() * 0.2))
            }
        }
    }

    function startSlide(idx) {
        slideIdx         = idx
        cycleTimer.count = 0
        cycleTimer.start()
    }

    // ── Animation sequence ────────────────────────────────────────────────────
    SequentialAnimation {
        id: mainAnim
        running: false

        // Slide 0
        ScriptAction { script: { slideItem.x = introRoot.landingX + introRoot.travelX; slideItem.opacity = 0; startSlide(0) } }
        ParallelAnimation {
            NumberAnimation { target: slideItem; property: "x";       to: introRoot.landingX;                     duration: 380; easing.type: Easing.InOutQuad }
            NumberAnimation { target: slideItem; property: "opacity"; to: 1.0;                                    duration: 160; easing.type: Easing.InOutQuad }
        }
        PauseAnimation { duration: slides[0].dur - 700 }
        ParallelAnimation {
            NumberAnimation { target: slideItem; property: "opacity"; to: 0.0;                                    duration: 160; easing.type: Easing.InOutQuad }
            NumberAnimation { target: slideItem; property: "x";       to: introRoot.landingX - introRoot.travelX;  duration: 380; easing.type: Easing.InOutQuad }
        }

        // Slide 1
        ScriptAction { script: { slideItem.x = introRoot.landingX + introRoot.travelX; slideItem.opacity = 0; startSlide(1) } }
        ParallelAnimation {
            NumberAnimation { target: slideItem; property: "x";       to: introRoot.landingX;                     duration: 380; easing.type: Easing.InOutQuad }
            NumberAnimation { target: slideItem; property: "opacity"; to: 1.0;                                    duration: 160; easing.type: Easing.InOutQuad }
        }
        PauseAnimation { duration: slides[1].dur - 700 }
        ParallelAnimation {
            NumberAnimation { target: slideItem; property: "opacity"; to: 0.0;                                    duration: 160; easing.type: Easing.InOutQuad }
            NumberAnimation { target: slideItem; property: "x";       to: introRoot.landingX - introRoot.travelX;  duration: 380; easing.type: Easing.InOutQuad }
        }

        // Slide 2
        ScriptAction { script: { slideItem.x = introRoot.landingX + introRoot.travelX; slideItem.opacity = 0; startSlide(2) } }
        ParallelAnimation {
            NumberAnimation { target: slideItem; property: "x";       to: introRoot.landingX;                     duration: 380; easing.type: Easing.InOutQuad }
            NumberAnimation { target: slideItem; property: "opacity"; to: 1.0;                                    duration: 160; easing.type: Easing.InOutQuad }
        }
        PauseAnimation { duration: slides[2].dur - 700 }
        ParallelAnimation {
            NumberAnimation { target: slideItem; property: "opacity"; to: 0.0;                                    duration: 160; easing.type: Easing.InOutQuad }
            NumberAnimation { target: slideItem; property: "x";       to: introRoot.landingX - introRoot.travelX;  duration: 380; easing.type: Easing.InOutQuad }
        }

        // Fade out and hand off
        ScriptAction { script: cycleTimer.stop() }
        NumberAnimation { target: introRoot; property: "opacity"; to: 0.0; duration: 350; easing.type: Easing.InOutQuad }
        ScriptAction { script: introRoot.done() }
    }

    Timer {
        interval: 220; running: true; repeat: false
        onTriggered: { buildFontList(); mainAnim.start() }
    }
}
