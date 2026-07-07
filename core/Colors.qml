pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    property string activeMode: "dark"
    property string activeScheme: "vibrant"
    property var fixedPaletteOverride: null

    property bool colorsLoaded: false

    function refreshColorsFromFile() {
        try {
            var content = (typeof colorsFile.text === 'function') ? colorsFile.text() : colorsFile.text;
            if (!content || content.length === 0) {
                console.log("Colors: file content is empty");
                return;
            }
            var json = JSON.parse(content);
            if (json) {
                palettes = json;
                colorsLoaded = true;
                console.log("Colors: palettes loaded from cache");
            }
        } catch (e) {
            console.log("Colors: Error parsing colors.json:", e);
        }
    }

    property FileView colorsFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/quickshell/colors.json"
        watchChanges: true
        onFileChanged: colorsFile.reload()
        onLoaded: refreshColorsFromFile()
        onLoadFailed: {
            colorsLoaded = false;
        }
    }

    property Timer reloadTimer: Timer {
        interval: 2000
        running: !colorsLoaded
        repeat: true
        onTriggered: colorsFile.reload()
    }

    property var palettes: /*JSON_START*/ {
  "dark-fidelity": {
    "rootBg": "#181211",
    "bg": "#181211",
    "card": "#534342",
    "textMain": "#ede0de",
    "textSub": "#d8c2bf",
    "accentBlue": "#ffb3ac",
    "secondary": "#e7bdb8",
    "accentPurple": "#e1c38c",
    "softAccentBg": "#5d3f3c",
    "softAccentText": "#ffdad6",
    "outline": "#a08c8a",
    "outlineVariant": "#534342",
    "error": "#ffb4ab"
  },
  "dark-content": {
    "rootBg": "#1e0f0e",
    "bg": "#1e0f0e",
    "card": "#5b403d",
    "textMain": "#fadcd9",
    "textSub": "#e4beba",
    "accentBlue": "#ffb3ac",
    "secondary": "#ffb3ac",
    "accentPurple": "#ffb866",
    "softAccentBg": "#812723",
    "softAccentText": "#ffdad6",
    "outline": "#ab8985",
    "outlineVariant": "#5b403d",
    "error": "#ffb4ab"
  },
  "dark-expressive": {
    "rootBg": "#1e100e",
    "bg": "#1e100e",
    "card": "#5d3f3c",
    "textMain": "#f9dcd9",
    "textSub": "#e7bdb8",
    "accentBlue": "#feabf5",
    "secondary": "#f0b3e7",
    "accentPurple": "#ffb3ac",
    "softAccentBg": "#653661",
    "softAccentText": "#ffd7f6",
    "outline": "#ad8884",
    "outlineVariant": "#5d3f3c",
    "error": "#ffb4ab"
  },
  "dark-monochrome": {
    "rootBg": "#131313",
    "bg": "#131313",
    "card": "#474747",
    "textMain": "#e2e2e2",
    "textSub": "#c6c6c6",
    "accentBlue": "#ffffff",
    "secondary": "#c6c6c6",
    "accentPurple": "#e2e2e2",
    "softAccentBg": "#474747",
    "softAccentText": "#e2e2e2",
    "outline": "#919191",
    "outlineVariant": "#474747",
    "error": "#ffb4ab"
  },
  "dark-neutral": {
    "rootBg": "#181211",
    "bg": "#181211",
    "card": "#534342",
    "textMain": "#ede0de",
    "textSub": "#d8c2bf",
    "accentBlue": "#ffb3ac",
    "secondary": "#e7bdb8",
    "accentPurple": "#e1c38c",
    "softAccentBg": "#5d3f3c",
    "softAccentText": "#ffdad6",
    "outline": "#a08c8a",
    "outlineVariant": "#534342",
    "error": "#ffb4ab"
  },
  "dark-tonal-spot": {
    "rootBg": "#181211",
    "bg": "#181211",
    "card": "#534342",
    "textMain": "#ede0de",
    "textSub": "#d8c2bf",
    "accentBlue": "#ffb3ac",
    "secondary": "#e7bdb8",
    "accentPurple": "#e1c38c",
    "softAccentBg": "#5d3f3c",
    "softAccentText": "#ffdad6",
    "outline": "#a08c8a",
    "outlineVariant": "#534342",
    "error": "#ffb4ab"
  },
  "dark-rainbow": {
    "rootBg": "#131313",
    "bg": "#131313",
    "card": "#474747",
    "textMain": "#e2e2e2",
    "textSub": "#c6c6c6",
    "accentBlue": "#ffb3ac",
    "secondary": "#e7bdb8",
    "accentPurple": "#e1c38c",
    "softAccentBg": "#5d3f3c",
    "softAccentText": "#ffdad6",
    "outline": "#919191",
    "outlineVariant": "#474747",
    "error": "#ffb4ab"
  },
  "dark-vibrant": {
    "rootBg": "#1c0e0d",
    "bg": "#291414",
    "card": "#371b1b",
    "textMain": "#f3f2f2",
    "textSub": "#b6afaf",
    "accentBlue": "#eea2a1",
    "secondary": "#635cd6",
    "accentPurple": "#f5e385",
    "softAccentBg": "#16106f",
    "softAccentText": "#e2e2e9",
    "outline": "#756161",
    "outlineVariant": "#756161",
    "error": "#fd4663"
  },
  "dark-faithful": {
    "rootBg": "#1c0e0d",
    "bg": "#291414",
    "card": "#371b1b",
    "textMain": "#f3f2f2",
    "textSub": "#b6afaf",
    "accentBlue": "#eea2a1",
    "secondary": "#635cd6",
    "accentPurple": "#f5e385",
    "softAccentBg": "#16106f",
    "softAccentText": "#e2e2e9",
    "outline": "#756161",
    "outlineVariant": "#756161",
    "error": "#fd4663"
  },
  "dark-dysfunctional": {
    "rootBg": "#1c190d",
    "bg": "#292614",
    "card": "#37331b",
    "textMain": "#f3f3f2",
    "textSub": "#b6b5af",
    "accentBlue": "#f0dd7c",
    "secondary": "#c9f07c",
    "accentPurple": "#8ff07c",
    "softAccentBg": "#79b405",
    "softAccentText": "#ecfad1",
    "outline": "#726f5d",
    "outlineVariant": "#726f5d",
    "error": "#fd4663"
  },
  "dark-muted": {
    "rootBg": "#161313",
    "bg": "#211c1c",
    "card": "#2c2626",
    "textMain": "#f3f2f2",
    "textSub": "#b5b0b0",
    "accentBlue": "#fdfdfd",
    "secondary": "#fdfdfd",
    "accentPurple": "#fdfdfd",
    "softAccentBg": "#a89f9f",
    "softAccentText": "#e7e4e4",
    "outline": "#6f6666",
    "outlineVariant": "#706666",
    "error": "#fd4663"
  },
  "light-fidelity": {
    "rootBg": "#e4d7d6",
    "bg": "#fff8f7",
    "card": "#f5dddb",
    "textMain": "#201a19",
    "textSub": "#534342",
    "accentBlue": "#9c413c",
    "secondary": "#775653",
    "accentPurple": "#725b2e",
    "softAccentBg": "#ffdad6",
    "softAccentText": "#2c1513",
    "outline": "#857371",
    "outlineVariant": "#d8c2bf",
    "error": "#ba1a1a"
  },
  "light-content": {
    "rootBg": "#f1d3d0",
    "bg": "#fff8f7",
    "card": "#ffdad6",
    "textMain": "#271716",
    "textSub": "#5b403d",
    "accentBlue": "#bb181f",
    "secondary": "#a13e38",
    "accentPurple": "#875200",
    "softAccentBg": "#ffdad6",
    "softAccentText": "#410003",
    "outline": "#906f6c",
    "outlineVariant": "#e4beba",
    "error": "#ba1a1a"
  },
  "light-expressive": {
    "rootBg": "#f0d4d1",
    "bg": "#fff8f7",
    "card": "#ffdad6",
    "textMain": "#271816",
    "textSub": "#5d3f3c",
    "accentBlue": "#8a4486",
    "secondary": "#7f4d7a",
    "accentPurple": "#904a45",
    "softAccentBg": "#ffd7f6",
    "softAccentText": "#330833",
    "outline": "#926f6b",
    "outlineVariant": "#e7bdb8",
    "error": "#ba1a1a"
  },
  "light-monochrome": {
    "rootBg": "#f9f9f9",
    "bg": "#f9f9f9",
    "card": "#e2e2e2",
    "textMain": "#1b1b1b",
    "textSub": "#474747",
    "accentBlue": "#000000",
    "secondary": "#5e5e5e",
    "accentPurple": "#3b3b3b",
    "softAccentBg": "#e2e2e2",
    "softAccentText": "#1b1b1b",
    "outline": "#777777",
    "outlineVariant": "#c6c6c6",
    "error": "#ba1a1a"
  },
  "light-neutral": {
    "rootBg": "#e4d7d6",
    "bg": "#fff8f7",
    "card": "#f5dddb",
    "textMain": "#201a19",
    "textSub": "#534342",
    "accentBlue": "#9c413c",
    "secondary": "#775653",
    "accentPurple": "#725b2e",
    "softAccentBg": "#ffdad6",
    "softAccentText": "#2c1513",
    "outline": "#857371",
    "outlineVariant": "#d8c2bf",
    "error": "#ba1a1a"
  },
  "light-tonal-spot": {
    "rootBg": "#e4d7d6",
    "bg": "#fff8f7",
    "card": "#f5dddb",
    "textMain": "#201a19",
    "textSub": "#534342",
    "accentBlue": "#9c413c",
    "secondary": "#775653",
    "accentPurple": "#725b2e",
    "softAccentBg": "#ffdad6",
    "softAccentText": "#2c1513",
    "outline": "#857371",
    "outlineVariant": "#d8c2bf",
    "error": "#ba1a1a"
  },
  "light-rainbow": {
    "rootBg": "#dadada",
    "bg": "#f9f9f9",
    "card": "#e2e2e2",
    "textMain": "#1b1b1b",
    "textSub": "#474747",
    "accentBlue": "#9c413c",
    "secondary": "#775653",
    "accentPurple": "#725b2e",
    "softAccentBg": "#ffdad6",
    "softAccentText": "#2c1513",
    "outline": "#777777",
    "outlineVariant": "#c6c6c6",
    "error": "#ba1a1a"
  },
  "light-vibrant": {
    "rootBg": "#e4bfbe",
    "bg": "#f0dcdb",
    "card": "#deb1b0",
    "textMain": "#1b1818",
    "textSub": "#524a4a",
    "accentBlue": "#c32622",
    "secondary": "#1d1963",
    "accentPurple": "#a58d0e",
    "softAccentBg": "#736ec0",
    "softAccentText": "#07070a",
    "outline": "#aa7170",
    "outlineVariant": "#a27474",
    "error": "#fd4663"
  },
  "light-faithful": {
    "rootBg": "#e4bfbe",
    "bg": "#f0dcdb",
    "card": "#deb1b0",
    "textMain": "#1b1818",
    "textSub": "#524a4a",
    "accentBlue": "#c32622",
    "secondary": "#1d1963",
    "accentPurple": "#a58d0e",
    "softAccentBg": "#736ec0",
    "softAccentText": "#07070a",
    "outline": "#aa7170",
    "outlineVariant": "#a27474",
    "error": "#fd4663"
  },
  "light-dysfunctional": {
    "rootBg": "#f6eaad",
    "bg": "#faf3d1",
    "card": "#f3e59a",
    "textMain": "#1b1a18",
    "textSub": "#5e5c55",
    "accentBlue": "#ceb018",
    "secondary": "#81b715",
    "accentPurple": "#2aa012",
    "softAccentBg": "#cce599",
    "softAccentText": "#304508",
    "outline": "#988d4f",
    "outlineVariant": "#968d5d",
    "error": "#fd4663"
  },
  "light-muted": {
    "rootBg": "#d1d1d1",
    "bg": "#e6e6e6",
    "card": "#c7c7c7",
    "textMain": "#1a1919",
    "textSub": "#575252",
    "accentBlue": "#737373",
    "secondary": "#666666",
    "accentPurple": "#595959",
    "softAccentBg": "#c2bcbc",
    "softAccentText": "#282424",
    "outline": "#8e8181",
    "outlineVariant": "#8d8181",
    "error": "#fd4663"
  }
} /*JSON_END*/

    property var currentPalette: fixedPaletteOverride || palettes[activeMode + "-" + activeScheme] || palettes["dark-fidelity"] || {}

    function applyFixedPalette(rootBg, bg, card, textMain, textSub, accentBlue, accentPurple, softAccentBg, softAccentText, error, secondary, outline, outlineVariant) {
        fixedPaletteOverride = {
            "rootBg": rootBg,
            "bg": bg,
            "card": card,
            "textMain": textMain,
            "textSub": textSub,
            "accentBlue": accentBlue,
            "accentPurple": accentPurple,
            "softAccentBg": softAccentBg,
            "softAccentText": softAccentText,
            "error": error,
            "secondary": secondary,
            "outline": outline,
            "outlineVariant": outlineVariant
        }
    }

    function clearFixedPalette() {
        fixedPaletteOverride = null
    }

    property color rootBg: currentPalette.rootBg || "#121212"
    property color bg: currentPalette.bg || "#121212"
    property color card: currentPalette.card || "#121212"
    property color textMain: currentPalette.textMain || "#ffffff"
    property color textSub: currentPalette.textSub || "#e0e0e0"
    property color accentBlue: currentPalette.accentBlue || "#ffffff"
    property color accentPurple: currentPalette.accentPurple || "#ffffff"
    property color softAccentBg: currentPalette.softAccentBg || "#121212"
    property color softAccentText: currentPalette.softAccentText || "#ffffff"

    property color outline: currentPalette.outline || "#8c9199"
    property color outlineVariant: currentPalette.outlineVariant || "#42474e"
    property color secondary: currentPalette.secondary || "#bac8da"
    property color error: currentPalette.error || "#ff5555"

    // Legacy aliases for widget compatibility
    property color purple: accentPurple
    property color fg: textMain
    property color muted: textSub
    property color subtext: textSub
    property color blue: accentBlue
    property color red: error
    property color surface: bg

    Behavior on rootBg { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
    Behavior on bg { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
    Behavior on card { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
    Behavior on textMain { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
    Behavior on textSub { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
    Behavior on accentBlue { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
    Behavior on accentPurple { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
    Behavior on softAccentBg { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
    Behavior on softAccentText { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
    Behavior on error { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
    Behavior on secondary { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
    Behavior on outline { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
    Behavior on outlineVariant { ColorAnimation { duration: 400; easing.type: Easing.OutQuart } }
}
