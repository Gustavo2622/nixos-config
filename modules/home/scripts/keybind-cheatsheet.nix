# Lightweight keybind cheatsheet overlay — categorized multi-column grid.
# Complementary to qs-keybinds (Super+K): this is for quick-glance reference,
# not interactive search. Dismisses on Escape or click-outside.
{pkgs}:
pkgs.writeShellScriptBin "keybind-cheatsheet" ''
  #!/usr/bin/env bash
  set -euo pipefail

  BIND_NIX="/etc/nixos/modules/home/hyprland/binds.nix"

  # Parse binds.nix into JSON: extract section headers as categories and bind entries
  json=$(${pkgs.gawk}/bin/awk '
    BEGIN {
      cat = "General"
      first = 1
      printf "["
    }
    # Section headers: # ============= CATEGORY =============
    /^[[:space:]]*#[[:space:]]*=+[[:space:]]/ {
      match($0, /=+[[:space:]]+(.+)[[:space:]]+=+/, m)
      if (m[1] != "") {
        # Title-case: lowercase then capitalize first letter of each word
        cat = tolower(m[1])
        n_words = split(cat, words, " ")
        cat = ""
        for (w = 1; w <= n_words; w++) {
          if (w > 1) cat = cat " "
          cat = cat toupper(substr(words[w], 1, 1)) substr(words[w], 2)
        }
      }
      next
    }
    # Bind entries: quoted strings like "$modifier,key, Description, action, args"
    /^[[:space:]]*"/ {
      if (match($0, /"([^"]+)"/, arr)) {
        line = arr[1]
        n = split(line, p, ",")
        if (n >= 3) {
          mods = p[1]; key = p[2]; desc = p[3]
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", mods)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", desc)

          # Skip empty descriptions or mouse-only binds
          if (desc == "" || key ~ /mouse/) next

          # Format modifier for display
          gsub(/\$modifier/, "Super", mods)
          gsub(/SHIFT/, "Shift", mods)
          gsub(/CONTROL/, "Ctrl", mods)
          gsub(/CTRL/, "Ctrl", mods)
          gsub(/ALT/, "Alt", mods)
          gsub(/ +/, "+", mods)

          # Skip duplicate vi-style binds (keep arrow key versions)
          if (desc ~ /\(VI\)$/) next

          display = mods "+" key

          if (!first) printf ","
          first = 0
          # Escape quotes in desc
          gsub(/"/, "\\\"", desc)
          printf "{\"cat\":\"%s\",\"key\":\"%s\",\"desc\":\"%s\"}", cat, display, desc
        }
      }
    }
    END { printf "]" }
  ' "$BIND_NIX")

  tmpdir=$(${pkgs.coreutils}/bin/mktemp -d)
  qml="$tmpdir/cheatsheet.qml"
  jsonfile="$tmpdir/binds.json"

  echo "$json" > "$jsonfile"

  cat > "$qml" <<'QML'
import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Window {
  id: win
  visible: true
  width: Screen.width * 0.75
  height: Screen.height * 0.75
  x: (Screen.width - width) / 2
  y: (Screen.height - height) / 2
  title: "Keybind Cheatsheet"
  flags: Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint | Qt.WindowStaysOnTopHint
  color: "transparent"

  property var bindsData: []
  property var categories: []

  // Category colors
  function catColor(cat) {
    var colors = {
      "Workspace Overview": "#00BCD4",
      "Terminals": "#4CAF50",
      "Application Launchers": "#FF9800",
      "Screenshots": "#FF5722",
      "Window Management": "#FFC107",
      "Window Movement": "#E91E63",
      "Window Swapping": "#9C27B0",
      "Focus Movement": "#2196F3",
      "Workspace Switching": "#00BCD4",
      "Move Window To Workspace": "#8BC34A",
      "Workspace Navigation": "#795548",
      "Window Cycling": "#607D8B",
      "Media & Hardware Controls": "#9E9E9E"
    };
    return colors[cat] || "#757575";
  }

  function loadData() {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        try {
          var data = JSON.parse(xhr.responseText);
          win.bindsData = data;
          // Extract unique categories preserving order
          var seen = {};
          var cats = [];
          for (var i = 0; i < data.length; i++) {
            if (!seen[data[i].cat]) {
              seen[data[i].cat] = true;
              cats.push(data[i].cat);
            }
          }
          win.categories = cats;
          buildModel();
        } catch(e) {
          console.error("Parse error:", e);
        }
      }
    };
    xhr.open("GET", "file://JSON_PATH_PLACEHOLDER");
    xhr.send();
  }

  ListModel { id: catModel }

  function buildModel() {
    catModel.clear();
    for (var c = 0; c < categories.length; c++) {
      var cat = categories[c];
      var binds = [];
      for (var i = 0; i < bindsData.length; i++) {
        if (bindsData[i].cat === cat) {
          binds.push(bindsData[i]);
        }
      }
      catModel.append({"catName": cat, "bindsJson": JSON.stringify(binds)});
    }
  }

  Component.onCompleted: loadData()

  Shortcut {
    sequences: ["Escape", "Return", "Space"]
    context: Qt.ApplicationShortcut
    onActivated: Qt.quit()
  }

  // Click-outside-to-dismiss
  MouseArea {
    anchors.fill: parent
    onClicked: Qt.quit()

    Rectangle {
      id: frame
      anchors.fill: parent
      anchors.margins: 8
      radius: 16
      color: "#EE111111"
      border.width: 1
      border.color: "#33ffffff"

      MouseArea {
        anchors.fill: parent
        // Absorb clicks on the frame so they don't dismiss
      }

      Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 8

        // Title
        Text {
          text: "Keybind Cheatsheet"
          color: "#66ccff"
          font.pixelSize: 20
          font.bold: true
          anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
          text: "Press Escape, Enter, or Space to close  ·  Super+K for interactive search"
          color: "#66888888"
          font.pixelSize: 11
          anchors.horizontalCenter: parent.horizontalCenter
        }

        Item { width: 1; height: 4 }

        // Scrollable grid of categories
        Flickable {
          width: parent.width
          height: parent.height - 52
          contentHeight: gridFlow.height
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          Flow {
            id: gridFlow
            width: parent.width
            spacing: 12

            Repeater {
              model: catModel

              // Each category is a box
              Rectangle {
                width: {
                  // Responsive column width: aim for 3 columns
                  var cols = 3;
                  var gap = 12;
                  return (gridFlow.width - (cols - 1) * gap) / cols;
                }
                height: catHeader.height + catBinds.height + 20
                radius: 10
                color: "#22ffffff"
                border.width: 1
                border.color: Qt.rgba(
                  parseInt(catColor(model.catName).substr(1,2), 16) / 255,
                  parseInt(catColor(model.catName).substr(3,2), 16) / 255,
                  parseInt(catColor(model.catName).substr(5,2), 16) / 255,
                  0.3
                )

                Column {
                  anchors.fill: parent
                  anchors.margins: 10
                  spacing: 6

                  // Category header
                  Text {
                    id: catHeader
                    text: model.catName
                    color: catColor(model.catName)
                    font.pixelSize: 13
                    font.bold: true
                    width: parent.width
                  }

                  // Binds in this category
                  Column {
                    id: catBinds
                    width: parent.width
                    spacing: 3

                    Repeater {
                      model: {
                        try { return JSON.parse(bindsJson); }
                        catch(e) { return []; }
                      }

                      Row {
                        width: catBinds.width
                        spacing: 8

                        Text {
                          text: modelData.key
                          color: "#66ccff"
                          font.pixelSize: 12
                          font.family: "monospace"
                          font.bold: true
                          width: parent.width * 0.45
                          elide: Text.ElideRight
                        }

                        Text {
                          text: modelData.desc
                          color: "#cccccc"
                          font.pixelSize: 12
                          width: parent.width * 0.52
                          elide: Text.ElideRight
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
QML

  # Replace placeholder
  ${pkgs.gnused}/bin/sed -i "s|JSON_PATH_PLACEHOLDER|$jsonfile|g" "$qml"

  # QML runtime environment
  export QT_QPA_PLATFORM="wayland;xcb"
  export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
  export QT_PLUGIN_PATH="${pkgs.qt6.qtbase}/lib/qt-6/plugins:${pkgs.qt6.qtwayland}/lib/qt-6/plugins"
  export QML_IMPORT_PATH="${pkgs.qt6.qtbase}/lib/qt-6/qml:${pkgs.qt6.qtdeclarative}/lib/qt-6/qml:${pkgs.qt6.qt5compat}/lib/qt-6/qml"
  export QML2_IMPORT_PATH="$QML_IMPORT_PATH"
  export QML_XHR_ALLOW_FILE_READ="1"

  QML_BIN="${pkgs.qt6.qtdeclarative}/bin/qml"
  if ! [ -x "$QML_BIN" ]; then
    if [ -x "${pkgs.qt6.qtdeclarative}/bin/qml6" ]; then
      QML_BIN="${pkgs.qt6.qtdeclarative}/bin/qml6"
    elif command -v qml >/dev/null 2>&1; then
      QML_BIN=$(command -v qml)
    elif command -v qml6 >/dev/null 2>&1; then
      QML_BIN=$(command -v qml6)
    fi
  fi

  "$QML_BIN" "$qml" 2>/dev/null || true
''
