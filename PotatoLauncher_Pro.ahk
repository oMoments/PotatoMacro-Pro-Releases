#Requires AutoHotkey v2.0
#SingleInstance Force

MACRO_SCRIPT := A_ScriptDir "\PotatoMacro_Pro.ahk"
CFG          := A_ScriptDir "\PotatoConfig_Pro.ini"
activeMacros := Map()
fld          := Map()

BASE_URL  := "https://raw.githubusercontent.com/oMoments/PotatoMacro-Pro-Releases/master/"
USERS_URL := "https://gist.githubusercontent.com/oMoments/3ba25917ed7c4e2a33d19074e28c0c19/raw/users.txt"
AUTH_FILE := A_ScriptDir "\auth.dat"

; =============================================
;   LOGIN
; =============================================
CheckLogin() {
    if FileExist(AUTH_FILE) {
        saved := ""
        loop read AUTH_FILE
            saved := A_LoopReadLine
        if ValidateCredentials(saved)
            return
        FileDelete AUTH_FILE
    }
    ShowLoginDialog()
}

ShowLoginDialog() {
    loginGui := Gui("+AlwaysOnTop -Resize", "Potato Macro Pro — Login")
    loginGui.SetFont("s10", "Segoe UI")
    loginGui.Add("Text", "x15 y15 w200", "Username:")
    userEdit := loginGui.Add("Edit", "x15 y33 w200 -Theme")
    loginGui.Add("Text", "x15 y63 w200", "Password:")
    passEdit := loginGui.Add("Edit", "x15 y81 w200 -Theme Password")
    errText  := loginGui.Add("Text", "x15 y111 w200 cRed", "")
    btnLogin := loginGui.Add("Button", "x15 y130 w200", "Login")

    btnLogin.OnEvent("Click", TryLogin)
    loginGui.OnEvent("Close", (*) => ExitApp())

    TryLogin(*) {
        u := Trim(userEdit.Value)
        p := Trim(passEdit.Value)
        if !u || !p {
            errText.Value := "Enter username and password."
            return
        }
        errText.Value := "Checking..."
        if ValidateCredentials(u ":" p) {
            FileDelete AUTH_FILE
            FileAppend u ":" p, AUTH_FILE
            loginGui.Destroy()
        } else {
            errText.Value := "Invalid username or password."
        }
    }

    loginGui.Show("w230 h165")
    WinWaitClose "ahk_id " loginGui.Hwnd
}

ValidateCredentials(entry) {
    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", USERS_URL, false)
        http.Send()
        loop parse, http.ResponseText, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line = "" || SubStr(line, 1, 1) = "#")
                continue
            if (line = entry)
                return true
        }
    }
    return false
}

CheckLogin()

; =============================================
;   UPDATE
; =============================================
DoUpdate(*) {
    ToolTip "Downloading update..."
    try {
        Download BASE_URL "PotatoMacro_Pro.ahk",   A_ScriptDir "\PotatoMacro_Pro.ahk"
        Download BASE_URL "version.txt",            A_ScriptDir "\version.txt"
        Download BASE_URL "PotatoLauncher_Pro.ahk", A_ScriptDir "\PotatoLauncher_Pro_new.ahk"
    } catch {
        ToolTip
        MsgBox "Update failed. Check your internet connection.", "Update Error", 0x10
        return
    }
    ToolTip
    bat := A_ScriptDir "\apply_update.bat"
    try FileDelete bat
    FileAppend '@echo off`r`ntimeout /t 1 /nobreak >nul`r`nmove /y "' A_ScriptDir '\PotatoLauncher_Pro_new.ahk" "' A_ScriptDir '\PotatoLauncher_Pro.ahk"`r`nstart "" "' A_AhkPath '" "' A_ScriptDir '\PotatoLauncher_Pro.ahk"`r`ndel "%~f0"', bat
    Run bat
    ExitApp
}

CheckForUpdate() {
    global btnUpdate
    try {
        localVersion := ""
        loop read A_ScriptDir "\version.txt"
            localVersion := Trim(A_LoopReadLine)
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", BASE_URL "version.txt", false)
        http.Send()
        latestVersion := Trim(http.ResponseText)
        if (latestVersion != "" && latestVersion != localVersion)
            btnUpdate.Visible := true
    }
}
SetTimer CheckForUpdate, -1500

; =============================================
;   COORD PICKER HELPERS
; =============================================
PickCoord(keyX, keyY, *) {
    global mainGui, fld
    mainGui.Hide()
    Sleep 200
    KeyWait "LButton"
    Sleep 100
    ToolTip "Click the target position in Roblox..."
    KeyWait "LButton", "D"
    MouseGetPos &mx, &my
    KeyWait "LButton"
    ToolTip
    hwnds := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    for hwnd in hwnds {
        WinGetPos &wx, &wy, , , "ahk_id " hwnd
        fld[keyX].Value := mx - wx
        fld[keyY].Value := my - wy
        break
    }
    mainGui.Show("w520 h542")
    tabs.Focus()
}

PickSingleX(key, *) {
    global mainGui, fld
    mainGui.Hide()
    Sleep 200
    KeyWait "LButton"
    Sleep 100
    ToolTip "Click the target position in Roblox..."
    KeyWait "LButton", "D"
    MouseGetPos &mx, &my
    KeyWait "LButton"
    ToolTip
    hwnds := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    for hwnd in hwnds {
        WinGetPos &wx, &wy, , , "ahk_id " hwnd
        fld[key].Value := mx - wx
        break
    }
    mainGui.Show("w520 h542")
    tabs.Focus()
}

PickSingleY(key, tip := "", *) {
    global mainGui, fld
    mainGui.Hide()
    Sleep 200
    KeyWait "LButton"
    Sleep 100
    ToolTip tip != "" ? tip : "Click the target position in Roblox..."
    KeyWait "LButton", "D"
    MouseGetPos &mx, &my
    KeyWait "LButton"
    ToolTip
    hwnds := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    for hwnd in hwnds {
        WinGetPos &wx, &wy, , , "ahk_id " hwnd
        fld[key].Value := my - wy
        break
    }
    mainGui.Show("w520 h542")
    tabs.Focus()
}

MeasureRowH(*) {
    global mainGui, fld
    mainGui.Hide()
    Sleep 200
    KeyWait "LButton"
    Sleep 100
    ToolTip "Click the FIRST generator buy button..."
    KeyWait "LButton", "D"
    MouseGetPos , &y1
    KeyWait "LButton"
    Sleep 100
    ToolTip "Click the NEXT generator buy button..."
    KeyWait "LButton", "D"
    MouseGetPos , &y2
    KeyWait "LButton"
    ToolTip
    fld["GenRowH"].Value := Abs(y2 - y1)
    mainGui.Show("w520 h542")
    tabs.Focus()
}

; =============================================
;   GUI HELPERS
; =============================================
; Full coord row: numbered label + X + Y + pick button + optional description
CoordRow(label, y, keyX, keyY, desc := "") {
    global mainGui, fld
    mainGui.Add("Text", "x10 y" (y+3) " w175", label)
    mainGui.Add("Text", "x185 y" (y+3) " w18", "X:")
    fld[keyX] := mainGui.Add("Edit", "x203 y" y " w50 Number -Theme")
    mainGui.Add("Text", "x256 y" (y+3) " w18", "Y:")
    fld[keyY] := mainGui.Add("Edit", "x274 y" y " w50 Number -Theme")
    mainGui.Add("Button", "x327 y" (y-1) " w22 h21", "+")
        .OnEvent("Click", PickCoord.Bind(keyX, keyY))
    if desc != ""
        mainGui.Add("Text", "x354 y" (y+3) " w156 cGray", desc)
}

; X-only row
CoordRowX(label, y, key, desc := "") {
    global mainGui, fld
    mainGui.Add("Text", "x10 y" (y+3) " w175", label)
    mainGui.Add("Text", "x185 y" (y+3) " w18", "X:")
    fld[key] := mainGui.Add("Edit", "x203 y" y " w50 Number -Theme")
    mainGui.Add("Button", "x256 y" (y-1) " w22 h21", "+")
        .OnEvent("Click", PickSingleX.Bind(key))
    if desc != ""
        mainGui.Add("Text", "x283 y" (y+3) " w227 cGray", desc)
}

; Y-only row
CoordRowY(label, y, key, desc := "", pickTip := "") {
    global mainGui, fld
    mainGui.Add("Text", "x10 y" (y+3) " w175", label)
    mainGui.Add("Text", "x185 y" (y+3) " w18", "Y:")
    fld[key] := mainGui.Add("Edit", "x203 y" y " w50 Number -Theme")
    mainGui.Add("Button", "x256 y" (y-1) " w22 h21", "+")
        .OnEvent("Click", PickSingleY.Bind(key, pickTip))
    if desc != ""
        mainGui.Add("Text", "x283 y" (y+3) " w227 cGray", desc)
}

; Value-only row (no coord picker)
CoordRowVal(label, y, key) {
    global mainGui, fld
    mainGui.Add("Text", "x10 y" (y+3) " w175", label)
    fld[key] := mainGui.Add("Edit", "x203 y" y " w50 Number -Theme")
}

SectionHeader(label, y) {
    global mainGui
    mainGui.Add("Text", "x10 y" y " w500 cGray", label)
}

; Keybind row
KeybindRow(label, y, key) {
    global mainGui, fld
    mainGui.Add("Text", "x10 y" (y+3) " w175", label)
    fld["KB_" key] := mainGui.Add("Text", "x203 y" (y+3) " w80 cBlue", "")
    mainGui.Add("Button", "x290 y" (y-1) " w60 h21", "Set")
        .OnEvent("Click", RecordKey.Bind(key))
}

RecordKey(key, *) {
    global fld, CFG
    fld["KB_" key].Value := "Press a key..."
    ih := InputHook()
    ih.KeyOpt("{All}", "ES")
    ih.Start()
    ih.Wait()
    k := ih.EndKey
    IniWrite k, CFG, "Hotkeys", key
    fld["KB_" key].Value := k
    ApplyHotkeys()
}

; =============================================
;   GUI
; =============================================
mainGui := Gui("-Resize -MaximizeBox", "Potato Launcher Pro")
mainGui.SetFont("s9", "Segoe UI")

tabs := mainGui.Add("Tab3", "x0 y0 w520 h542", ["  Main  ", "  Settings  "])

; =============================================
;   TAB 1 — MAIN
; =============================================
tabs.UseTab(1)

mainGui.Add("Text", "x10 y33 w480", "Roblox Windows Detected:")
listBox := mainGui.Add("ListView", "x10 y50 w500 h140 -Multi", ["Window Title", "HWND", "Status"])
listBox.ModifyCol(1, 355)
listBox.ModifyCol(2, 0)
listBox.ModifyCol(3, 75)

mainGui.Add("Button", "x10 y200 w150", "Auto-Find").OnEvent("Click", AutoFind)
btnStart := mainGui.Add("Button", "x170 y200 w165", "Start  [F4]")
mainGui.Add("Button", "x345 y200 w165", "Stop All  [F5]").OnEvent("Click", StopAll)

btnUpdate := mainGui.Add("Button", "x10 y228 w500 h24 Hidden", "⬇ Update Available — Click to Update")
btnUpdate.SetFont("s9 cWhite", "Segoe UI")
btnUpdate.Opt("Background336699")
btnUpdate.OnEvent("Click", DoUpdate)

fld["AscEnabled"] := mainGui.Add("CheckBox", "x10 y260 w150", "Ascend")
fld["AscEnabled"].OnEvent("Click", UpdateAscendControls)
fld["AscPath"]  := mainGui.Add("Radio", "x25 y281 w180 Group", "Blessing of Abundance")
fld["AscPath2"] := mainGui.Add("Radio", "x25 y300 w180", "Blessing of Prestige")

; =============================================
;   TAB 2 — SETTINGS
; =============================================
tabs.UseTab(2)

; Resolution
mainGui.Add("Text", "x10 y36 w75", "Resolution:")
mainGui.Add("Text", "x88 y36 w20", "W:")
fld["ResW"] := mainGui.Add("Edit", "x108 y33 w55 Number -Theme")
mainGui.Add("Text", "x167 y36 w15", "×")
mainGui.Add("Text", "x185 y36 w20", "H:")
fld["ResH"] := mainGui.Add("Edit", "x205 y33 w55 Number -Theme")
mainGui.Add("Button", "x270 y33 w120", "Auto-detect").OnEvent("Click", AutoDetectRes)

mainGui.Add("Text", "x10 y60 w22 cGray", "the")
mainGui.Add("Text", "x30 y57 w22 h21 Border Center", "+")
mainGui.Add("Text", "x57 y60 w453 cGray", "acts as a coordinate finder — click it, then click the spot in Roblox")

; Sell
SectionHeader("Sell", 87)
CoordRow("• Golden Potatoes Tab",   104, "SellTabX", "SellTabY")
CoordRow("• Sell All Button",       126, "SellAllX", "SellAllY")

; Generators
SectionHeader("Generators", 151)
CoordRowX("• Buy Button (column X)", 168, "GenBtnX",  "any green buy button")
CoordRowY("• Y Top",                 190, "GenYTop",  "the highest buy button")
CoordRowY("• Y Bot",                 212, "GenYBot",  "the lowest buy button")
mainGui.Add("Text", "x10 y237 w175", "• Row Spacing:")
fld["GenRowH"] := mainGui.Add("Edit", "x203 y234 w50 Number -Theme")
mainGui.Add("Button", "x256 y233 w22 h21", "+").OnEvent("Click", MeasureRowH)
mainGui.Add("Text", "x283 y237 w227 cGray", "any buy button, then the one below it")

CoordRow("• Scroll Area",            256, "ScrollX", "ScrollY", "anywhere in the generator list")

; Prestige
SectionHeader("Prestige", 281)
CoordRow("• Prestige Now",           298, "PresNowX", "PresNowY")
CoordRow("• Prestige Confirm",       320, "PresConX", "PresConY")

; Ascend Coords
SectionHeader("Ascend Coords", 345)
CoordRow("• Blessing of Abundance",  362, "AscAbuX", "AscAbuY")
CoordRow("• Blessing of Prestige",   384, "AscPreX", "AscPreY")
CoordRow("• Ascend Confirm",         406, "AscConX", "AscConY")

; Keybinds
SectionHeader("Keybinds", 432)
KeybindRow("• Start",          449, "Start")
KeybindRow("• Stop All",       471, "Stop")
KeybindRow("• Bring to Front", 493, "Front")

mainGui.Add("Button", "x10 y518 w500", "Save Settings").OnEvent("Click", SaveSettings)

; =============================================
;   ASCEND CONTROLS
; =============================================
UpdateAscendControls(*) {
    global fld
    on := fld["AscEnabled"].Value
    fld["AscPath"].Enabled  := on
    fld["AscPath2"].Enabled := on
    if !on {
        fld["AscPath"].Value  := 0
        fld["AscPath2"].Value := 0
    }
}

; =============================================
;   POPULATE LIST
; =============================================
RefreshList(*) {
    listBox.Opt("-Redraw")
    listBox.Delete()
    hwnds := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    found := false
    for hwnd in hwnds {
        title  := WinGetTitle("ahk_id " hwnd)
        WinGetPos &wx, &wy, , , "ahk_id " hwnd
        if activeMacros.Has(hwnd) && !ProcessExist(Integer(activeMacros[hwnd]))
            activeMacros.Delete(hwnd)
        status := activeMacros.Has(hwnd) ? "RUNNING" : "idle"
        listBox.Add("", title, hwnd, status)
        found := true
    }
    if !found
        listBox.Add("", "No Roblox windows found", "", "")
    listBox.Opt("+Redraw")
}

AutoFind(*) {
    hwnds := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    for hwnd in hwnds {
        WinGetPos &wx, &wy, &ww, &wh, "ahk_id " hwnd
        fld["ResW"].Value := ww
        fld["ResH"].Value := wh
        break
    }
    RefreshList()
    ToolTip "Auto-find complete"
    SetTimer () => ToolTip(), -2000
}

AutoDetectRes(*) {
    hwnds := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    for hwnd in hwnds {
        WinGetPos , , &ww, &wh, "ahk_id " hwnd
        fld["ResW"].Value := ww
        fld["ResH"].Value := wh
        ToolTip "Resolution detected: " ww " × " wh
        SetTimer () => ToolTip(), -2000
        return
    }
    MsgBox "No Roblox window found."
}

; =============================================
;   SETTINGS — LOAD / SAVE
; =============================================
LoadSettings() {
    global fld, CFG
    fld["ResW"].Value      := IniRead(CFG, "Window",      "ResW",          0)
    fld["ResH"].Value      := IniRead(CFG, "Window",      "ResH",          0)
    fld["SellTabX"].Value  := IniRead(CFG, "Sell",        "GoldenTabX",    0)
    fld["SellTabY"].Value  := IniRead(CFG, "Sell",        "GoldenTabY",    0)
    fld["SellAllX"].Value  := IniRead(CFG, "Sell",        "SellAllX",      0)
    fld["SellAllY"].Value  := IniRead(CFG, "Sell",        "SellAllY",      0)
    fld["GenBtnX"].Value   := IniRead(CFG, "Generators",  "BtnX",          0)
    fld["GenYTop"].Value   := IniRead(CFG, "Generators",  "YTop",          0)
    fld["GenYBot"].Value   := IniRead(CFG, "Generators",  "YBot",          0)
    fld["GenRowH"].Value   := IniRead(CFG, "Generators",  "RowHeight",     0)
    fld["ScrollX"].Value   := IniRead(CFG, "Generators",  "ScrollX",       0)
    fld["ScrollY"].Value   := IniRead(CFG, "Generators",  "ScrollY",       0)
    fld["PresNowX"].Value  := IniRead(CFG, "Prestige",    "NowX",          0)
    fld["PresNowY"].Value  := IniRead(CFG, "Prestige",    "NowY",          0)
    fld["PresConX"].Value  := IniRead(CFG, "Prestige",    "ConfirmX",      0)
    fld["PresConY"].Value  := IniRead(CFG, "Prestige",    "ConfirmY",      0)
    fld["AscAbuX"].Value   := IniRead(CFG, "Ascend",      "BtnAbundanceX", 0)
    fld["AscAbuY"].Value   := IniRead(CFG, "Ascend",      "BtnAbundanceY", 0)
    fld["AscPreX"].Value   := IniRead(CFG, "Ascend",      "BtnPrestigeX",  0)
    fld["AscPreY"].Value   := IniRead(CFG, "Ascend",      "BtnPrestigeY",  0)
    fld["AscConX"].Value   := IniRead(CFG, "Ascend",      "ConfirmX",      0)
    fld["AscConY"].Value   := IniRead(CFG, "Ascend",      "ConfirmY",      0)
    ascPath := IniRead(CFG, "Ascend", "Path", 1)
    fld["AscEnabled"].Value := IniRead(CFG, "Ascend",     "Enabled",       0)
    fld["AscPath"].Value    := (ascPath = 1) ? 1 : 0
    fld["AscPath2"].Value   := (ascPath = 1) ? 0 : 1
    UpdateAscendControls()
    fld["KB_Start"].Value := IniRead(CFG, "Hotkeys", "Start", "F4")
    fld["KB_Stop"].Value  := IniRead(CFG, "Hotkeys", "Stop",  "F5")
    fld["KB_Front"].Value := IniRead(CFG, "Hotkeys", "Front", ".")
}

SaveSettings(*) {
    global fld, CFG
    IniWrite fld["ResW"].Value,       CFG, "Window",     "ResW"
    IniWrite fld["ResH"].Value,       CFG, "Window",     "ResH"
    IniWrite fld["SellTabX"].Value,   CFG, "Sell",       "GoldenTabX"
    IniWrite fld["SellTabY"].Value,   CFG, "Sell",       "GoldenTabY"
    IniWrite fld["SellAllX"].Value,   CFG, "Sell",       "SellAllX"
    IniWrite fld["SellAllY"].Value,   CFG, "Sell",       "SellAllY"
    IniWrite fld["GenBtnX"].Value,    CFG, "Generators", "BtnX"
    IniWrite fld["GenYTop"].Value,    CFG, "Generators", "YTop"
    IniWrite fld["GenYBot"].Value,    CFG, "Generators", "YBot"
    IniWrite fld["GenRowH"].Value,    CFG, "Generators", "RowHeight"
    IniWrite fld["ScrollX"].Value,    CFG, "Generators", "ScrollX"
    IniWrite fld["ScrollY"].Value,    CFG, "Generators", "ScrollY"
    IniWrite fld["PresNowX"].Value,   CFG, "Prestige",   "NowX"
    IniWrite fld["PresNowY"].Value,   CFG, "Prestige",   "NowY"
    IniWrite fld["PresConX"].Value,   CFG, "Prestige",   "ConfirmX"
    IniWrite fld["PresConY"].Value,   CFG, "Prestige",   "ConfirmY"
    IniWrite fld["AscEnabled"].Value, CFG, "Ascend",     "Enabled"
    IniWrite fld["AscPath"].Value ? 1 : 2, CFG, "Ascend", "Path"
    IniWrite fld["AscAbuX"].Value,    CFG, "Ascend",     "BtnAbundanceX"
    IniWrite fld["AscAbuY"].Value,    CFG, "Ascend",     "BtnAbundanceY"
    IniWrite fld["AscPreX"].Value,    CFG, "Ascend",     "BtnPrestigeX"
    IniWrite fld["AscPreY"].Value,    CFG, "Ascend",     "BtnPrestigeY"
    IniWrite fld["AscConX"].Value,    CFG, "Ascend",     "ConfirmX"
    IniWrite fld["AscConY"].Value,    CFG, "Ascend",     "ConfirmY"
    ToolTip "Settings saved!"
    SetTimer () => ToolTip(), -2000
}

; =============================================
;   START / STOP
; =============================================
StartSelected(*) {
    row := listBox.GetNext(0, "Focused")
    if !row
        row := 1
    hwnd := Integer(listBox.GetText(row, 2))
    if !hwnd
        return
    if activeMacros.Has(hwnd) {
        MsgBox "Already running on that window."
        return
    }
    WinGetPos &wx, &wy, , , "ahk_id " hwnd
    SaveSettings()
    Run A_AhkPath ' "' MACRO_SCRIPT '" ' hwnd ' ' wx ' ' wy, , , &pid
    activeMacros[hwnd] := pid
    RefreshList()
}

StopMacro(hwnd) {
    if activeMacros.Has(hwnd) {
        try ProcessClose(activeMacros[hwnd])
        activeMacros.Delete(hwnd)
    }
}

StopAll(*) {
    for hwnd, pid in activeMacros.Clone()
        StopMacro(hwnd)
    RefreshList()
}

; =============================================
;   WIRE UP
; =============================================
btnStart.OnEvent("Click", StartSelected)
SetTimer () => RefreshList(), 2000

BringToFront(*) {
    global mainGui
    mainGui.Show()
    WinActivate "ahk_id " mainGui.Hwnd
}

StopAllWithTip(*) {
    StopAll()
    ToolTip "All macros stopped"
    SetTimer () => ToolTip(), -2000
}

ApplyHotkeys() {
    global fld
    static activeKeys := []
    for k in activeKeys
        try Hotkey k, "Off"
    activeKeys := []
    pairs := Map("Start", StartSelected, "Stop", StopAllWithTip, "Front", BringToFront)
    for settingKey, fn in pairs {
        k := fld["KB_" settingKey].Value
        if (k = "" || k = "Press a key...")
            continue
        try {
            Hotkey k, fn
            activeKeys.Push(k)
        }
    }
}

LoadSettings()
ApplyHotkeys()
RefreshList()
mainGui.Show("w520 h542")
