#Requires AutoHotkey v2.0
#SingleInstance Force

if A_IsCompiled {
    deployDir := A_AppData "\PotatoMacroPro"
    DirCreate deployDir
    FileInstall "PotatoMacro_Pro.ahk", deployDir "\PotatoMacro_Pro.ahk", 1
    FileInstall "OCR.ahk",             deployDir "\OCR.ahk",             1
    FileInstall "instructions.txt",    A_ScriptDir "\instructions.txt",  1
    MACRO_SCRIPT := deployDir "\PotatoMacro_Pro.ahk"
    CFG := deployDir "\PotatoConfig_Pro.ini"
    ; migrate old config from exe folder if AppData one doesn't exist yet
    if !FileExist(CFG) && FileExist(A_ScriptDir "\PotatoConfig_Pro.ini")
        FileCopy A_ScriptDir "\PotatoConfig_Pro.ini", CFG
} else {
    deployDir    := A_ScriptDir
    MACRO_SCRIPT := A_ScriptDir "\PotatoMacro_Pro.ahk"
    CFG          := A_ScriptDir "\PotatoConfig_Pro.ini"
}
activeMacros := Map()
fld          := Map()
shopPid      := 0

BASE_URL  := "https://raw.githubusercontent.com/oMoments/PotatoMacro-Pro-Releases/master/"
AUTH_URL  := "https://potato-auth.lukepj00.workers.dev"
AUTH_KEY  := "p8xK2mQv7rNjLdW4cTbYsZeHgAoUiFn3"
AUTH_FILE := A_ScriptDir "\auth.dat"

FetchAuthUrl() {
    global AUTH_URL, BASE_URL
    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", BASE_URL "auth_url.txt", false)
        http.SetTimeouts(5000, 5000, 5000, 5000)
        http.Send()
        url := Trim(http.ResponseText)
        if (url != "" && InStr(url, "https://"))
            AUTH_URL := url
    }
}
FetchAuthUrl()

; =============================================
;   AHK INTERPRETER LOOKUP (for compiled mode)
; =============================================
GetAhkExe() {
    if !A_IsCompiled
        return A_AhkPath
    candidates := [
        A_ProgramFiles "\AutoHotkey\v2\AutoHotkey64.exe",
        A_ProgramFiles "\AutoHotkey\v2\AutoHotkey32.exe",
        A_ProgramFiles "\AutoHotkey\AutoHotkey.exe",
        A_ProgramFiles "\AutoHotkey\AutoHotkeyU64.exe",
    ]
    for path in candidates
        if FileExist(path)
            return path
    try {
        ahkDir := RegRead("HKLM\SOFTWARE\AutoHotkey", "InstallDir")
        for name in ["v2\AutoHotkey64.exe", "v2\AutoHotkey32.exe", "AutoHotkey.exe"]
            if FileExist(ahkDir "\" name)
                return ahkDir "\" name
    }
    return ""
}

; =============================================
;   LOGIN
; =============================================
CheckLogin() {
    if FileExist(AUTH_FILE) {
        saved := ""
        loop read AUTH_FILE
            saved := A_LoopReadLine
        if ValidateCredentials(saved) = "ok"
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
        result := ValidateCredentials(u ":" p)
        if result = "ok" {
            try FileDelete AUTH_FILE
            FileAppend u ":" p, AUTH_FILE
            loginGui.Destroy()
        } else if result = "error" {
            errText.Value := "Connection failed. Check your internet."
        } else {
            errText.Value := "Invalid username or password."
        }
    }

    loginGui.Show("w230 h165")
    WinWaitClose "ahk_id " loginGui.Hwnd
}

ValidateCredentials(entry) {
    try {
        parts := StrSplit(entry, ":", , 2)
        if (parts.Length < 2)
            return "invalid"
        body := '{"u":"' parts[1] '","p":"' parts[2] '"}'
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("POST", AUTH_URL, false)
        http.SetTimeouts(8000, 8000, 8000, 8000)
        http.SetRequestHeader("Content-Type", "application/json")
        http.SetRequestHeader("X-App-Key", AUTH_KEY)
        http.Send(body)
        return InStr(http.ResponseText, '"ok":true') > 0 ? "ok" : "invalid"
    }
    return "error"
}

CheckLogin()

; =============================================
;   UPDATE
; =============================================
DoUpdate(*) {
    global btnUpdate
    btnUpdate.Visible := false
    ToolTip "Downloading update..."
    try {
        Download BASE_URL "version.txt", A_ScriptDir "\version.txt"
        if A_IsCompiled {
            Download BASE_URL "PotatoLauncher_Pro.exe", A_ScriptDir "\PotatoLauncher_Pro_new.exe"
        } else {
            Download BASE_URL "PotatoMacro_Pro.ahk",   A_ScriptDir "\PotatoMacro_Pro.ahk"
            Download BASE_URL "PotatoLauncher_Pro.ahk", A_ScriptDir "\PotatoLauncher_Pro_new.ahk"
        }
    } catch {
        ToolTip
        MsgBox "Update failed. Check your internet connection.", "Update Error", 0x10
        return
    }
    ToolTip
    try FileDelete A_ScriptDir "\.just_updated"
    FileAppend "1", A_ScriptDir "\.just_updated"
    bat := A_ScriptDir "\apply_update.bat"
    try FileDelete bat
    if A_IsCompiled {
        FileAppend '@echo off`r`ntimeout /t 1 /nobreak >nul`r`nmove /y "' A_ScriptDir '\PotatoLauncher_Pro_new.exe" "' A_ScriptDir '\PotatoLauncher_Pro.exe"`r`nstart "" "' A_ScriptDir '\PotatoLauncher_Pro.exe"`r`ndel "%~f0"', bat
    } else {
        FileAppend '@echo off`r`ntimeout /t 1 /nobreak >nul`r`nmove /y "' A_ScriptDir '\PotatoLauncher_Pro_new.ahk" "' A_ScriptDir '\PotatoLauncher_Pro.ahk"`r`nstart "" "' A_AhkPath '" "' A_ScriptDir '\PotatoLauncher_Pro.ahk"`r`ndel "%~f0"', bat
    }
    Run bat
    ExitApp
}

CheckForUpdate() {
    global btnUpdate
    if FileExist(A_ScriptDir "\.dev")
        return
    if FileExist(A_ScriptDir "\.just_updated") {
        FileDelete A_ScriptDir "\.just_updated"
        return
    }
    try {
        localVersion := ""
        if FileExist(A_ScriptDir "\version.txt") {
            loop read A_ScriptDir "\version.txt"
                localVersion := Trim(A_LoopReadLine)
        }
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
PickCoord(keyX, keyY, tip := "", *) {
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
        fld[keyX].Value := mx - wx
        fld[keyY].Value := my - wy
        break
    }
    mainGui.Show("w1100 h685")
    tabs.Focus()
}

PickSingleX(key, tip := "", *) {
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
        fld[key].Value := mx - wx
        break
    }
    mainGui.Show("w1100 h685")
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
    mainGui.Show("w1100 h685")
    tabs.Focus()
}

MeasureRowH(*) {
    MeasureRowHTo("GenRowH")
}

MeasureRowHTo(targetKey, *) {
    global mainGui, fld
    mainGui.Hide()
    Sleep 200
    KeyWait "LButton"
    Sleep 100
    ToolTip "Click the FIRST buy button..."
    KeyWait "LButton", "D"
    MouseGetPos , &y1
    KeyWait "LButton"
    Sleep 100
    ToolTip "Click the NEXT buy button..."
    KeyWait "LButton", "D"
    MouseGetPos , &y2
    KeyWait "LButton"
    ToolTip
    fld[targetKey].Value := Abs(y2 - y1)
    mainGui.Show("w1100 h685")
    tabs.Focus()
}


; =============================================
;   GUI HELPERS
; =============================================
CoordRow(label, y, keyX, keyY, desc := "", pickTip := "", xOff := 0) {
    global mainGui, fld
    mainGui.Add("Text", "x" (10+xOff) " y" (y+3) " w175", label)
    mainGui.Add("Text", "x" (185+xOff) " y" (y+3) " w18", "X:")
    fld[keyX] := mainGui.Add("Edit", "x" (203+xOff) " y" y " w50 Number -Theme")
    mainGui.Add("Text", "x" (256+xOff) " y" (y+3) " w18", "Y:")
    fld[keyY] := mainGui.Add("Edit", "x" (274+xOff) " y" y " w50 Number -Theme")
    mainGui.Add("Button", "x" (327+xOff) " y" (y-1) " w22 h21", "+")
        .OnEvent("Click", PickCoord.Bind(keyX, keyY, pickTip))
    if desc != ""
        mainGui.Add("Text", "x" (354+xOff) " y" (y+3) " w156 cGray", desc)
}

CoordRowX(label, y, key, desc := "", pickTip := "") {
    global mainGui, fld
    mainGui.Add("Text", "x10 y" (y+3) " w175", label)
    mainGui.Add("Text", "x185 y" (y+3) " w18", "X:")
    fld[key] := mainGui.Add("Edit", "x203 y" y " w50 Number -Theme")
    mainGui.Add("Button", "x256 y" (y-1) " w22 h21", "+")
        .OnEvent("Click", PickSingleX.Bind(key, pickTip))
    if desc != ""
        mainGui.Add("Text", "x283 y" (y+3) " w227 cGray", desc)
}

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

SectionHeader(label, y) {
    global mainGui
    mainGui.Add("Text", "x10 y" y " w500 cGray", label)
}

KeybindRow(label, y, key, xOff := 0) {
    global mainGui, fld
    mainGui.Add("Text", "x" (10+xOff) " y" (y+3) " w150", label)
    fld["KB_" key] := mainGui.Add("Text", "x" (175+xOff) " y" (y+3) " w100 cBlue", "")
    mainGui.Add("Button", "x" (285+xOff) " y" (y-1) " w60 h21", "Set")
        .OnEvent("Click", RecordKey.Bind(key))
}

CompactCoord(label, y, keyX, keyY, xOff, pickTip := "") {
    global mainGui, fld
    mainGui.Add("Text",   "x" xOff         " y" (y+3) " w42",                       label)
    mainGui.Add("Text",   "x" (xOff + 42)  " y" (y+3) " w12",                       "X:")
    fld[keyX] := mainGui.Add("Edit", "x" (xOff + 56)  " y" y     " w42 Number -Theme")
    mainGui.Add("Text",   "x" (xOff + 102) " y" (y+3) " w12",                       "Y:")
    fld[keyY] := mainGui.Add("Edit", "x" (xOff + 116) " y" y     " w42 Number -Theme")
    mainGui.Add("Button", "x" (xOff + 162) " y" (y-1) " w22 h21", "+")
        .OnEvent("Click", PickCoord.Bind(keyX, keyY, pickTip))
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
mainGui := Gui("+Resize", "Potato Launcher Pro")
OnMessage(0x0024, WM_GETMINMAXINFO)
WM_GETMINMAXINFO(wParam, lParam, msg, hwnd) {
    global mainGui
    if (hwnd != mainGui.Hwnd)
        return
    NumPut("Int", 1100, lParam, 24)
    NumPut("Int", 685,  lParam, 28)
}
mainGui.SetFont("s9", "Segoe UI")

tabs := mainGui.Add("Tab3", "x0 y0 w1100 h685", ["  Main  ", "  Settings  "])

; =============================================
;   TAB 1 — MAIN
; =============================================
tabs.UseTab(1)

mainGui.Add("Text", "x10 y33 w480", "Roblox Windows Detected:")
listBox := mainGui.Add("ListView", "x10 y50 w1080 h140 -Multi", ["Window Title", "ID", "Status"])
listBox.ModifyCol(1, 820)
listBox.ModifyCol(2, 120)
listBox.ModifyCol(3, 100)

mainGui.Add("Button", "x10 y200 w1080 h24", "Auto-Find").OnEvent("Click", AutoFind)

btnUpdate := mainGui.Add("Button", "x10 y230 w1080 h24 Hidden", "⬇ Update Available — Click to Update")
btnUpdate.SetFont("s9 cWhite", "Segoe UI")
btnUpdate.Opt("Background336699")
btnUpdate.OnEvent("Click", DoUpdate)

; --- 3 evenly-spaced toggle GroupBoxes ---
mainGui.Add("GroupBox", "x10 y260 w350 h90", "")
fld["AscEnabled"] := mainGui.Add("CheckBox", "x25 y282 w150", "Ascend")
fld["AscEnabled"].OnEvent("Click", UpdateAscendControls)
fld["AscPath"]  := mainGui.Add("Radio", "x40 y304 w200 Group", "Blessing of Abundance")
fld["AscPath2"] := mainGui.Add("Radio", "x40 y324 w200",       "Blessing of Prestige")

mainGui.Add("GroupBox", "x375 y260 w350 h90", "")
fld["InvEnabled"] := mainGui.Add("CheckBox", "x390 y282 w200", "Inventory Swap")
mainGui.Add("Text", "x390 y304 w330 cGray", "Equips your prestige potato right before each prestige, then swaps back to your bonus potato afterwards.")

mainGui.Add("GroupBox", "x740 y260 w350 h90", "")
fld["ShopAuto"] := mainGui.Add("CheckBox", "x755 y282 w200", "Auto Shop  (every 5 min)")
fld["ShopAuto"].OnEvent("Click", UpdateShopControls)
fld["SkipRocks"]    := mainGui.Add("Radio", "x770 y304 w200 Group", "Skip Rock / Useless Rock")
fld["SkipRocksOff"] := mainGui.Add("Radio", "x770 y324 w120",        "Buy All")

btnStartShop := mainGui.Add("Button", "x10  y358 w540 h24", "▶ Start Shop Loop")
btnStopShop  := mainGui.Add("Button", "x550 y358 w540 h24", "■ Stop Shop")
btnStart     := mainGui.Add("Button", "x10  y388 w540 h267", "Start  [F4]")
btnStopAll   := mainGui.Add("Button", "x550 y388 w540 h267", "Stop All  [F5]")
btnStopAll.OnEvent("Click", StopAllWithTip)

; =============================================
;   TAB 2 — SETTINGS
; =============================================
tabs.UseTab(2)

mainGui.Add("Text", "x10 y36 w75", "Resolution:")
mainGui.Add("Text", "x88 y36 w20", "W:")
fld["ResW"] := mainGui.Add("Edit", "x108 y33 w55 Number -Theme")
mainGui.Add("Text", "x167 y36 w15", "×")
mainGui.Add("Text", "x185 y36 w20", "H:")
fld["ResH"] := mainGui.Add("Edit", "x205 y33 w55 Number -Theme")
mainGui.Add("Button", "x270 y33 w120", "Auto-detect").OnEvent("Click", AutoDetectRes)

mainGui.Add("Text", "x10 y60 w22 cGray", "the")
mainGui.Add("Text", "x30 y57 w22 h21 Border Center", "+")
mainGui.Add("Text", "x57 y60 w900 cGray", "acts as a coordinate finder — click it, then click the spot in Roblox")

; ============= LEFT COLUMN =============
mainGui.Add("GroupBox", "x5 y85 w510 h78", " Sell ")
CoordRow("• Golden Potatoes Tab", 104, "SellTabX", "SellTabY", "", "Click the golden potatoes tab in the sell screen")
CoordRow("• Sell All Button",     126, "SellAllX", "SellAllY", "", "Click the sell all button")

mainGui.Add("GroupBox", "x5 y170 w510 h140", " Generators ")
CoordRowX("• Buy Button (column X)", 189, "GenBtnX",  "any green buy button", "Click any green buy button in the generators list")
CoordRowY("• Y Top",                 211, "GenYTop",  "the highest buy button", "Click the highest visible buy button")
CoordRowY("• Y Bot",                 233, "GenYBot",  "the lowest buy button",  "Click the lowest visible buy button")
mainGui.Add("Text", "x10 y258 w175", "• Row Spacing:")
fld["GenRowH"] := mainGui.Add("Edit", "x203 y255 w50 Number -Theme")
mainGui.Add("Button", "x256 y254 w22 h21", "+").OnEvent("Click", MeasureRowH)
mainGui.Add("Text", "x283 y258 w227 cGray", "any buy button, then the one below it")
CoordRow("• Scroll Area", 277, "ScrollX", "ScrollY", "anywhere in the generator list", "Click anywhere inside the generator scroll list")

mainGui.Add("GroupBox", "x5 y317 w510 h78", " Prestige ")
CoordRow("• Prestige Now",     336, "PresNowX", "PresNowY", "", "Click the Prestige Now button")
CoordRow("• Prestige Confirm", 358, "PresConX", "PresConY", "", "Click the confirm button on the prestige popup")

mainGui.Add("GroupBox", "x5 y402 w510 h128", " Ascend ")
CoordRow("• Blessing of Abundance", 428, "AscAbuX", "AscAbuY", "", "Click the Blessing of Abundance path button")
CoordRow("• Blessing of Prestige",  450, "AscPreX", "AscPreY", "", "Click the Blessing of Prestige path button")
CoordRow("• Ascend Confirm",        472, "AscConX", "AscConY", "", "Click the confirm button on the ascend popup")

; ============= RIGHT COLUMN =============
mainGui.Add("GroupBox", "x520 y85 w575 h100", " Keybinds ")
KeybindRow("• Start",          104, "Start", 515)
KeybindRow("• Stop All",       126, "Stop",  515)
KeybindRow("• Bring to Front", 148, "Front", 515)

mainGui.Add("GroupBox", "x520 y195 w575 h145", " Shop ")
mainGui.Add("Text", "x530 y214 w555 cGray", "Set the BUY button for each slot. Left col = Btn 1-4, right col = Btn 5-8.")

loop 4 {
    rowY := 234 + (A_Index - 1) * 22
    CompactCoord("Btn " A_Index,       rowY, "Shop2Btn" A_Index       "X", "Shop2Btn" A_Index       "Y", 525, "Click Buy Button " A_Index       " in the shop")
    CompactCoord("Btn " (A_Index + 4), rowY, "Shop2Btn" (A_Index + 4) "X", "Shop2Btn" (A_Index + 4) "Y", 795, "Click Buy Button " (A_Index + 4) " in the shop")
}

mainGui.Add("GroupBox", "x520 y350 w575 h150", " Inventory Swap ")
CoordRow("• Prestige Potato",  374, "InvPresX",   "InvPresY",   "", "Click the potato that buffs prestige points",    515)
CoordRow("• Equip (prestige)", 398, "InvPresEqX", "InvPresEqY", "", "Click the equip button for the prestige potato", 515)
CoordRow("• Bonus Potato",     422, "InvBonX",    "InvBonY",    "", "Click the potato that buffs potato gain",        515)
CoordRow("• Equip (bonus)",    446, "InvBonEqX",  "InvBonEqY",  "", "Click the equip button for the bonus potato",   515)

mainGui.Add("Button", "x10 y590 w1080 h28", "Save Settings").OnEvent("Click", SaveSettings)

; =============================================
;   SHOP / ASCEND CONTROLS
; =============================================
UpdateShopControls(*) {
    global fld
    on := fld["ShopAuto"].Value
    fld["SkipRocks"].Enabled    := on
    fld["SkipRocksOff"].Enabled := on
    if !on {
        fld["SkipRocks"].Value    := 0
        fld["SkipRocksOff"].Value := 0
    } else {
        fld["SkipRocks"].Value    := 1
        fld["SkipRocksOff"].Value := 0
    }
}

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
    fld["ResW"].Value      := IniRead(CFG, "Window",     "ResW",          0)
    fld["ResH"].Value      := IniRead(CFG, "Window",     "ResH",          0)
    fld["SellTabX"].Value  := IniRead(CFG, "Sell",       "GoldenTabX",    0)
    fld["SellTabY"].Value  := IniRead(CFG, "Sell",       "GoldenTabY",    0)
    fld["SellAllX"].Value  := IniRead(CFG, "Sell",       "SellAllX",      0)
    fld["SellAllY"].Value  := IniRead(CFG, "Sell",       "SellAllY",      0)
    fld["GenBtnX"].Value   := IniRead(CFG, "Generators", "BtnX",          0)
    fld["GenYTop"].Value   := IniRead(CFG, "Generators", "YTop",          0)
    fld["GenYBot"].Value   := IniRead(CFG, "Generators", "YBot",          0)
    fld["GenRowH"].Value   := IniRead(CFG, "Generators", "RowHeight",     0)
    fld["ScrollX"].Value   := IniRead(CFG, "Generators", "ScrollX",       0)
    fld["ScrollY"].Value   := IniRead(CFG, "Generators", "ScrollY",       0)
    fld["PresNowX"].Value  := IniRead(CFG, "Prestige",   "NowX",          0)
    fld["PresNowY"].Value  := IniRead(CFG, "Prestige",   "NowY",          0)
    fld["PresConX"].Value  := IniRead(CFG, "Prestige",   "ConfirmX",      0)
    fld["PresConY"].Value  := IniRead(CFG, "Prestige",   "ConfirmY",      0)
    fld["AscAbuX"].Value   := IniRead(CFG, "Ascend",     "BtnAbundanceX", 0)
    fld["AscAbuY"].Value   := IniRead(CFG, "Ascend",     "BtnAbundanceY", 0)
    fld["AscPreX"].Value   := IniRead(CFG, "Ascend",     "BtnPrestigeX",  0)
    fld["AscPreY"].Value   := IniRead(CFG, "Ascend",     "BtnPrestigeY",  0)
    fld["AscConX"].Value   := IniRead(CFG, "Ascend",     "ConfirmX",      0)
    fld["AscConY"].Value   := IniRead(CFG, "Ascend",     "ConfirmY",      0)
    ascPath := IniRead(CFG, "Ascend", "Path", 1)
    fld["AscEnabled"].Value := IniRead(CFG, "Ascend",    "Enabled",       0)
    fld["AscPath"].Value    := (ascPath = 1) ? 1 : 0
    fld["AscPath2"].Value   := (ascPath = 1) ? 0 : 1
    UpdateAscendControls()
    fld["InvEnabled"].Value  := IniRead(CFG, "Inventory", "Enabled",      0)
    fld["InvPresX"].Value    := IniRead(CFG, "Inventory", "PresPotatoX",  0)
    fld["InvPresY"].Value    := IniRead(CFG, "Inventory", "PresPotatoY",  0)
    fld["InvPresEqX"].Value  := IniRead(CFG, "Inventory", "PresEquipX",   0)
    fld["InvPresEqY"].Value  := IniRead(CFG, "Inventory", "PresEquipY",   0)
    fld["InvBonX"].Value     := IniRead(CFG, "Inventory", "BonPotatoX",   0)
    fld["InvBonY"].Value     := IniRead(CFG, "Inventory", "BonPotatoY",   0)
    fld["InvBonEqX"].Value   := IniRead(CFG, "Inventory", "BonEquipX",    0)
    fld["InvBonEqY"].Value   := IniRead(CFG, "Inventory", "BonEquipY",    0)
    fld["ShopAuto"].Value    := IniRead(CFG, "Shop",      "AutoEnabled",   0)
    skipRocksVal := Integer(IniRead(CFG, "Shop", "SkipRocks", 1))
    fld["SkipRocks"].Value    := (skipRocksVal = 1) ? 1 : 0
    fld["SkipRocksOff"].Value := (skipRocksVal = 1) ? 0 : 1
    UpdateShopControls()
    loop 8 {
        fld["Shop2Btn" A_Index "X"].Value := IniRead(CFG, "Shop", "L2Btn" A_Index "X", 0)
        fld["Shop2Btn" A_Index "Y"].Value := IniRead(CFG, "Shop", "L2Btn" A_Index "Y", 0)
    }
    fld["KB_Start"].Value := IniRead(CFG, "Hotkeys", "Start", "F4")
    fld["KB_Stop"].Value  := IniRead(CFG, "Hotkeys", "Stop",  "F5")
    fld["KB_Front"].Value := IniRead(CFG, "Hotkeys", "Front", ".")
}

SaveSettings(*) {
    global fld, CFG
    IniWrite fld["ResW"].Value,      CFG, "Window",     "ResW"
    IniWrite fld["ResH"].Value,      CFG, "Window",     "ResH"
    IniWrite fld["SellTabX"].Value,  CFG, "Sell",       "GoldenTabX"
    IniWrite fld["SellTabY"].Value,  CFG, "Sell",       "GoldenTabY"
    IniWrite fld["SellAllX"].Value,  CFG, "Sell",       "SellAllX"
    IniWrite fld["SellAllY"].Value,  CFG, "Sell",       "SellAllY"
    IniWrite fld["GenBtnX"].Value,   CFG, "Generators", "BtnX"
    IniWrite fld["GenYTop"].Value,   CFG, "Generators", "YTop"
    IniWrite fld["GenYBot"].Value,   CFG, "Generators", "YBot"
    IniWrite fld["GenRowH"].Value,   CFG, "Generators", "RowHeight"
    IniWrite fld["ScrollX"].Value,   CFG, "Generators", "ScrollX"
    IniWrite fld["ScrollY"].Value,   CFG, "Generators", "ScrollY"
    IniWrite fld["PresNowX"].Value,  CFG, "Prestige",   "NowX"
    IniWrite fld["PresNowY"].Value,  CFG, "Prestige",   "NowY"
    IniWrite fld["PresConX"].Value,  CFG, "Prestige",   "ConfirmX"
    IniWrite fld["PresConY"].Value,  CFG, "Prestige",   "ConfirmY"
    IniWrite fld["AscEnabled"].Value, CFG, "Ascend",    "Enabled"
    IniWrite fld["AscPath"].Value ? 1 : 2, CFG, "Ascend", "Path"
    IniWrite fld["AscAbuX"].Value,   CFG, "Ascend",     "BtnAbundanceX"
    IniWrite fld["AscAbuY"].Value,   CFG, "Ascend",     "BtnAbundanceY"
    IniWrite fld["AscPreX"].Value,   CFG, "Ascend",     "BtnPrestigeX"
    IniWrite fld["AscPreY"].Value,   CFG, "Ascend",     "BtnPrestigeY"
    IniWrite fld["AscConX"].Value,   CFG, "Ascend",     "ConfirmX"
    IniWrite fld["AscConY"].Value,   CFG, "Ascend",     "ConfirmY"
    IniWrite fld["InvEnabled"].Value, CFG, "Inventory", "Enabled"
    IniWrite fld["InvPresX"].Value,   CFG, "Inventory", "PresPotatoX"
    IniWrite fld["InvPresY"].Value,   CFG, "Inventory", "PresPotatoY"
    IniWrite fld["InvPresEqX"].Value, CFG, "Inventory", "PresEquipX"
    IniWrite fld["InvPresEqY"].Value, CFG, "Inventory", "PresEquipY"
    IniWrite fld["InvBonX"].Value,    CFG, "Inventory", "BonPotatoX"
    IniWrite fld["InvBonY"].Value,    CFG, "Inventory", "BonPotatoY"
    IniWrite fld["InvBonEqX"].Value,  CFG, "Inventory", "BonEquipX"
    IniWrite fld["InvBonEqY"].Value,  CFG, "Inventory", "BonEquipY"
    IniWrite fld["ShopAuto"].Value,   CFG, "Shop",      "AutoEnabled"
    IniWrite fld["SkipRocks"].Value ? 1 : 0, CFG, "Shop", "SkipRocks"
    loop 8 {
        IniWrite fld["Shop2Btn" A_Index "X"].Value, CFG, "Shop", "L2Btn" A_Index "X"
        IniWrite fld["Shop2Btn" A_Index "Y"].Value, CFG, "Shop", "L2Btn" A_Index "Y"
    }
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
    ahkExe := GetAhkExe()
    if !ahkExe {
        MsgBox "AutoHotkey v2 not found.`nPlease install it from autohotkey.com", "Error", 0x10
        return
    }
    WinGetPos &wx, &wy, , , "ahk_id " hwnd
    SaveSettings()
    Run '"' ahkExe '" "' MACRO_SCRIPT '" ' hwnd ' ' wx ' ' wy ' "' deployDir '"', , , &pid
    activeMacros[hwnd] := pid
    RefreshList()
}

StartShopLoop(*) {
    global shopPid, btnStartShop, btnStopShop
    if (shopPid > 0 && ProcessExist(shopPid)) {
        MsgBox "Shop loop is already running."
        return
    }
    row := listBox.GetNext(0, "Focused")
    if !row
        row := 1
    hwnd := Integer(listBox.GetText(row, 2))
    if !hwnd
        return
    ahkExe := GetAhkExe()
    if !ahkExe {
        MsgBox "AutoHotkey v2 not found.", "Error", 0x10
        return
    }
    WinGetPos &wx, &wy, , , "ahk_id " hwnd
    SaveSettings()
    Run '"' ahkExe '" "' MACRO_SCRIPT '" ' hwnd ' ' wx ' ' wy ' "' deployDir '" shop', , , &shopPid
    btnStartShop.Enabled := false
    btnStopShop.Enabled  := true
}

StopShopLoop(*) {
    global shopPid, btnStartShop, btnStopShop
    if (shopPid > 0)
        try ProcessClose(shopPid)
    shopPid := 0
    btnStartShop.Enabled := true
    btnStopShop.Enabled  := false
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
    StopShopLoop()
    RefreshList()
}

; =============================================
;   WIRE UP
; =============================================
btnStart.OnEvent("Click", StartSelected)
btnStartShop.OnEvent("Click", StartShopLoop)
btnStopShop.OnEvent("Click", StopShopLoop)
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
    global fld, btnStart, btnStopAll
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
    btnStart.Text   := "Start  [" fld["KB_Start"].Value "]"
    btnStopAll.Text := "Stop All  [" fld["KB_Stop"].Value "]"
}

btnStopShop.Enabled := false
LoadSettings()
ApplyHotkeys()
RefreshList()
mainGui.Show("w1100 h685")
