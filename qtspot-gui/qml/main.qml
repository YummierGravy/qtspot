import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import com.spotix.qt 1.0

ApplicationWindow {
    id: root

    width: 1180
    height: 780
    minimumWidth: 900
    minimumHeight: 560
    visible: true
    title: "qtspot"
    color: terminalBg

    readonly property SpotixApp spotix: SpotixApp {}
    property string activePane: "detail"
    property var expandedTreeIds: ({})
    property string selectedTreeId: "route:saved-tracks"
    property int treeRevision: 0
    property int playingTick: 0
    property int libraryPaneWidth: 330
    property int footerPaneHeight: 204
    property color terminalBg: "#181a20"
    property color panelBg: "#20232b"
    property color panelAlt: "#272b34"
    property color controlBg: "#242832"
    property color controlHover: "#303644"
    property color borderColor: "#596172"
    property color textColor: "#d7dce7"
    property color dimText: "#9aa3b5"
    property color accent: "#a6d4ff"
    property color cyan: "#9adbcf"
    property color kdeBlue: "#8fb8e8"
    property color kdeViolet: "#c7a0d9"
    property color warn: "#e6c987"
    property color error: "#e89a9a"
    property color selection: "#343b4a"
    property int rowHeight: 28

    Component.onCompleted: {
        root.spotix.refreshSession()
        root.spotix.loadLibrary()
        root.refocusKeyboard()
    }

    function formatTime(ms) {
        var total = Math.max(0, Math.floor(ms / 1000))
        var minutes = Math.floor(total / 60)
        var seconds = total % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    function parseArray(json) {
        try {
            return JSON.parse(json)
        } catch (e) {
            return []
        }
    }

    function currentTreeItem() {
        var items = treeList.model
        if (treeList.currentIndex < 0 || treeList.currentIndex >= items.length) {
            return null
        }
        return items[treeList.currentIndex]
    }

    function currentDetailRow() {
        var rows = root.parseArray(root.spotix.detail_rows_json)
        if (detailList.currentIndex < 0 || detailList.currentIndex >= rows.length) {
            return null
        }
        return rows[detailList.currentIndex]
    }

    function isAccountRoute() {
        return root.spotix.route === "login"
    }

    function playingGlyph() {
        var frames = ["|", "/", "-", "\\"]
        return frames[root.playingTick % frames.length]
    }

    function isNowPlayingRow(row) {
        return row && row.kind === "track" && root.spotix.playback_state === "Playing" && row.label === root.spotix.now_playing_title
    }

    function activateCurrent() {
        if (root.activePane === "tree") {
            var item = root.currentTreeItem()
            root.activateTreeItem(item)
            return
        }

        var row = root.currentDetailRow()
        if (!row) {
            return
        }
        if (row.playable || row.kind === "action" || row.kind === "album" || row.kind === "artist" || row.kind === "playlist" || row.kind === "show") {
            root.spotix.activateDetailRow(row.id)
        }
    }

    function moveSelection(delta) {
        var view = root.activePane === "tree" ? treeList : detailList
        var count = view.count
        if (count <= 0) {
            return
        }
        view.currentIndex = Math.max(0, Math.min(count - 1, view.currentIndex + delta))
        if (root.activePane === "tree") {
            var item = root.currentTreeItem()
            if (item) {
                root.selectedTreeId = item.id
            }
        }
        view.positionViewAtIndex(view.currentIndex, ListView.Contain)
    }

    function hasTreeChildren(itemId) {
        var items = root.parseArray(root.spotix.nav_tree_json)
        for (var i = 0; i < items.length; i++) {
            if (items[i].parent_id === itemId) {
                return true
            }
        }
        return false
    }

    function isTreeExpanded(itemId) {
        return root.expandedTreeIds[itemId] === true
    }

    function setTreeExpanded(itemId, expanded) {
        var next = {}
        for (var key in root.expandedTreeIds) {
            next[key] = root.expandedTreeIds[key]
        }
        next[itemId] = expanded
        root.expandedTreeIds = next
        root.treeRevision += 1
        Qt.callLater(root.restoreTreeSelection)
    }

    function visibleTreeItems(json, revision) {
        var items = root.parseArray(json)
        var byId = {}
        var visible = []
        for (var i = 0; i < items.length; i++) {
            byId[items[i].id] = items[i]
        }
        for (var j = 0; j < items.length; j++) {
            var item = items[j]
            var parentId = item.parent_id
            var isVisible = true
            while (parentId && byId[parentId]) {
                if (!root.isTreeExpanded(parentId)) {
                    isVisible = false
                    break
                }
                parentId = byId[parentId].parent_id
            }
            if (isVisible) {
                visible.push(item)
            }
        }
        return visible
    }

    function treePrefix(item) {
        if (root.hasTreeChildren(item.id)) {
            return root.isTreeExpanded(item.id) ? "- " : "+ "
        }
        return ""
    }

    function coverAscii(item) {
        if (!item) {
            return ""
        }
        if (item.art_ascii.length === 0) {
            return "<pre style=\"margin:0;color:#6f7480\">::::::<br/>::..::<br/>::::::</pre>"
        }
        return item.art_ascii
    }

    function shouldShowCoverAscii(item) {
        if (!item) {
            return false
        }
        return item.kind === "track" || item.kind === "album" || item.kind === "playlist" || item.kind === "show"
    }

    function activateTreeItem(item) {
        if (!item || !item.selectable) {
            return
        }
        root.selectedTreeId = item.id
        if (root.hasTreeChildren(item.id)) {
            root.setTreeExpanded(item.id, !root.isTreeExpanded(item.id))
        }
        root.spotix.activateTreeItem(item.id)
        Qt.callLater(root.restoreTreeSelection)
    }

    function collapseCurrentTreeItem() {
        var item = root.currentTreeItem()
        if (item && root.hasTreeChildren(item.id) && root.isTreeExpanded(item.id)) {
            root.selectedTreeId = item.id
            root.setTreeExpanded(item.id, false)
            return true
        }
        return false
    }

    function closeCurrentTreeBranch() {
        var item = root.currentTreeItem()
        if (!item) {
            return false
        }
        if (root.hasTreeChildren(item.id) && root.isTreeExpanded(item.id)) {
            root.selectedTreeId = item.id
            root.setTreeExpanded(item.id, false)
            return true
        }
        if (!item.parent_id) {
            return false
        }
        var items = treeList.model
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === item.parent_id) {
                treeList.currentIndex = i
                root.selectedTreeId = items[i].id
                root.setTreeExpanded(items[i].id, false)
                treeList.positionViewAtIndex(i, ListView.Contain)
                return true
            }
        }
        return false
    }

    function moveToFirstTreeChild() {
        var item = root.currentTreeItem()
        if (!item || !root.hasTreeChildren(item.id)) {
            return false
        }
        root.selectedTreeId = item.id
        if (!root.isTreeExpanded(item.id)) {
            root.setTreeExpanded(item.id, true)
        }
        var items = treeList.model
        for (var i = treeList.currentIndex + 1; i < items.length; i++) {
            if (items[i].parent_id === item.id) {
                treeList.currentIndex = i
                root.selectedTreeId = items[i].id
                treeList.positionViewAtIndex(i, ListView.Contain)
                return true
            }
        }
        return false
    }

    function moveToTreeParent() {
        var item = root.currentTreeItem()
        if (!item || !item.parent_id) {
            return false
        }
        var items = treeList.model
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === item.parent_id) {
                treeList.currentIndex = i
                root.selectedTreeId = items[i].id
                treeList.positionViewAtIndex(i, ListView.Contain)
                return true
            }
        }
        return false
    }

    function restoreTreeSelection() {
        var items = treeList.model
        if (!items || items.length === 0) {
            treeList.currentIndex = -1
            return
        }
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === root.selectedTreeId) {
                treeList.currentIndex = i
                treeList.positionViewAtIndex(i, ListView.Contain)
                return
            }
        }
        treeList.currentIndex = Math.max(0, Math.min(treeList.currentIndex, items.length - 1))
        root.selectedTreeId = items[treeList.currentIndex].id
    }

    function progressRatio() {
        if (root.spotix.playback_duration_ms <= 0) {
            return 0
        }
        return Math.max(0, Math.min(1, root.spotix.playback_progress_ms / root.spotix.playback_duration_ms))
    }

    function volumePercent() {
        return Math.round(Math.max(0, Math.min(1, root.spotix.volume)) * 100)
    }

    function barClickRatio(mouseX, barWidth) {
        return Math.max(0, Math.min(1, (mouseX - 2) / Math.max(1, barWidth - 4)))
    }

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value))
    }

    function footerSpacing() {
        return Math.max(1, Math.min(8, Math.floor((root.footerPaneHeight - 140) / 20)))
    }

    function footerControlHeight() {
        return root.footerPaneHeight <= 175 ? 26 : 30
    }

    function terminalBar(ratio, width, head) {
        var clamped = Math.max(0, Math.min(1, ratio))
        var filled = Math.floor(clamped * width)
        var output = "["
        for (var i = 0; i < width; i++) {
            if (i < filled) {
                output += "="
            } else if (i === filled && filled < width) {
                output += head
            } else {
                output += "-"
            }
        }
        return output + "]"
    }

    function eqBandLevel(index) {
        var bands = root.parseArray(root.spotix.spectrum_bands_json)
        if (index >= bands.length || root.spotix.playback_state !== "Playing") {
            return 0
        }
        return Math.max(0, Math.min(1, Number(bands[index]) || 0))
    }

    function eqColumn(index) {
        var visualLevel = Math.pow(Math.max(0, Math.min(1, root.eqBandLevel(index) * 1.45)), 0.72)
        var filled = Math.round(visualLevel * 4)
        var output = ""
        for (var row = 3; row >= 0; row--) {
            output += row < filled ? "#" : "."
            if (row > 0) {
                output += "\n"
            }
        }
        return output
    }

    function cargoStatusWord() {
        if (root.spotix.playback_state === "Playing") {
            return "Playing"
        }
        if (root.spotix.playback_state === "Paused") {
            return "Paused "
        }
        if (root.spotix.playback_state === "Loading") {
            return "Loading"
        }
        if (root.spotix.playback_state === "Blocked") {
            return "Blocked"
        }
        return "Stopped"
    }

    function accountName() {
        if (root.spotix.profile_name.length > 0) {
            return root.spotix.profile_name
        }
        return root.spotix.authenticated ? "Spotify account" : "Sign in"
    }

    function accountStatus() {
        if (root.spotix.authenticated) {
            return "Connected"
        }
        if (root.spotix.login_busy) {
            return "Waiting for browser"
        }
        return "Login required"
    }

    function nowPlayingText() {
        return root.spotix.now_playing_title + " :: " + root.spotix.now_playing_artist + (root.spotix.now_playing_album.length > 0 ? " / " + root.spotix.now_playing_album : "")
    }

    function refocusKeyboard() {
        keyboardRoot.forceActiveFocus()
    }

    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            root.playingTick += 1
            root.spotix.refreshPlayback()
            root.spotix.refreshSession()
        }
    }

    Item {
        id: keyboardRoot
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if ((searchField.activeFocus || accountKeyField.activeFocus) && event.key !== Qt.Key_Escape) {
                return
            }
            if (event.key === Qt.Key_Down) {
                root.moveSelection(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                root.moveSelection(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
                root.activePane = root.activePane === "tree" ? "detail" : "tree"
                event.accepted = true
            } else if (event.key === Qt.Key_Right && root.activePane === "tree") {
                root.moveToFirstTreeChild()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activateCurrent()
                event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backspace) {
                if (root.activePane === "tree" && root.closeCurrentTreeBranch()) {
                    event.accepted = true
                } else if (root.activePane === "tree" && event.key === Qt.Key_Left && root.moveToTreeParent()) {
                    event.accepted = true
                } else if (root.activePane !== "tree") {
                    root.spotix.navigateBack()
                    event.accepted = true
                } else {
                    event.accepted = true
                }
            } else if (event.key === Qt.Key_Space) {
                root.spotix.playPause()
                event.accepted = true
            } else if (event.key === Qt.Key_Slash) {
                searchField.forceActiveFocus()
                searchField.selectAll()
                event.accepted = true
            } else if (event.key === Qt.Key_R && event.modifiers & Qt.ControlModifier) {
                root.spotix.loadLibrary()
                root.spotix.refreshSession()
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                root.refocusKeyboard()
                event.accepted = true
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                color: panelBg
                border.color: borderColor
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 260
                        Layout.fillHeight: true
                        Layout.topMargin: 5
                        Layout.bottomMargin: 5
                        color: accountSettingsMouse.containsMouse ? controlHover : controlBg
                        border.color: accountSettingsMouse.containsMouse ? accent : kdeBlue
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Label {
                                text: root.spotix.authenticated ? "●" : "○"
                                color: root.spotix.authenticated ? accent : warn
                                font.family: "monospace"
                                font.pixelSize: 13
                                font.bold: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Label {
                                    Layout.fillWidth: true
                                    text: root.accountName()
                                    color: textColor
                                    elide: Text.ElideRight
                                    font.family: "monospace"
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: root.accountStatus()
                                    color: root.spotix.authenticated ? accent : warn
                                    elide: Text.ElideRight
                                    font.family: "monospace"
                                    font.pixelSize: 10
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 24
                                color: accountSettingsMouse.containsMouse ? panelAlt : "transparent"
                                border.color: accountSettingsMouse.containsMouse ? accent : borderColor
                                border.width: 1

                                Label {
                                    anchors.centerIn: parent
                                    text: "[*]"
                                    color: accountSettingsMouse.containsMouse ? accent : dimText
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                MouseArea {
                                    id: accountSettingsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        root.spotix.navigateToRoute("login")
                                        root.activePane = "detail"
                                        root.refocusKeyboard()
                                    }
                                }
                            }
                        }
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        text: root.spotix.search_query
                        placeholderText: "press / to search"
                        color: textColor
                        placeholderTextColor: dimText
                        selectionColor: selection
                        selectedTextColor: textColor
                        font.family: "monospace"
                        font.pixelSize: 15
                        background: Rectangle {
                            color: panelAlt
                            border.color: searchField.activeFocus ? accent : borderColor
                        }
                        onTextChanged: root.spotix.search_query = text
                        onAccepted: {
                            root.spotix.navigateToRoute("search")
                            root.spotix.submitSearch()
                            root.refocusKeyboard()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 92
                        Layout.fillHeight: true
                        Layout.topMargin: 5
                        Layout.bottomMargin: 5
                        color: searchMouse.containsMouse ? controlHover : controlBg
                        border.color: searchMouse.containsMouse ? accent : kdeBlue
                        border.width: 1

                        Label {
                            anchors.centerIn: parent
                            text: "search"
                            color: searchMouse.containsMouse ? accent : textColor
                            font.family: "monospace"
                            font.pixelSize: 13
                            font.bold: true
                        }

                        MouseArea {
                            id: searchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.spotix.navigateToRoute("search")
                                root.spotix.submitSearch()
                                root.refocusKeyboard()
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Rectangle {
                    Layout.preferredWidth: root.libraryPaneWidth
                    Layout.minimumWidth: 220
                    Layout.maximumWidth: 520
                    Layout.fillHeight: true
                    color: panelBg
                    border.color: root.activePane === "tree" ? accent : borderColor
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: root.spotix.active_route_art_ascii.length > 0 ? 1 : 6

                        Label {
                            Layout.fillWidth: true
                            text: "Library"
                            color: cyan
                            font.family: "monospace"
                            font.pixelSize: 13
                            font.bold: true
                        }

                        ListView {
                            id: treeList
                            property var appRoot: root
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            currentIndex: 0
                            model: root.visibleTreeItems(root.spotix.nav_tree_json, root.treeRevision)
                            boundsBehavior: Flickable.StopAtBounds
                            onCountChanged: Qt.callLater(root.restoreTreeSelection)
                            onModelChanged: Qt.callLater(root.restoreTreeSelection)

                            delegate: Rectangle {
                                id: treeDelegate
                                property var view: ListView.view
                                property var appRoot: view.appRoot
                                width: view.width
                                height: rowHeight
                                color: ListView.isCurrentItem && appRoot.activePane === "tree" ? selection : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    spacing: 8

                                    Label {
                                        Layout.preferredWidth: 42
                                        Layout.preferredHeight: parent.height
                                        visible: !treeDelegate.appRoot.hasTreeChildren(modelData.id) && treeDelegate.appRoot.shouldShowCoverAscii(modelData)
                                        text: treeDelegate.appRoot.coverAscii(modelData)
                                        textFormat: Text.RichText
                                        color: kdeViolet
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: "monospace"
                                        font.pixelSize: 6
                                        font.bold: true
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: treeDelegate.appRoot.treePrefix(modelData) + modelData.label
                                        color: ListView.isCurrentItem ? accent : textColor
                                        elide: Text.ElideRight
                                        font.family: "monospace"
                                        font.pixelSize: 14
                                    }

                                    Label {
                                        text: modelData.meta
                                        color: dimText
                                        elide: Text.ElideRight
                                        font.family: "monospace"
                                        font.pixelSize: 12
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        treeDelegate.appRoot.activePane = "tree"
                                        treeDelegate.view.currentIndex = index
                                        treeDelegate.appRoot.selectedTreeId = modelData.id
                                        treeDelegate.appRoot.activateTreeItem(modelData)
                                        treeDelegate.appRoot.refocusKeyboard()
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.fillHeight: true
                    color: splitLeftMouse.containsMouse || splitLeftMouse.pressed ? selection : borderColor

                    MouseArea {
                        id: splitLeftMouse
                        property real startX: 0
                        property int startWidth: 0
                        anchors.fill: parent
                        cursorShape: Qt.SplitHCursor
                        hoverEnabled: true
                        onPressed: function(mouse) {
                            startX = mouse.x
                            startWidth = root.libraryPaneWidth
                        }
                        onPositionChanged: function(mouse) {
                            if (pressed) {
                                root.libraryPaneWidth = root.clamp(startWidth + mouse.x - startX, 220, Math.min(520, root.width - 520))
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: panelBg
                    border.color: root.activePane === "detail" ? accent : borderColor
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 82
                            spacing: 8

                            Label {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: root.spotix.active_route_title
                                color: accent
                                font.family: "monospace"
                                font.pixelSize: 18
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Label {
                                Layout.preferredWidth: 165
                                Layout.preferredHeight: 82
                                clip: true
                                text: root.spotix.active_route_art_ascii.length > 0 ? root.spotix.active_route_art_ascii : (root.spotix.authenticated ? "ONLINE" : "LOGIN")
                                textFormat: root.spotix.active_route_art_ascii.length > 0 ? Text.RichText : Text.PlainText
                                color: root.spotix.authenticated ? accent : warn
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.family: "monospace"
                                font.pixelSize: root.spotix.active_route_art_ascii.length > 0 ? 7 : 13
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.maximumHeight: 32
                            text: root.spotix.detail_status
                            color: dimText
                            wrapMode: Text.WordWrap
                            font.family: "monospace"
                            font.pixelSize: 13
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.isAccountRoute() ? 58 : 0
                            visible: root.isAccountRoute()
                            color: panelAlt
                            border.color: borderColor
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 10

                                Label {
                                    text: "Web API client ID"
                                    color: kdeBlue
                                    font.family: "monospace"
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                TextField {
                                    id: accountKeyField
                                    Layout.fillWidth: true
                                    text: root.spotix.account_key
                                    placeholderText: "paste Spotify client ID; leave blank to use default"
                                    color: textColor
                                    placeholderTextColor: dimText
                                    selectionColor: selection
                                    selectedTextColor: textColor
                                    font.family: "monospace"
                                    font.pixelSize: 13
                                    background: Rectangle {
                                        color: panelBg
                                        border.color: accountKeyField.activeFocus ? accent : borderColor
                                    }
                                    onAccepted: {
                                        root.spotix.saveAccountKey(text)
                                        root.refocusKeyboard()
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 84
                                    Layout.fillHeight: true
                                    color: saveKeyMouse.containsMouse ? controlHover : controlBg
                                    border.color: saveKeyMouse.containsMouse ? accent : kdeBlue
                                    border.width: 1

                                    Label {
                                        anchors.centerIn: parent
                                        text: "save"
                                        color: saveKeyMouse.containsMouse ? accent : textColor
                                        font.family: "monospace"
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: saveKeyMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            root.spotix.saveAccountKey(accountKeyField.text)
                                            root.refocusKeyboard()
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: borderColor
                        }

                        ListView {
                            id: detailList
                            property var appRoot: root
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            currentIndex: 0
                            model: root.parseArray(root.spotix.detail_rows_json)
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                id: detailDelegate
                                property var view: ListView.view
                                property var appRoot: view.appRoot
                                width: view.width
                                height: rowHeight
                                color: ListView.isCurrentItem && appRoot.activePane === "detail" ? selection : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 2
                                    anchors.rightMargin: 6
                                    spacing: 2

                                    Label {
                                        Layout.preferredWidth: 10
                                        text: detailDelegate.appRoot.isNowPlayingRow(modelData) ? detailDelegate.appRoot.playingGlyph() : ""
                                        color: accent
                                        horizontalAlignment: Text.AlignHCenter
                                        font.family: "monospace"
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    Label {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: parent.height
                                        visible: detailDelegate.appRoot.shouldShowCoverAscii(modelData)
                                        text: detailDelegate.appRoot.coverAscii(modelData)
                                        textFormat: Text.RichText
                                        horizontalAlignment: Text.AlignLeft
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: "monospace"
                                        font.pixelSize: 6
                                        font.bold: true
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        color: detailDelegate.appRoot.isNowPlayingRow(modelData) || ListView.isCurrentItem ? accent : textColor
                                        elide: Text.ElideRight
                                        font.family: "monospace"
                                        font.pixelSize: 14
                                    }

                                    Label {
                                        Layout.preferredWidth: 260
                                        text: modelData.meta
                                        color: dimText
                                        elide: Text.ElideRight
                                        font.family: "monospace"
                                        font.pixelSize: 12
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        detailDelegate.appRoot.activePane = "detail"
                                        detailDelegate.view.currentIndex = index
                                        if (modelData.playable || modelData.kind === "action" || modelData.kind === "album" || modelData.kind === "artist" || modelData.kind === "playlist" || modelData.kind === "show") {
                                            detailDelegate.appRoot.spotix.activateDetailRow(modelData.id)
                                        }
                                        detailDelegate.appRoot.refocusKeyboard()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                color: splitFooterMouse.containsMouse || splitFooterMouse.pressed ? selection : borderColor

                MouseArea {
                    id: splitFooterMouse
                    property real startY: 0
                    property int startHeight: 0
                    anchors.fill: parent
                    cursorShape: Qt.SplitVCursor
                    hoverEnabled: true
                    onPressed: function(mouse) {
                        startY = mouse.y
                        startHeight = root.footerPaneHeight
                    }
                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            root.footerPaneHeight = root.clamp(startHeight - (mouse.y - startY), 150, Math.min(300, root.height - 260))
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.footerPaneHeight
                Layout.minimumHeight: 150
                Layout.maximumHeight: 300
                color: panelBg
                border.color: kdeBlue
                border.width: 1

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: kdeBlue }
                        GradientStop { position: 0.55; color: accent }
                        GradientStop { position: 1.0; color: kdeViolet }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    anchors.rightMargin: artBox.width + 14
                    spacing: root.footerSpacing()

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.footerControlHeight()
                            color: panelAlt
                            border.color: borderColor
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                Label {
                                    text: "Now Playing"
                                    color: kdeBlue
                                    font.family: "monospace"
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true

                                    Label {
                                        id: nowPlayingLabel
                                        y: Math.round((parent.height - height) / 2)
                                        x: nowPlayingLabel.width > parent.width ? -nowPlayingScroll.offset : 0
                                        text: root.nowPlayingText()
                                        color: textColor
                                        font.family: "monospace"
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    Timer {
                                        id: nowPlayingScroll
                                        property real offset: 0
                                        interval: 80
                                        running: nowPlayingLabel.width > parent.width
                                        repeat: true
                                        onTriggered: {
                                            var overflow = nowPlayingLabel.width - parent.width
                                            offset = overflow <= 0 ? 0 : (offset + 1) % (overflow + 48)
                                        }
                                        onRunningChanged: {
                                            if (!running) {
                                                offset = 0
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 22
                                    color: savedMouse.containsMouse ? controlHover : controlBg
                                    border.color: root.spotix.now_playing_saved ? accent : dimText
                                    border.width: 1
                                    opacity: root.spotix.saved_track_id.length > 0 ? 1.0 : 0.45

                                    Label {
                                        anchors.centerIn: parent
                                        text: root.spotix.now_playing_saved_busy ? "[..]" : (root.spotix.now_playing_saved ? "[x]" : "[ ]")
                                        color: root.spotix.now_playing_saved ? accent : textColor
                                        font.family: "monospace"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: savedMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: root.spotix.saved_track_id.length > 0 && !root.spotix.now_playing_saved_busy
                                        onClicked: {
                                            root.spotix.toggleNowPlayingSaved()
                                            root.refocusKeyboard()
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: [
                                { label: "prev", command: "previous" },
                                { label: root.spotix.playback_state === "Playing" ? "||" : ">", command: "toggle" },
                                { label: "next", command: "next" },
                                { label: root.spotix.shuffle_enabled ? "shuffle*" : "shuffle", command: "shuffle" }
                            ]

                            delegate: Rectangle {
                                Layout.preferredWidth: 82
                                Layout.preferredHeight: root.footerControlHeight()
                                color: controlMouse.containsMouse ? controlHover : controlBg
                                border.color: controlMouse.containsMouse ? accent : kdeBlue
                                border.width: 1

                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: modelData.command === "toggle" ? error : (controlMouse.containsMouse ? accent : textColor)
                                    font.family: "monospace"
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                MouseArea {
                                    id: controlMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (modelData.command === "previous") {
                                            root.spotix.playPrevious()
                                        } else if (modelData.command === "toggle") {
                                            root.spotix.playPause()
                                        } else if (modelData.command === "next") {
                                            root.spotix.playNext()
                                        } else if (modelData.command === "shuffle") {
                                            root.spotix.toggleShuffle()
                                        }
                                        root.refocusKeyboard()
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Label {
                            text: root.cargoStatusWord()
                            color: root.spotix.playback_state === "Blocked" ? warn : accent
                            font.family: "monospace"
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Label {
                            Layout.fillWidth: true
                            text: root.terminalBar(root.progressRatio(), Math.max(12, Math.floor(width / 8) - 6), ">") + " " + Math.floor(root.progressRatio() * 100) + "%"
                            color: kdeBlue
                            clip: true
                            horizontalAlignment: Text.AlignLeft
                            font.family: "monospace"
                            font.pixelSize: 13
                            font.bold: true

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.spotix.seekPlayback(root.barClickRatio(mouse.x, width))
                            }
                        }

                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Label {
                            text: root.formatTime(root.spotix.playback_progress_ms) + " / " + root.formatTime(root.spotix.playback_duration_ms)
                            color: dimText
                            font.family: "monospace"
                            font.pixelSize: 12
                        }

                        Label {
                            text: "Volume"
                            color: cyan
                            font.family: "monospace"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Label {
                            Layout.preferredWidth: 180
                            text: root.terminalBar(root.spotix.volume, Math.max(8, Math.floor(width / 8) - 1), "|")
                            color: cyan
                            clip: true
                            horizontalAlignment: Text.AlignLeft
                            font.family: "monospace"
                            font.pixelSize: 12
                            font.bold: true

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.spotix.setPlaybackVolume(root.barClickRatio(mouse.x, width))
                            }
                        }

                        Label {
                            Layout.preferredWidth: 28
                            text: root.volumePercent() + "%"
                            color: cyan
                            horizontalAlignment: Text.AlignLeft
                            font.family: "monospace"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24

                            Row {
                                anchors.centerIn: parent
                                spacing: 3

                                Repeater {
                                    model: 16

                                    delegate: Label {
                                        width: 7
                                        text: root.eqColumn(index)
                                        color: kdeViolet
                                        horizontalAlignment: Text.AlignHCenter
                                        lineHeight: 0.82
                                        font.family: "monospace"
                                        font.pixelSize: 7
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Label {
                            Layout.fillWidth: true
                            text: root.spotix.playback_status + " | " + root.spotix.queue_summary
                            color: root.spotix.playback_state === "Blocked" ? warn : dimText
                            elide: Text.ElideRight
                            font.family: "monospace"
                            font.pixelSize: 12
                        }

                        Label {
                            text: "keys: space play/pause | click bar seek | click vol set"
                            color: dimText
                            elide: Text.ElideRight
                            font.family: "monospace"
                            font.pixelSize: 12
                        }
                    }
                }

                Rectangle {
                    id: artBox
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    width: 250
                    height: parent.height - 12
                    color: panelAlt
                    border.color: borderColor
                    border.width: 1

                    Label {
                        id: artText
                        anchors.fill: parent
                        anchors.margins: 6
                        text: root.spotix.now_playing_art_ascii
                        textFormat: Text.RichText
                        color: accent
                        font.family: "monospace"
                        font.pixelSize: 8
                        lineHeight: 0.95
                        elide: Text.ElideNone
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        clip: true
                    }
                }
            }
        }
    }
}
