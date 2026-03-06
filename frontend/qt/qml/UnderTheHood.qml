
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property string apiBase: ""
    signal back()

    readonly property color bgColor:     "#ffffff"
    readonly property color cardColor:   "#f6f8fa"
    readonly property color accentColor: "#1a7f37"
    readonly property color accentBlue:  "#0969da"
    readonly property color textColor:   "#24292f"
    readonly property color dimColor:    "#57606a"
    readonly property color tagBg:       "#ddf4e1"
    readonly property color lineColor:   "#d0d7de"

    Rectangle { anchors.fill: parent; color: bgColor }

    // ── Header bar ──
    Rectangle {
        id: headerBar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 48
        color: cardColor
        z: 10

        Rectangle {
            id: backBtn
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 16
            width: backLabel.implicitWidth + 24
            height: 32
            radius: 6
            color: backMa.containsMouse ? accentColor : cardColor
            border.color: backMa.containsMouse ? accentColor : lineColor
            border.width: 1

            Text {
                id: backLabel
                anchors.centerIn: parent
                text: "Back to CV"
                color: backMa.containsMouse ? "#ffffff" : accentColor
                font.pixelSize: 13
            }

            MouseArea {
                id: backMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: back()
            }

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            text: "Under the Hood"
            color: accentColor
            font.pixelSize: 18
            font.bold: true
            anchors.centerIn: parent
        }
    }

    // ── Active balloon ──
    property string activeBlock: ""


    property var blocks: [
        {
            id: "aws",
            label: "AWS EC2 Instance t4g nano",
            col: 2, row: 0,
            colSpan: 4, rowSpan: 5,
            isGroup: true,
            title: "Cloud Infrastructure — AWS EC2 + S3",
            desc: "The API and HTML are served from a t4g.nano EC2 instance running Docker Compose. WASM assets (6.3 MB brotli-compressed) are stored in S3 and served directly to the browser — offloading the heavy transfer from the nano instance. Let's Encrypt provides HTTPS.",
            lang: "bash",
            code: "# ship.sh deploy pipeline\n./ship.sh\n# 1. Build WASM (Docker, amd64)\n# 2. Brotli-compress assets\n# 3. Upload .wasm/.js to S3\n# 4. Patch HTML to load from S3\n# 5. Build + push arm64 images\n# 6. Deploy to EC2 via SSH"
        },
        {
            id: "browser",
            label: "Browser",
            col: 0, row: 1,
            colSpan: 1, rowSpan: 1,
            isGroup: false,
            title: "User's Web Browser",
            desc: "The user accesses the application via any modern web browser. The HTML entry point is served by nginx on EC2. The WASM binary (6.3 MB br) and JS glue are fetched directly from S3 — bypassing the nano EC2 instance entirely for the heavy assets. API calls go back to the EC2 origin.",
            lang: "text",
            code: "https://timel.es  (nginx/EC2)\n\nBrowser loads:\n  1. cv_wasm.html  (EC2,   ~6 KB)\n  2. cv_wasm.js    (S3,  101 KB br)\n  3. cv_wasm.wasm  (S3,  6.3 MB br)\n  4. qtloader.js   (S3,  2.9 KB br)\n  5. Renders QML via WebGL canvas\n\nAPI calls: https://timel.es/api/*\n           -> nginx -> FastAPI"
        },
        {
            id: "https",
            label: "HTTPS / TLS",
            col: 1, row: 1,
            colSpan: 1, rowSpan: 1,
            isGroup: false,
            title: "HTTPS — Self-Signed TLS Certificate",
            desc: "All traffic is encrypted via HTTPS. The nginx container generates a self-signed certificate at build time using OpenSSL. This is deployed as-is on the EC2 instance. For production, the certificate would be replaced with a proper ACM-managed certificate behind an Application Load Balancer.",
            lang: "bash",
            code: "# Generated in Dockerfile.nginx\nRUN openssl req -x509 -nodes \\\n    -days 365 \\\n    -newkey rsa:2048 \\\n    -keyout /etc/nginx/ssl/dev.key \\\n    -out    /etc/nginx/ssl/dev.crt \\\n    -subj   '/CN=localhost'\n\n# Nginx serves on port 8443 (SSL)\nserver {\n    listen 8443 ssl;\n    ssl_certificate     /etc/nginx/ssl/dev.crt;\n    ssl_certificate_key /etc/nginx/ssl/dev.key;\n}"
        },
        {
            id: "frontend_group",
            label: "Frontend Container",
            col: 2, row: 1,
            colSpan: 2, rowSpan: 4,
            isGroup: true,
            title: "Frontend Container — Nginx + Qt WASM",
            desc: "An nginx container serves the Qt 6 WebAssembly application over HTTPS. It also acts as a reverse proxy, forwarding /api/ requests to the backend container. This solves CORS issues and keeps all traffic on a single origin.",
            lang: "nginx",
            code: "server {\n  listen 8443 ssl;\n  ssl_certificate     /etc/nginx/ssl/dev.crt;\n  ssl_certificate_key /etc/nginx/ssl/dev.key;\n  root /usr/share/nginx/html;\n  index cv_wasm.html;\n\n  location /api/ {\n    proxy_pass https://backend:8443/;\n    proxy_ssl_verify off;\n  }\n\n  location / {\n    try_files $uri $uri/\n      /cv_wasm.html;\n  }\n}"
        },
        {
            id: "nginx",
            label: "Nginx\nReverse Proxy",
            col: 2, row: 2,
            colSpan: 1, rowSpan: 1,
            isGroup: false,
            title: "Nginx — Static Files & Reverse Proxy",
            desc: "Nginx serves the static WebAssembly files (.wasm, .js, .html) and proxies API requests to the backend. The reverse proxy configuration allows the QML frontend to make same-origin requests to /api/, which nginx forwards to the backend container over the Docker network.",
            lang: "nginx",
            code: "# Static WASM files\nlocation ~ \\.wasm$ {\n    types { application/wasm wasm; }\n}\n\n# Reverse proxy to backend\nlocation /api/ {\n    proxy_pass https://backend:8443/;\n    proxy_ssl_verify off;\n    proxy_set_header Host $host;\n    proxy_set_header X-Real-IP\n        $remote_addr;\n}"
        },
        {
            id: "qt_wasm",
            label: "Qt 6 QML\n(WebAssembly)",
            col: 2, row: 3,
            colSpan: 1, rowSpan: 1,
            isGroup: false,
            title: "Qt 6 QML Frontend — Compiled to WebAssembly",
            desc: "The UI is built entirely in QML (Qt 6.6.3) and compiled to WebAssembly using Emscripten 3.1.37. The browser downloads and executes the .wasm binary, which renders the QML scene using WebGL. Environment variables are injected via Module.ENV in the HTML page before the WASM module loads.",
            lang: "qml",
            code: "Flickable {\n    contentHeight: col.height + 60\n    Column {\n        id: col\n        width: Math.min(\n            parent.width - 40, 800)\n        spacing: 24\n\n        Image {\n            source: apiBase +\n              \"/image?name=picture.jpg\"\n            fillMode: Image.PreserveAspectCrop\n        }\n\n        Repeater {\n            model: cvData.experience\n            Rectangle {\n                radius: 8; color: cardColor\n            }\n        }\n    }\n}"
        },
        {
            id: "emscripten",
            label: "Emscripten\nC++ Bridge",
            col: 2, row: 4,
            colSpan: 1, rowSpan: 1,
            isGroup: false,
            title: "Emscripten — C++ to WebAssembly Bridge",
            desc: "Emscripten compiles the Qt C++ application to WebAssembly. The main.cpp entry point reads API_BASE_URL from Module.ENV (injected in the HTML page) and exposes it as a QML context property. This allows the QML frontend to construct correct absolute URLs for API calls.",
            lang: "cpp",
            code: "#include <QGuiApplication>\n#include <QQmlApplicationEngine>\n#include <QQmlContext>\n\nint main(int argc, char *argv[]) {\n  QGuiApplication app(argc, argv);\n  QQmlApplicationEngine engine;\n\n  // Injected via Module.ENV in HTML\n  QString apiBase =\n      qgetenv(\"API_BASE_URL\");\n  if (apiBase.isEmpty())\n      apiBase = \"/api\";\n\n  engine.rootContext()\n    ->setContextProperty(\n        \"apiBaseUrl\", apiBase);\n  engine.load(QUrl(\n    \"qrc:/CvWow/qml/Main.qml\"));\n  return app.exec();\n}"
        },
        {
            id: "backend_group",
            label: "Backend Container",
            col: 4, row: 1,
            colSpan: 2, rowSpan: 4,
            isGroup: true,
            title: "Backend Container — Python FastAPI",
            desc: "A lightweight Python container running FastAPI with uvicorn. Serves CV data as JSON, the profile picture as a binary file response, and a WebSocket endpoint for real-time updates. The backend also uses HTTPS with a self-signed certificate.",
            lang: "yaml",
            code: "# docker-compose.local.yml\nservices:\n  backend:\n    build:\n      context: ../backend\n    restart: unless-stopped\n\n  frontend:\n    build:\n      context: ../frontend\n      dockerfile: Dockerfile.nginx\n    ports:\n      - \"8444:8443\"\n    restart: unless-stopped"
        },
        {
            id: "fastapi",
            label: "FastAPI\nServer",
            col: 4, row: 2,
            colSpan: 1, rowSpan: 1,
            isGroup: false,
            title: "Python FastAPI — REST & WebSocket API",
            desc: "The backend is a Python FastAPI application serving the CV data parsed from YAML, the profile picture as a binary file response, and a WebSocket endpoint that supports real-time CV refresh commands.",
            lang: "python",
            code: "from fastapi import FastAPI, WebSocket\nfrom fastapi.responses import (\n    FileResponse, JSONResponse)\nimport yaml\n\napp = FastAPI(title=\"cv-backend\")\n\n@app.get(\"/cv\")\ndef get_cv():\n    data = yaml.safe_load(\n        CV_PATH.read_text())\n    return JSONResponse(data)\n\n@app.get(\"/image\")\ndef image(name: str = \"picture.jpg\"):\n    if name not in ALLOWED_IMAGES:\n        return JSONResponse(\n            {\"error\":\"not found\"}, 404)\n    return FileResponse(\n        APP_DIR / name,\n        media_type=ALLOWED_IMAGES[name])\n\n@app.websocket(\"/ws\")\nasync def ws(websocket: WebSocket):\n    await websocket.accept()\n    data = await websocket.receive_text()\n    await websocket.send_json(\n      {\"type\":\"cv_updated\",\n       \"cv\": load_cv()})"
        },
        {
            id: "cv_data",
            label: "CV Data\n(YAML)",
            col: 4, row: 3,
            colSpan: 1, rowSpan: 1,
            isGroup: false,
            title: "CV Data — YAML Source of Truth",
            desc: "All CV content is stored in a single cv.yaml file alongside the application code. The backend parses it on each request, so updating the CV is as simple as editing the YAML file and triggering a refresh via WebSocket.",
            lang: "yaml",
            code: "basics:\n  name: Bogdan Rus\n  title: >-\n    Vehicle Software &\n    Systems Architect\n  location: Timisoara, Romania\n  contact:\n    email: rusbogdanclaudiu@\n           googlemail.com\n    phone: \"+40740222729\"\n  summary: >\n    Senior automotive software\n    architect with nearly two\n    decades of experience..."
        },
        {
            id: "images",
            label: "Images\nEndpoint",
            col: 4, row: 4,
            colSpan: 1, rowSpan: 1,
            isGroup: false,
            title: "Image Serving — GET /image?name=",
            desc: "Profile picture and GitHub contributions chart are served via a single GET endpoint with a query string parameter. An allow-list restricts which files can be served. The QML frontend loads them directly using Image elements.",
            lang: "python",
            code: "ALLOWED_IMAGES = {\n    \"picture.jpg\": \"image/jpeg\",\n    \"contributions.png\": \"image/png\",\n}\n\n@app.get(\"/image\")\ndef image(name: str = \"picture.jpg\"):\n    if name not in ALLOWED_IMAGES:\n        return JSONResponse(\n            {\"error\": \"not found\"}, 404)\n    return FileResponse(\n        APP_DIR / name,\n        media_type=ALLOWED_IMAGES[name])"
        },
        {
            id: "stats",
            label: "Payload\nStats",
            col: 0, row: 5,
            colSpan: 1, rowSpan: 1,
            isGroup: false,
            title: "Payload & Performance Statistics",
            desc: "Key metrics about the application's transfer sizes and loading performance. WASM and JS assets are served from S3 — the nano EC2 instance only serves the 6 KB HTML entry point and API responses. The browser caches WASM after the first load.",
            lang: "text",
            code: "Compression pipeline:\n  wasm-opt -Oz (Docker): -> 24 MB\n  brotli-11 (ship.sh):   ->  6.3 MB (-74%)\n\n  js raw:  552 KB\n  js br:   101 KB  (-82%)\n\nS3 transfer (br, cached):\n  cv_wasm.wasm:  6.3 MB\n  cv_wasm.js:    101 KB\n  qtloader.js:   2.9 KB\n\nEC2 transfer (nginx):\n  cv_wasm.html:  ~6 KB\n  /api/*:        ~22 KB\n──────────────────────────\nTotal first load: ~6.4 MB"
        },
        {
            id: "brotli",
            label: "wasm-opt\n+ Brotli",
            col: 2, row: 5,
            colSpan: 1, rowSpan: 1,
            isGroup: false,
            title: "wasm-opt -Oz + Brotli-11 Compression",
            desc: "Two compression stages before S3 upload. wasm-opt -Oz runs inside Dockerfile.wasm-build (binaryen) after the CMake build — WASM-level dead-code elimination and instruction compaction. ship.sh then applies brotli -q 11 before uploading. Assets are served with Content-Encoding: br so browsers decompress transparently.",
            lang: "bash",
            code: "# Stage 1: wasm-opt -Oz (Dockerfile)\n# Runs after cmake --build:\nwasm-opt -Oz cv_wasm.wasm \\\n  -o cv_wasm.wasm\n# raw build -> 24 MB\n\n# Stage 2: brotli-11 (ship.sh)\nbrotli -q 11 -f \\\n  -o cv_wasm.wasm.br cv_wasm.wasm\n# 24 MB -> 6.3 MB (-74%)\n\nbrotli -q 11 -f \\\n  -o cv_wasm.js.br cv_wasm.js\n# 552 KB -> 101 KB (-82%)"
        },
        {
            id: "s3_cdn",
            label: "AWS S3\nCDN (WASM)",
            col: 1, row: 5,
            colSpan: 1, rowSpan: 1,
            isGroup: false,
            title: "AWS S3 — Static Asset CDN for WASM",
            desc: "Compressed assets are uploaded under their original filenames with Content-Encoding: br. S3 sends this header verbatim so browsers decompress transparently — the WASM runtime receives plain bytes without any code changes. cv_wasm.wasm (6.3 MB), cv_wasm.js (101 KB) and qtloader.js (2.9 KB) are served from S3; nginx only serves the ~6 KB HTML entry point.",
            lang: "bash",
            code: "aws s3 cp cv_wasm.wasm.br \\\n  s3://BUCKET/cv_wasm.wasm \\\n  --content-type application/wasm \\\n  --content-encoding br\n\n# S3 object headers:\n# Content-Type: application/wasm\n# Content-Encoding: br\n# -> browser decompresses\n# -> WASM runtime sees plain bytes\n# -> no code changes needed"
        },
        {
            id: "github",
            label: "GitHub",
            col: 3, row: 5,
            colSpan: 1, rowSpan: 1,
            isGroup: false,
            isLink: true,
            linkUrl: "https://github.com/rusbogdan/cv",
            title: "Source Code — GitHub",
            desc: "The complete source code for this project is publicly available on GitHub. Click this block to open the repository. It contains the FastAPI backend, Qt QML frontend, Docker configurations, build scripts, and the CV data.",
            lang: "bash",
            code: "git clone \\\n  https://github.com/rusbogdan/cv\ncd cv\n./build.sh\n\n# Repository structure:\n# backend/     - FastAPI + cv.yaml\n# frontend/qt/ - QML source\n# frontend/dist/- WASM build output\n# infra/       - Docker Compose\n# build.sh     - Build pipeline"
        }
    ]

    // ── Connector definitions ──
    property var connectors: [
        { from: "browser", to: "https", label: "HTTPS" },
        { from: "https", to: "nginx", label: "TLS" },
        { from: "nginx", to: "qt_wasm", label: "HTML" },
        { from: "nginx", to: "fastapi", label: "/api/*" },
        { from: "qt_wasm", to: "emscripten", label: "" },
        { from: "fastapi", to: "cv_data", label: "" },
        { from: "fastapi", to: "images", label: "" },
        { from: "brotli", to: "s3_cdn", label: "~10 MB\nbr" },
        { from: "browser", to: "s3_cdn", label: "WASM\n~10 MB" }
    ]

    // ── Grid layout parameters ──
    property int gridCols: 6
    property int gridRows: 6
    property real cellPadding: 8
    property real groupInset: 28
    property real blockScale: 0.6  // non-group blocks are 60% of cell size

    function cellX(col, w) {
        var cw = (diagramArea.width - 40) / gridCols
        return 20 + col * cw + cellPadding
    }
    function cellY(row, h) {
        var ch = (diagramArea.height - 40) / gridRows
        return 20 + row * ch + cellPadding
    }
    function cellW(span) {
        var cw = (diagramArea.width - 40) / gridCols
        return span * cw - cellPadding * 2
    }
    function cellH(span) {
        var ch = (diagramArea.height - 40) / gridRows
        return span * ch - cellPadding * 2
    }

    // Scaled block position and size (centers block within its cell)
    function blockX(b) {
        var x = cellX(b.col, 0)
        if (b.isGroup) return x
        var fullW = cellW(b.colSpan)
        var scaledW = fullW * blockScale
        return x + (fullW - scaledW) / 2
    }
    function blockY(b) {
        var y = cellY(b.row, 0)
        if (b.isGroup) return y
        var fullH = cellH(b.rowSpan)
        var scaledH = fullH * blockScale
        return y + (fullH - scaledH) / 2
    }
    function blockW(b) {
        if (b.isGroup) return cellW(b.colSpan)
        return cellW(b.colSpan) * blockScale
    }
    function blockH(b) {
        if (b.isGroup) return cellH(b.rowSpan)
        return cellH(b.rowSpan) * blockScale
    }

    function blockCenterX(b) {
        return blockX(b) + blockW(b) / 2
    }
    function blockCenterY(b) {
        return blockY(b) + blockH(b) / 2
    }

    function findBlock(id) {
        for (var i = 0; i < blocks.length; i++) {
            if (blocks[i].id === id) return blocks[i]
        }
        return null
    }

    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: headerBar.bottom; bottom: parent.bottom }
        contentWidth: diagramArea.width
        contentHeight: diagramArea.height
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: diagramArea
            width: Math.max(root.width, 800)
            height: Math.max(root.height - headerBar.height, 700)

            // ── Click empty area to close balloon ──
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: activeBlock = ""
            }

            // ── Draw connector lines ──
            Canvas {
                id: lineCanvas
                anchors.fill: parent
                z: 1
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()

                    for (var ci = 0; ci < connectors.length; ci++) {
                        var conn = connectors[ci]
                        var fb = findBlock(conn.from)
                        var tb = findBlock(conn.to)
                        if (!fb || !tb) continue

                        var fx = blockCenterX(fb)
                        var fy = blockCenterY(fb)
                        var tx = blockCenterX(tb)
                        var ty = blockCenterY(tb)

                        ctx.strokeStyle = accentColor
                        ctx.lineWidth = 2
                        ctx.globalAlpha = 0.5
                        ctx.setLineDash([6, 4])

                        ctx.beginPath()
                        ctx.moveTo(fx, fy)
                        ctx.lineTo(tx, ty)
                        ctx.stroke()

                        // Arrow head
                        var angle = Math.atan2(ty - fy, tx - fx)
                        var arrowLen = 10
                        ctx.setLineDash([])
                        ctx.beginPath()
                        ctx.moveTo(tx, ty)
                        ctx.lineTo(tx - arrowLen * Math.cos(angle - 0.4), ty - arrowLen * Math.sin(angle - 0.4))
                        ctx.moveTo(tx, ty)
                        ctx.lineTo(tx - arrowLen * Math.cos(angle + 0.4), ty - arrowLen * Math.sin(angle + 0.4))
                        ctx.stroke()

                        // Label
                        if (conn.label !== "") {
                            ctx.globalAlpha = 0.8
                            ctx.fillStyle = dimColor
                            ctx.font = "10px sans-serif"
                            ctx.textAlign = "center"
                            var lines = conn.label.split("\n")
                            var mx = (fx + tx) / 2
                            var my = (fy + ty) / 2 - (lines.length * 6)
                            for (var li = 0; li < lines.length; li++) {
                                ctx.fillText(lines[li], mx, my + li * 13)
                            }
                        }
                        ctx.globalAlpha = 1.0
                    }
                }

                Component.onCompleted: requestPaint()
                Connections {
                    target: diagramArea
                    function onWidthChanged() { lineCanvas.requestPaint() }
                    function onHeightChanged() { lineCanvas.requestPaint() }
                }
            }

            // ── Draw blocks ──
            Repeater {
                model: blocks

                Rectangle {
                    id: blockRect
                    z: modelData.isGroup ? 0 : 2

                    x: blockX(modelData)
                    y: blockY(modelData)
                    width: blockW(modelData)
                    height: blockH(modelData)

                    radius: modelData.isGroup ? 12 : 8
                    color: modelData.isGroup ? "transparent" : (blockMa.containsMouse ? "#ddf4e1" : cardColor)
                    border.color: modelData.isGroup ? lineColor : (blockMa.containsMouse ? accentColor : lineColor)
                    border.width: modelData.isGroup ? 2 : (blockMa.containsMouse ? 2 : 1)

                    // Dotted border for groups
                    Rectangle {
                        visible: modelData.isGroup === true
                        anchors.fill: parent
                        color: "transparent"
                        radius: 12
                        border.color: "transparent"

                        Canvas {
                            anchors.fill: parent
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.strokeStyle = lineColor
                                ctx.lineWidth = 2
                                ctx.setLineDash([8, 5])
                                ctx.beginPath()
                                var r = 12
                                var w = width; var h = height
                                ctx.moveTo(r, 0)
                                ctx.lineTo(w - r, 0)
                                ctx.arcTo(w, 0, w, r, r)
                                ctx.lineTo(w, h - r)
                                ctx.arcTo(w, h, w - r, h, r)
                                ctx.lineTo(r, h)
                                ctx.arcTo(0, h, 0, h - r, r)
                                ctx.lineTo(0, r)
                                ctx.arcTo(0, 0, r, 0, r)
                                ctx.stroke()
                            }
                            Component.onCompleted: requestPaint()
                        }
                    }

                    Behavior on border.color { ColorAnimation { duration: 200 } }
                    Behavior on color { ColorAnimation { duration: 200 } }

                    // Group label at top-left
                    Text {
                        visible: modelData.isGroup === true
                        text: modelData.label
                        color: dimColor
                        font.pixelSize: 11
                        font.bold: true
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 10
                        opacity: 0.8
                    }

                    // Block label centered
                    Column {
                        visible: modelData.isGroup !== true
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            text: modelData.label
                            color: textColor
                            font.pixelSize: 13
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        // Link hint
                        Text {
                            visible: modelData.isLink === true
                            text: "(click to open)"
                            color: accentColor
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        id: blockMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: modelData.isGroup ? Qt.ArrowCursor : Qt.PointingHandCursor
                        propagateComposedEvents: modelData.isGroup === true
                        onClicked: function(mouse) {
                            if (modelData.isGroup) {
                                mouse.accepted = false
                                return
                            }
                            if (modelData.isLink) {
                                Qt.openUrlExternally(modelData.linkUrl)
                                return
                            }
                            if (activeBlock === modelData.id) {
                                activeBlock = ""
                            } else {
                                activeBlock = modelData.id
                            }
                        }
                    }
                }
            }

            // ── Balloon overlay ──
            Repeater {
                model: blocks

                Item {
                    id: balloonWrapper
                    visible: activeBlock === modelData.id && modelData.isGroup !== true
                    z: 200

                    property real bx: blockX(modelData) + blockW(modelData) + 12
                    property real by: blockY(modelData)

                    x: {
                        if (bx + 360 > diagramArea.width)
                            return blockX(modelData) - 372
                        return bx
                    }
                    y: Math.max(8, Math.min(by, diagramArea.height - balloonContent.height - 40))
                    width: 360

                    Rectangle {
                        id: balloonContent
                        width: 360
                        height: balloonCol.height + 28
                        radius: 10
                        color: cardColor
                        border.color: accentColor
                        border.width: 1

                        Column {
                            id: balloonCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                            spacing: 8

                            Text {
                                text: modelData.title
                                color: accentColor
                                font.pixelSize: 14
                                font.bold: true
                                width: parent.width
                                wrapMode: Text.Wrap
                            }

                            Text {
                                text: modelData.desc
                                color: textColor
                                font.pixelSize: 12
                                width: parent.width
                                wrapMode: Text.Wrap
                                lineHeight: 1.4
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: lineColor
                            }

                            Text {
                                text: {
                                    var l = modelData.lang
                                    if (l === "python") return "Python"
                                    if (l === "qml") return "QML"
                                    if (l === "cpp") return "C++"
                                    if (l === "yaml") return "YAML"
                                    if (l === "nginx") return "Nginx Config"
                                    if (l === "bash") return "Shell"
                                    return l.toUpperCase()
                                }
                                color: dimColor
                                font.pixelSize: 10
                                font.bold: true
                            }

                            Rectangle {
                                width: parent.width
                                height: codeText.implicitHeight + 16
                                radius: 6
                                color: "#f6f8fa"
                                border.color: lineColor
                                border.width: 1

                                Text {
                                    id: codeText
                                    anchors { fill: parent; margins: 8 }
                                    text: syntaxHighlight(modelData.code, modelData.lang)
                                    textFormat: Text.RichText
                                    font.family: "monospace"
                                    font.pixelSize: 10
                                    wrapMode: Text.Wrap
                                    lineHeight: 1.3
                                }
                            }
                        }

                        // Close button
                        Rectangle {
                            anchors { right: parent.right; top: parent.top; margins: 6 }
                            width: 20; height: 20; radius: 10
                            color: closeMa.containsMouse ? "#ff4444" : tagBg

                            Text {
                                anchors.centerIn: parent
                                text: "x"
                                color: textColor
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: activeBlock = ""
                            }

                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        scale: visible ? 1.0 : 0.9
                        opacity: visible ? 1.0 : 0.0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }
            }
        }
    }

    // ── Syntax highlighting ──

    function syntaxHighlight(code, lang) {
        var escaped = code.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        var lines = escaped.split("\n")
        var result = []

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]

            if (lang === "python") {
                line = colorize(line, [
                    { pattern: /#.*$/, color: "#57606a" },
                    { pattern: /"[^"]*"/g, color: "#0550ae" },
                    { pattern: /'[^']*'/g, color: "#0550ae" },
                    { pattern: /\b(from|import|def|async|await|return|if|else|for|while|try|except|class|pass|True|False|None)\b/g, color: "#cf222e" },
                    { pattern: /@\w+/g, color: "#8250df" }
                ])
            } else if (lang === "qml") {
                line = colorize(line, [
                    { pattern: /\/\/.*$/g, color: "#57606a" },
                    { pattern: /\/\*.*\*\//g, color: "#57606a" },
                    { pattern: /"[^"]*"/g, color: "#0550ae" },
                    { pattern: /\b(import|property|signal|function|var|if|else|return|true|false)\b/g, color: "#cf222e" },
                    { pattern: /\b(Item|Rectangle|Column|Row|Text|Image|Flickable|Repeater|Flow|RowLayout|ColumnLayout|Canvas|MouseArea)\b/g, color: "#953800" }
                ])
            } else if (lang === "cpp") {
                line = colorize(line, [
                    { pattern: /\/\/.*$/g, color: "#57606a" },
                    { pattern: /"[^"]*"/g, color: "#0550ae" },
                    { pattern: /\b(include|int|char|return|if|else|void|QString|QUrl)\b/g, color: "#cf222e" },
                    { pattern: /#\w+/g, color: "#8250df" }
                ])
            } else if (lang === "yaml") {
                line = colorize(line, [
                    { pattern: /#.*$/g, color: "#57606a" },
                    { pattern: /"[^"]*"/g, color: "#0550ae" },
                    { pattern: /\b(true|false|null)\b/g, color: "#cf222e" },
                    { pattern: /^(\s*)(\w[\w\-]*)\s*:/g, color: "#0969da" }
                ])
            } else if (lang === "nginx") {
                line = colorize(line, [
                    { pattern: /#.*$/g, color: "#57606a" },
                    { pattern: /\b(server|listen|ssl|location|proxy_pass|proxy_ssl_verify|proxy_set_header|root|index|ssl_certificate|ssl_certificate_key|try_files|types)\b/g, color: "#cf222e" },
                    { pattern: /"[^"]*"/g, color: "#0550ae" },
                    { pattern: /\d+/g, color: "#953800" }
                ])
            } else if (lang === "bash") {
                line = colorize(line, [
                    { pattern: /#.*$/g, color: "#57606a" },
                    { pattern: /"[^"]*"/g, color: "#0550ae" },
                    { pattern: /'[^']*'/g, color: "#0550ae" },
                    { pattern: /\b(cd|git|ssh|openssl|RUN|req)\b/g, color: "#cf222e" }
                ])
            } else {
                line = colorize(line, [
                    { pattern: /#.*$/g, color: "#57606a" }
                ])
            }

            result.push(line)
        }

        return "<pre style='margin:0;white-space:pre-wrap;color:#24292f;'>" + result.join("\n") + "</pre>"
    }

    function colorize(line, rules) {
        // Collect all matches with positions, avoiding overlaps
        var tokens = []
        for (var i = 0; i < rules.length; i++) {
            var r = rules[i]
            var re = new RegExp(r.pattern.source, r.pattern.flags)
            var m
            while ((m = re.exec(line)) !== null) {
                var start = m.index
                var end = start + m[0].length
                // Skip if overlaps with an existing token
                var overlaps = false
                for (var j = 0; j < tokens.length; j++) {
                    if (start < tokens[j].end && end > tokens[j].start) {
                        overlaps = true
                        break
                    }
                }
                if (!overlaps && m[0].length > 0) {
                    tokens.push({ start: start, end: end, color: r.color })
                }
                if (!r.pattern.global) break
            }
        }
        // Sort by position
        tokens.sort(function(a, b) { return a.start - b.start })
        // Build result
        var out = ""
        var pos = 0
        for (var k = 0; k < tokens.length; k++) {
            var t = tokens[k]
            out += line.substring(pos, t.start)
            out += "<font color='" + t.color + "'>" + line.substring(t.start, t.end) + "</font>"
            pos = t.end
        }
        out += line.substring(pos)
        return out
    }
}
