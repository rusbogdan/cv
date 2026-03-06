
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property string apiBase: ""
    signal navigateUnderTheHood()

    readonly property color bgColor:     "#ffffff"
    readonly property color cardColor:   "#f6f8fa"
    readonly property color accentColor: "#1a7f37"
    readonly property color accentBlue:  "#0969da"
    readonly property color textColor:   "#24292f"
    readonly property color dimColor:    "#57606a"
    readonly property color tagBg:       "#ddf4e1"
    readonly property color lineColor:   "#d0d7de"

    Rectangle { anchors.fill: parent; color: bgColor }

    property var cvData: null

    // ── Header bar ──
    Rectangle {
        id: headerBar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 48
        color: cardColor
        z: 10

        Text {
            text: "CV"
            color: accentColor
            font.pixelSize: 18
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 16
        }

        Rectangle {
            id: hoodBtn
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 16
            width: hoodLabel.implicitWidth + 24
            height: 32
            radius: 6
            color: hoodMa.containsMouse ? accentColor : cardColor
            border.color: hoodMa.containsMouse ? accentColor : lineColor
            border.width: 1

            Text {
                id: hoodLabel
                anchors.centerIn: parent
                text: "Under the Hood"
                color: hoodMa.containsMouse ? "#ffffff" : accentColor
                font.pixelSize: 13
            }

            MouseArea {
                id: hoodMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: navigateUnderTheHood()
            }

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Rectangle {
            id: printBtn
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: hoodBtn.left
            anchors.rightMargin: 8
            width: printLabel.implicitWidth + 24
            height: 32
            radius: 6
            color: printMa.containsMouse ? "#0969da" : cardColor
            border.color: printMa.containsMouse ? "#0969da" : lineColor
            border.width: 1

            Text {
                id: printLabel
                anchors.centerIn: parent
                text: "Print"
                color: printMa.containsMouse ? "#ffffff" : accentBlue
                font.pixelSize: 13
            }

            MouseArea {
                id: printMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: printHelper.print()
            }

            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: headerBar.bottom; bottom: parent.bottom }
        contentWidth: width
        contentHeight: col.height + 60
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: Math.min(parent.width - 40, 800)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24
            topPadding: 30

            // ── Loading / Error ──
            Text {
                id: statusTxt
                width: parent.width
                text: "Loading..."
                color: dimColor
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                visible: cvData === null
            }

            // ── Header ──
            Item {
                width: parent.width
                height: headerRow.height
                visible: cvData !== null

                RowLayout {
                    id: headerRow
                    width: parent.width
                    spacing: 20

                    Rectangle {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 120
                        radius: 60
                        color: cardColor
                        clip: true

                        Image {
                            id: profilePic
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: root.apiBase !== "" ? root.apiBase + "/image?name=picture.jpg" : ""
                            onStatusChanged: {
                                if (status === Image.Error)
                                    console.log("[cv] picture.jpg FAILED: " + source)
                                else if (status === Image.Ready)
                                    console.log("[cv] picture.jpg OK: " + source)
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: cvData ? cvData.basics.name : ""
                            color: textColor
                            font.pixelSize: 28
                            font.bold: true
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }
                        Text {
                            text: cvData ? cvData.basics.title : ""
                            color: accentColor
                            font.pixelSize: 16
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }
                        Text {
                            text: cvData ? cvData.basics.location : ""
                            color: dimColor
                            font.pixelSize: 13
                            Layout.fillWidth: true
                        }
                        Text {
                            text: {
                                if (!cvData) return ""
                                var c = cvData.basics.contact
                                return c.email + "  |  " + c.phone
                            }
                            color: dimColor
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            // ── Summary ──
            Column {
                width: parent.width
                spacing: 8
                visible: cvData !== null

                SectionHeader { label: "Summary" }

                Text {
                    width: parent.width
                    text: cvData ? cvData.basics.summary.trim() : ""
                    color: textColor
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                    lineHeight: 1.5
                }
            }

            // ── Architecture Focus ──
            Column {
                width: parent.width
                spacing: 8
                visible: cvData !== null

                SectionHeader { label: "Architecture Focus" }

                Text { text: "Domains"; color: dimColor; font.pixelSize: 12; font.bold: true }
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: cvData ? cvData.architecture_focus.domains : []
                        Tag { text: modelData }
                    }
                }

                Text { text: "Competencies"; color: dimColor; font.pixelSize: 12; font.bold: true; topPadding: 6 }
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: cvData ? cvData.architecture_focus.competencies : []
                        Tag { text: modelData }
                    }
                }
            }

            // ── Technology ──
            Column {
                width: parent.width
                spacing: 8
                visible: cvData !== null

                SectionHeader { label: "Technology" }

                Repeater {
                    model: cvData ? ["programming", "embedded", "automotive", "distributed"] : []
                    Column {
                        width: parent.width
                        spacing: 4
                        topPadding: index > 0 ? 6 : 0

                        Text {
                            text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                            color: dimColor
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Flow {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: cvData.technology[modelData]
                                Tag { text: modelData }
                            }
                        }
                    }
                }
            }

            // ── Experience ──
            Column {
                width: parent.width
                spacing: 10
                visible: cvData !== null

                SectionHeader { label: "Experience" }

                Repeater {
                    model: cvData ? cvData.experience : []

                    Rectangle {
                        width: parent.width
                        height: expCol.height + 24
                        radius: 8
                        color: cardColor
                        border.color: lineColor
                        border.width: 1

                        Column {
                            id: expCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 6

                            RowLayout {
                                width: parent.width
                                Text {
                                    text: modelData.role
                                    color: textColor
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }
                                Text {
                                    text: modelData.period
                                    color: accentColor
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                text: modelData.company + (modelData.location ? "  ·  " + modelData.location : "")
                                color: dimColor
                                font.pixelSize: 12
                            }

                            Column {
                                width: parent.width
                                spacing: 3
                                topPadding: 4
                                Repeater {
                                    model: modelData.highlights
                                    Text {
                                        width: parent.width
                                        text: "·  " + modelData
                                        color: textColor
                                        font.pixelSize: 12
                                        wrapMode: Text.Wrap
                                        leftPadding: 8
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Education ──
            Column {
                width: parent.width
                spacing: 10
                visible: cvData !== null

                SectionHeader { label: "Education" }

                Repeater {
                    model: cvData ? cvData.education : []

                    Rectangle {
                        width: parent.width
                        height: eduCol.height + 24
                        radius: 8
                        color: cardColor
                        border.color: lineColor
                        border.width: 1

                        Column {
                            id: eduCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 4

                            RowLayout {
                                width: parent.width
                                Text {
                                    text: modelData.degree
                                    color: textColor
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }
                                Text {
                                    text: modelData.period
                                    color: accentColor
                                    font.pixelSize: 12
                                }
                            }
                            Text {
                                text: modelData.institution
                                color: dimColor
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            // ── Certifications ──
            Column {
                width: parent.width
                spacing: 8
                visible: cvData !== null

                SectionHeader { label: "Certifications" }

                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: cvData ? cvData.certifications : []
                        Tag {
                            text: {
                                if (typeof modelData === "string") return modelData
                                var keys = Object.keys(modelData)
                                return keys[0] + ": " + modelData[keys[0]]
                            }
                        }
                    }
                }
            }

            // ── Selected Projects ──
            Column {
                width: parent.width
                spacing: 10
                visible: cvData !== null

                SectionHeader { label: "Selected Projects" }

                Repeater {
                    model: cvData ? cvData.selected_projects : []

                    Rectangle {
                        width: parent.width
                        height: projCol.height + 24
                        radius: 8
                        color: cardColor
                        border.color: lineColor
                        border.width: 1

                        Column {
                            id: projCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 4

                            Text {
                                text: modelData.name
                                color: textColor
                                font.pixelSize: 14
                                font.bold: true
                                width: parent.width
                                wrapMode: Text.Wrap
                            }
                            Text {
                                text: modelData.role
                                color: accentColor
                                font.pixelSize: 12
                            }

                            Flow {
                                width: parent.width
                                spacing: 6
                                topPadding: 4
                                visible: modelData.technologies !== undefined
                                Repeater {
                                    model: modelData.technologies || []
                                    Tag { text: modelData }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 3
                                topPadding: 4
                                visible: modelData.impact !== undefined
                                Repeater {
                                    model: modelData.impact || []
                                    Text {
                                        width: parent.width
                                        text: "·  " + modelData
                                        color: textColor
                                        font.pixelSize: 12
                                        wrapMode: Text.Wrap
                                        leftPadding: 8
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Interests ──
            Column {
                width: parent.width
                spacing: 8
                visible: cvData !== null

                SectionHeader { label: "Interests" }

                Text { text: "Research"; color: dimColor; font.pixelSize: 12; font.bold: true }
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: cvData ? cvData.research_interests : []
                        Tag { text: modelData }
                    }
                }

                Text { text: "Open Systems Work"; color: dimColor; font.pixelSize: 12; font.bold: true; topPadding: 6 }
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: cvData ? cvData.open_systems_work : []
                        Tag { text: modelData }
                    }
                }

                Text { text: "Personal"; color: dimColor; font.pixelSize: 12; font.bold: true; topPadding: 6 }
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: cvData ? cvData.personal_interests : []
                        Tag { text: modelData }
                    }
                }
            }

            // ── Contributions ──
            Column {
                width: parent.width
                spacing: 8
                visible: cvData !== null

                SectionHeader { label: "Contributions" }

                Image {
                    id: contribImg
                    width: parent.width
                    fillMode: Image.PreserveAspectFit
                    source: root.apiBase !== "" ? root.apiBase + "/image?name=contributions.png" : ""
                    onStatusChanged: {
                        if (status === Image.Error)
                            console.log("[cv] contributions.png FAILED: " + source)
                        else if (status === Image.Ready)
                            console.log("[cv] contributions.png OK: " + source)
                    }
                }
            }

            Item { width: 1; height: 30 }
        }
    }

    // ── Reusable components ──

    component SectionHeader: Column {
        property string label
        width: parent.width
        spacing: 6

        Text {
            text: label
            color: accentColor
            font.pixelSize: 13
            font.bold: true
            font.letterSpacing: 1.2
        }
        Row {
            spacing: 3
            Repeater {
                model: Math.min(Math.floor(parent.parent.width / 5), 120)
                Rectangle {
                    width: 3; height: 3; radius: 1
                    color: index % 4 === 0 ? "#9be9a8"
                         : index % 4 === 1 ? "#40c463"
                         : index % 4 === 2 ? "#30a14e"
                         : "#216e39"
                }
            }
        }
    }

    component Tag: Rectangle {
        property alias text: tagLabel.text
        width: tagLabel.implicitWidth + 14
        height: tagLabel.implicitHeight + 6
        radius: 2
        color: tagBg
        border.color: "#1a7f37"
        border.width: 1

        Text {
            id: tagLabel
            anchors.centerIn: parent
            color: "#1a7f37"
            font.pixelSize: 11
        }
    }

    // ── Data loading ──

    function loadCv() {
        if (apiBase === "") {
            console.log("[cv] loadCv: apiBase empty, skipping")
            return
        }
        var url = apiBase + "/cv"
        console.log("[cv] apiBase: '" + apiBase + "'")
        console.log("[cv] fetching: " + url)
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                console.log("[cv] XHR status: " + xhr.status + " url=" + url)
                if (xhr.status === 200) {
                    try {
                        cvData = JSON.parse(xhr.responseText)
                        statusTxt.visible = false
                        console.log("[cv] CV loaded OK, name=" + cvData.basics.name)
                    } catch(e) {
                        console.log("[cv] JSON parse error: " + e + " body=" + xhr.responseText.substring(0, 200))
                        statusTxt.text = "Parse error: " + e
                        statusTxt.color = "#ff6666"
                    }
                } else {
                    var body = xhr.responseText ? xhr.responseText.substring(0, 200) : "(empty)"
                    console.log("[cv] XHR error body: " + body)
                    if (xhr.status === 0)
                        console.log("[cv] status=0: URL may be treated as local file (relative path in WASM?). apiBase='" + apiBase + "'")
                    statusTxt.text = "Error: HTTP " + xhr.status
                    statusTxt.color = "#ff6666"
                }
            }
        }
        xhr.send()
    }

    Component.onCompleted: {
        console.log("[cv] CvPage ready, apiBase='" + root.apiBase + "'")
    }
}
