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
rerollPid    := 0

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
    loginGui.BackColor := "1E1E2E"
    loginGui.SetFont("s10 cCDD6F4", "Segoe UI")
    loginGui.Add("Text", "x15 y15 w200", "Username:")
    userEdit := loginGui.Add("Edit", "x15 y33 w200 -Theme Background2A2A3E")
    loginGui.Add("Text", "x15 y63 w200", "Password:")
    passEdit := loginGui.Add("Edit", "x15 y81 w200 -Theme Password Background2A2A3E")
    errText  := loginGui.Add("Text", "x15 y111 w200 cRed", "")
    btnLogin := loginGui.Add("Button", "x15 y130 w200 Background3D6B9E", "Login")
    btnLogin.SetFont("s10 cWhite Bold", "Segoe UI")

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
        http.SetTimeouts(5000, 5000, 5000, 5000)
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

MeasureClickRowH(*) {
    MeasureRowHTo("ClickRowH")
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
    fld[keyX] := mainGui.Add("Edit", "x" (203+xOff) " y" y " w50 Number -Theme Background2A2A3E")
    mainGui.Add("Text", "x" (256+xOff) " y" (y+3) " w18", "Y:")
    fld[keyY] := mainGui.Add("Edit", "x" (274+xOff) " y" y " w50 Number -Theme Background2A2A3E")
    mainGui.Add("Button", "x" (327+xOff) " y" (y-1) " w22 h21", "+")
        .OnEvent("Click", PickCoord.Bind(keyX, keyY, pickTip))
    if desc != ""
        mainGui.Add("Text", "x" (354+xOff) " y" (y+3) " w156 c888BA8", desc)
}

CoordRowX(label, y, key, desc := "", pickTip := "", xOff := 0) {
    global mainGui, fld
    mainGui.Add("Text", "x" (10+xOff) " y" (y+3) " w175", label)
    mainGui.Add("Text", "x" (185+xOff) " y" (y+3) " w18", "X:")
    fld[key] := mainGui.Add("Edit", "x" (203+xOff) " y" y " w50 Number -Theme Background2A2A3E")
    mainGui.Add("Button", "x" (256+xOff) " y" (y-1) " w22 h21", "+")
        .OnEvent("Click", PickSingleX.Bind(key, pickTip))
    if desc != ""
        mainGui.Add("Text", "x" (283+xOff) " y" (y+3) " w227 c888BA8", desc)
}

CoordRowY(label, y, key, desc := "", pickTip := "", xOff := 0) {
    global mainGui, fld
    mainGui.Add("Text", "x" (10+xOff) " y" (y+3) " w175", label)
    mainGui.Add("Text", "x" (185+xOff) " y" (y+3) " w18", "Y:")
    fld[key] := mainGui.Add("Edit", "x" (203+xOff) " y" y " w50 Number -Theme Background2A2A3E")
    mainGui.Add("Button", "x" (256+xOff) " y" (y-1) " w22 h21", "+")
        .OnEvent("Click", PickSingleY.Bind(key, pickTip))
    if desc != ""
        mainGui.Add("Text", "x" (283+xOff) " y" (y+3) " w227 c888BA8", desc)
}

SectionHeader(label, y) {
    global mainGui
    mainGui.Add("Text", "x10 y" y " w500 c888BA8", label)
}

KeybindRow(label, y, key, xOff := 0) {
    global mainGui, fld
    mainGui.Add("Text", "x" (10+xOff) " y" (y+3) " w150", label)
    fld["KB_" key] := mainGui.Add("Text", "x" (175+xOff) " y" (y+3) " w100 c89B4FA", "")
    mainGui.Add("Button", "x" (285+xOff) " y" (y-1) " w60 h21", "Set")
        .OnEvent("Click", RecordKey.Bind(key))
}

InvSlotRow(label, rowY, keyX, keyY, xBase) {
    global mainGui, fld
    mainGui.Add("Text",   "x" (xBase)     " y" (rowY+3) " w55",                        label)
    mainGui.Add("Text",   "x" (xBase+57)  " y" (rowY+3) " w12",                        "X:")
    fld[keyX] := mainGui.Add("Edit", "x" (xBase+71)  " y" rowY     " w36 Number -Theme Background2A2A3E")
    mainGui.Add("Text",   "x" (xBase+110) " y" (rowY+3) " w12",                        "Y:")
    fld[keyY] := mainGui.Add("Edit", "x" (xBase+124) " y" rowY     " w36 Number -Theme Background2A2A3E")
    mainGui.Add("Button", "x" (xBase+163) " y" (rowY-1) " w22 h21", "+")
        .OnEvent("Click", PickCoord.Bind(keyX, keyY, ""))
}

CompactCoord(label, y, keyX, keyY, xOff, pickTip := "") {
    global mainGui, fld
    mainGui.Add("Text",   "x" xOff         " y" (y+3) " w42",                       label)
    mainGui.Add("Text",   "x" (xOff + 42)  " y" (y+3) " w12",                       "X:")
    fld[keyX] := mainGui.Add("Edit", "x" (xOff + 56)  " y" y     " w42 Number -Theme Background2A2A3E")
    mainGui.Add("Text",   "x" (xOff + 102) " y" (y+3) " w12",                       "Y:")
    fld[keyY] := mainGui.Add("Edit", "x" (xOff + 116) " y" y     " w42 Number -Theme Background2A2A3E")
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
mainGui.BackColor := "1E1E2E"
mainGui.SetFont("s9 cCDD6F4", "Segoe UI")

tabs := mainGui.Add("Tab3", "x0 y0 w1100 h685", ["  Main  ", "  Settings  ", "  Gen / Click Upgrades  ", "  Genetics  "])

; =============================================
;   TAB 1 — MAIN
; =============================================
tabs.UseTab(1)

mainGui.Add("Text", "x10 y33 w480", "Roblox Windows Detected:")
listBox := mainGui.Add("ListView", "x10 y50 w1080 h140 -Multi Background2A2A3E", ["Window Title", "ID", "Status"])
listBox.ModifyCol(1, 820)
listBox.ModifyCol(2, 120)
listBox.ModifyCol(3, 100)

mainGui.Add("Button", "x10 y200 w1080 h24 Background2E3A4E", "Auto-Find").OnEvent("Click", AutoFind)

btnUpdate := mainGui.Add("Button", "x10 y230 w1080 h24 Hidden", "⬇ Update Available — Click to Update")
btnUpdate.SetFont("s9 cWhite", "Segoe UI")
btnUpdate.Opt("Background336699")
btnUpdate.OnEvent("Click", DoUpdate)

; --- 4 evenly-spaced toggle GroupBoxes (centered: 4×255 + 5×16 = 1100) ---
mainGui.Add("GroupBox", "x16 y260 w255 h90", "")
fld["AscEnabled"] := mainGui.Add("CheckBox", "x31 y282 w220 -Theme", "Ascend")
fld["AscEnabled"].OnEvent("Click", UpdateAscendControls)
fld["AscPath"]  := mainGui.Add("Radio", "x46 y304 w205 Group -Theme", "Blessing of Abundance")
fld["AscPath2"] := mainGui.Add("Radio", "x46 y324 w205 -Theme",       "Blessing of Prestige")

mainGui.Add("GroupBox", "x287 y260 w255 h90", "")
fld["InvEnabled"] := mainGui.Add("CheckBox", "x302 y282 w220 -Theme", "Inventory Swap")
mainGui.Add("Text", "x302 y300 w228 c888BA8", "Equips your prestige potato right before each prestige, then swaps back afterwards.")

mainGui.Add("GroupBox", "x558 y260 w255 h90", "")
fld["ShopAuto"] := mainGui.Add("CheckBox", "x573 y282 w220 -Theme", "Auto Shop  (every 5 min)")
fld["ShopAuto"].OnEvent("Click", UpdateShopControls)
fld["SkipRocks"]    := mainGui.Add("Radio", "x588 y304 w195 Group -Theme", "Skip Rock / Useless Rock")
fld["SkipRocksOff"] := mainGui.Add("Radio", "x588 y324 w100 -Theme",        "Buy All")

mainGui.Add("GroupBox", "x829 y260 w255 h90", "")
mainGui.Add("Text", "x844 y275 w220", "Macro Mode")
fld["MacroModeGen"]    := mainGui.Add("Radio", "x844 y295 w220 Group -Theme", "Generators")
fld["MacroModeClicks"] := mainGui.Add("Radio", "x844 y317 w220 -Theme",        "Click Upgrades")

btnStartShop := mainGui.Add("Button", "x10  y358 w540 h24  Background2E5E8E", "▶ Start Shop Loop")
btnStartShop.SetFont("s9 cWhite Bold", "Segoe UI")
btnStopShop  := mainGui.Add("Button", "x550 y358 w540 h24  Background5E2E2E", "■ Stop Shop")
btnStopShop.SetFont("s9 cWhite Bold", "Segoe UI")
btnStart     := mainGui.Add("Button", "x10  y388 w540 h267 Background2D7D3A", "Start  [F4]")
btnStart.SetFont("s12 cWhite Bold", "Segoe UI")
btnStopAll   := mainGui.Add("Button", "x550 y388 w540 h267 Background7D2D2D", "Stop All  [F5]")
btnStopAll.SetFont("s12 cWhite Bold", "Segoe UI")
btnStopAll.OnEvent("Click", StopAllWithTip)

; =============================================
;   TAB 2 — SETTINGS
; =============================================
tabs.UseTab(2)

mainGui.Add("Text", "x10 y36 w75", "Resolution:")
mainGui.Add("Text", "x88 y36 w20", "W:")
fld["ResW"] := mainGui.Add("Edit", "x108 y33 w55 Number -Theme Background2A2A3E")
mainGui.Add("Text", "x167 y36 w15", "×")
mainGui.Add("Text", "x185 y36 w20", "H:")
fld["ResH"] := mainGui.Add("Edit", "x205 y33 w55 Number -Theme Background2A2A3E")
mainGui.Add("Button", "x270 y33 w120 Background2E3A4E", "Auto-detect").OnEvent("Click", AutoDetectRes)

mainGui.Add("Text", "x10 y60 w22 c888BA8", "the")
mainGui.Add("Text", "x30 y57 w22 h21 Border Center", "+")
mainGui.Add("Text", "x57 y60 w900 c888BA8", "acts as a coordinate finder — click it, then click the spot in Roblox")

; ============= LEFT COLUMN =============
mainGui.Add("GroupBox", "x5 y85 w510 h78", " Sell ")
CoordRow("• Golden Potatoes Tab", 104, "SellTabX", "SellTabY", "", "Click the golden potatoes tab in the sell screen")
CoordRow("• Sell All Button",     126, "SellAllX", "SellAllY", "", "Click the sell all button")

mainGui.Add("GroupBox", "x5 y170 w510 h78", " Prestige ")
CoordRow("• Prestige Now",     189, "PresNowX", "PresNowY", "", "Click the Prestige Now button")
CoordRow("• Prestige Confirm", 211, "PresConX", "PresConY", "", "Click the confirm button on the prestige popup")

mainGui.Add("GroupBox", "x5 y255 w510 h128", " Ascend ")
CoordRow("• Blessing of Abundance", 281, "AscAbuX", "AscAbuY", "", "Click the Blessing of Abundance path button")
CoordRow("• Blessing of Prestige",  303, "AscPreX", "AscPreY", "", "Click the Blessing of Prestige path button")
CoordRow("• Ascend Confirm",        325, "AscConX", "AscConY", "", "Click the confirm button on the ascend popup")

; ============= RIGHT COLUMN =============
mainGui.Add("GroupBox", "x520 y85 w575 h100", " Keybinds ")
KeybindRow("• Start",          104, "Start", 515)
KeybindRow("• Stop All",       126, "Stop",  515)
KeybindRow("• Bring to Front", 148, "Front", 515)

mainGui.Add("GroupBox", "x520 y195 w575 h145", " Shop ")
mainGui.Add("Text", "x530 y214 w555 c888BA8", "Set the BUY button for each slot. Left col = Btn 1-4, right col = Btn 5-8.")

loop 4 {
    rowY := 234 + (A_Index - 1) * 22
    CompactCoord("Btn " A_Index,       rowY, "Shop2Btn" A_Index       "X", "Shop2Btn" A_Index       "Y", 525, "Click Buy Button " A_Index       " in the shop")
    CompactCoord("Btn " (A_Index + 4), rowY, "Shop2Btn" (A_Index + 4) "X", "Shop2Btn" (A_Index + 4) "Y", 795, "Click Buy Button " (A_Index + 4) " in the shop")
}

mainGui.Add("GroupBox", "x520 y350 w575 h240", " Inventory Swap ")
mainGui.Add("Text", "x525 y368 w185 Center cCDD6F4", "— Slot 1 (Top) —")
mainGui.Add("Text", "x715 y368 w185 Center cCDD6F4", "— Slot 2 (Mid) —")
mainGui.Add("Text", "x905 y368 w185 Center cCDD6F4", "— Slot 3 (Bot) —")
loop 3 {
    s  := A_Index
    xb := 525 + (s - 1) * 190
    InvSlotRow("PresPot", 388, Format("InvPresX{}",   s), Format("InvPresY{}",   s), xb)
    InvSlotRow("PresEq",  410, Format("InvPresEqX{}", s), Format("InvPresEqY{}", s), xb)
    InvSlotRow("BonPot",  432, Format("InvBonX{}",    s), Format("InvBonY{}",    s), xb)
    InvSlotRow("BonEq",   454, Format("InvBonEqX{}",  s), Format("InvBonEqY{}",  s), xb)
}

mainGui.Add("Button", "x10 y590 w1080 h28 Background3D5A80", "Save Settings").OnEvent("Click", SaveSettings)

; =============================================
;   TAB 4 — GENETICS
; =============================================
tabs.UseTab(4)

mainGui.Add("GroupBox", "x5 y36 w510 h78", " Reroll ")
CoordRow("• Reroll Button",  55, "RerollBtnX", "RerollBtnY", "", "Click the Reroll All Slots button")
CoordRow("• Confirm Button", 77, "RerollConX", "RerollConY", "", "Click the confirm button")

mainGui.Add("GroupBox", "x5 y120 w510 h55", " Result Detection ")
CoordRow("• Genetics Roll Box", 139, "RerollScanX", "RerollScanY", "top-left of result box", "Click the top-left of the result box in the top-right corner of the window")

mainGui.Add("GroupBox", "x520 y36 w575 h55", " Stop on Rarity ")
fld["StopMythic"] := mainGui.Add("CheckBox", "x535 y56 w140 -Theme", "Mythic")
fld["StopSecret"] := mainGui.Add("CheckBox", "x680 y56 w140 -Theme", "Secret")

mainGui.Add("GroupBox", "x520 y97 w575 h148", " Stop on Name ")
fld["StopPotatoProd"] := mainGui.Add("CheckBox", "x535 y117 w270 -Theme", "Potato Production")
fld["StopGenBonus"]   := mainGui.Add("CheckBox", "x535 y139 w270 -Theme", "Generator Bonus")
fld["StopPresPoints"] := mainGui.Add("CheckBox", "x535 y161 w270 -Theme", "Prestige Points")
fld["StopGoldConv"]   := mainGui.Add("CheckBox", "x535 y183 w270 -Theme", "Gold Conversion")
fld["StopCosmicConv"] := mainGui.Add("CheckBox", "x535 y205 w270 -Theme", "Cosmic Clicks Conversion")

btnStartReroll := mainGui.Add("Button", "x5  y255 w540 h24 Background2E5E8E", "▶ Start Reroll Loop")
btnStartReroll.SetFont("s9 cWhite Bold", "Segoe UI")
btnStopReroll  := mainGui.Add("Button", "x550 y255 w540 h24 Background5E2E2E", "■ Stop Reroll")
btnStopReroll.SetFont("s9 cWhite Bold", "Segoe UI")

mainGui.Add("Button", "x10 y590 w1080 h28 Background3D5A80", "Save Settings").OnEvent("Click", SaveSettings)

; =============================================
;   TAB 3 — GEN / CLICK UPGRADES
; =============================================
tabs.UseTab(3)

mainGui.Add("Text", "x10 y36 w22 c888BA8", "the")
mainGui.Add("Text", "x30 y33 w22 h21 Border Center", "+")
mainGui.Add("Text", "x57 y36 w900 c888BA8", "acts as a coordinate finder — click it, then click the spot in Roblox")

; ============= LEFT — GENERATORS =============
mainGui.Add("GroupBox", "x5 y55 w510 h140", " Generators ")
CoordRowX("• Buy Button (col X)", 74,  "GenBtnX",  "any green buy button",             "Click any green buy button in the generators list")
CoordRowY("• Y Top",              96,  "GenYTop",  "the highest buy button",            "Click the highest visible buy button")
CoordRowY("• Y Bot",              118, "GenYBot",  "the lowest buy button",             "Click the lowest visible buy button")
mainGui.Add("Text",   "x10 y143 w175", "• Row Spacing:")
fld["GenRowH"] := mainGui.Add("Edit", "x203 y140 w50 Number -Theme Background2A2A3E")
mainGui.Add("Button", "x256 y139 w22 h21", "+").OnEvent("Click", MeasureRowH)
mainGui.Add("Text",   "x283 y143 w227 c888BA8", "any buy button, then the one below it")
CoordRow("• Scroll Area", 162, "ScrollX", "ScrollY", "anywhere in the generator list", "Click anywhere inside the generator scroll list")

; ============= RIGHT — CLICK UPGRADES =============
mainGui.Add("GroupBox", "x520 y55 w575 h165", " Click Upgrades ")
CoordRowX("• Buy Button (col X)", 74,  "ClickBtnX",    "any green buy button in the list",    "Click any green buy button in the click upgrades list", 515)
CoordRowY("• Y Top",              96,  "ClickYTop",    "the highest buy button",               "Click the highest visible buy button",                  515)
CoordRowY("• Y Bot",              118, "ClickYBot",    "the lowest buy button",                "Click the lowest visible buy button",                   515)
mainGui.Add("Text",   "x" (10+515) " y143 w175", "• Row Spacing:")
fld["ClickRowH"] := mainGui.Add("Edit", "x" (203+515) " y140 w50 Number -Theme Background2A2A3E")
mainGui.Add("Button", "x" (256+515) " y139 w22 h21", "+").OnEvent("Click", MeasureClickRowH)
mainGui.Add("Text",   "x" (283+515) " y143 w227 c888BA8", "any buy button, then the one below it")
CoordRow("• Scroll Area", 162, "ClickScrollX", "ClickScrollY", "anywhere in the click list", "Click anywhere inside the click upgrades scroll list", 515)
CoordRow("• Home Potato", 184, "ClickHomeX",   "ClickHomeY",   "center of the potato",       "Click the center of the potato on the home screen",  515)

mainGui.Add("Button", "x10 y590 w1080 h28 Background3D5A80", "Save Settings").OnEvent("Click", SaveSettings)

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
    fld["InvEnabled"].Value := IniRead(CFG, "Inventory", "Enabled", 0)
    loop 3 {
        s   := A_Index
        sec := "Inventory" s
        fld[Format("InvPresX{}",   s)].Value := IniRead(CFG, sec, "PresPotatoX", 0)
        fld[Format("InvPresY{}",   s)].Value := IniRead(CFG, sec, "PresPotatoY", 0)
        fld[Format("InvPresEqX{}", s)].Value := IniRead(CFG, sec, "PresEquipX",  0)
        fld[Format("InvPresEqY{}", s)].Value := IniRead(CFG, sec, "PresEquipY",  0)
        fld[Format("InvBonX{}",    s)].Value := IniRead(CFG, sec, "BonPotatoX",  0)
        fld[Format("InvBonY{}",    s)].Value := IniRead(CFG, sec, "BonPotatoY",  0)
        fld[Format("InvBonEqX{}", s)].Value := IniRead(CFG, sec, "BonEquipX",   0)
        fld[Format("InvBonEqY{}", s)].Value := IniRead(CFG, sec, "BonEquipY",   0)
    }
    fld["RerollBtnX"].Value     := IniRead(CFG, "Reroll", "BtnX",          0)
    fld["RerollBtnY"].Value     := IniRead(CFG, "Reroll", "BtnY",          0)
    fld["RerollConX"].Value     := IniRead(CFG, "Reroll", "ConfirmX",      0)
    fld["RerollConY"].Value     := IniRead(CFG, "Reroll", "ConfirmY",      0)
    fld["RerollScanX"].Value    := IniRead(CFG, "Reroll", "ScanX",         0)
    fld["RerollScanY"].Value    := IniRead(CFG, "Reroll", "ScanY",         0)
    fld["StopMythic"].Value     := IniRead(CFG, "Reroll", "StopMythic",    0)
    fld["StopSecret"].Value     := IniRead(CFG, "Reroll", "StopSecret",    0)
    fld["StopPotatoProd"].Value := IniRead(CFG, "Reroll", "StopPotatoProd", 0)
    fld["StopGenBonus"].Value   := IniRead(CFG, "Reroll", "StopGenBonus",  0)
    fld["StopPresPoints"].Value := IniRead(CFG, "Reroll", "StopPresPoints", 0)
    fld["StopGoldConv"].Value   := IniRead(CFG, "Reroll", "StopGoldConv",  0)
    fld["StopCosmicConv"].Value := IniRead(CFG, "Reroll", "StopCosmicConv", 0)
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
    fld["ClickBtnX"].Value    := IniRead(CFG, "ClickUpgrades", "BtnX",      0)
    fld["ClickYTop"].Value    := IniRead(CFG, "ClickUpgrades", "YTop",      0)
    fld["ClickYBot"].Value    := IniRead(CFG, "ClickUpgrades", "YBot",      0)
    fld["ClickRowH"].Value    := IniRead(CFG, "ClickUpgrades", "RowHeight", 0)
    fld["ClickScrollX"].Value := IniRead(CFG, "ClickUpgrades", "ScrollX",   0)
    fld["ClickScrollY"].Value := IniRead(CFG, "ClickUpgrades", "ScrollY",   0)
    fld["ClickHomeX"].Value   := IniRead(CFG, "ClickUpgrades", "HomeX",     0)
    fld["ClickHomeY"].Value   := IniRead(CFG, "ClickUpgrades", "HomeY",     0)
    macroMode := IniRead(CFG, "Main", "MacroMode", "generators")
    fld["MacroModeGen"].Value    := (macroMode = "generators") ? 1 : 0
    fld["MacroModeClicks"].Value := (macroMode = "clicks")     ? 1 : 0
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
    loop 3 {
        s   := A_Index
        sec := "Inventory" s
        IniWrite fld[Format("InvPresX{}",   s)].Value, CFG, sec, "PresPotatoX"
        IniWrite fld[Format("InvPresY{}",   s)].Value, CFG, sec, "PresPotatoY"
        IniWrite fld[Format("InvPresEqX{}", s)].Value, CFG, sec, "PresEquipX"
        IniWrite fld[Format("InvPresEqY{}", s)].Value, CFG, sec, "PresEquipY"
        IniWrite fld[Format("InvBonX{}",    s)].Value, CFG, sec, "BonPotatoX"
        IniWrite fld[Format("InvBonY{}",    s)].Value, CFG, sec, "BonPotatoY"
        IniWrite fld[Format("InvBonEqX{}", s)].Value, CFG, sec, "BonEquipX"
        IniWrite fld[Format("InvBonEqY{}", s)].Value, CFG, sec, "BonEquipY"
    }
    IniWrite fld["RerollBtnX"].Value,     CFG, "Reroll", "BtnX"
    IniWrite fld["RerollBtnY"].Value,     CFG, "Reroll", "BtnY"
    IniWrite fld["RerollConX"].Value,     CFG, "Reroll", "ConfirmX"
    IniWrite fld["RerollConY"].Value,     CFG, "Reroll", "ConfirmY"
    IniWrite fld["RerollScanX"].Value,    CFG, "Reroll", "ScanX"
    IniWrite fld["RerollScanY"].Value,    CFG, "Reroll", "ScanY"
    IniWrite fld["StopMythic"].Value,     CFG, "Reroll", "StopMythic"
    IniWrite fld["StopSecret"].Value,     CFG, "Reroll", "StopSecret"
    IniWrite fld["StopPotatoProd"].Value, CFG, "Reroll", "StopPotatoProd"
    IniWrite fld["StopGenBonus"].Value,   CFG, "Reroll", "StopGenBonus"
    IniWrite fld["StopPresPoints"].Value, CFG, "Reroll", "StopPresPoints"
    IniWrite fld["StopGoldConv"].Value,   CFG, "Reroll", "StopGoldConv"
    IniWrite fld["StopCosmicConv"].Value, CFG, "Reroll", "StopCosmicConv"
    IniWrite fld["ShopAuto"].Value,   CFG, "Shop",      "AutoEnabled"
    IniWrite fld["SkipRocks"].Value ? 1 : 0, CFG, "Shop", "SkipRocks"
    loop 8 {
        IniWrite fld["Shop2Btn" A_Index "X"].Value, CFG, "Shop", "L2Btn" A_Index "X"
        IniWrite fld["Shop2Btn" A_Index "Y"].Value, CFG, "Shop", "L2Btn" A_Index "Y"
    }
    IniWrite fld["ClickBtnX"].Value,    CFG, "ClickUpgrades", "BtnX"
    IniWrite fld["ClickYTop"].Value,    CFG, "ClickUpgrades", "YTop"
    IniWrite fld["ClickYBot"].Value,    CFG, "ClickUpgrades", "YBot"
    IniWrite fld["ClickRowH"].Value,    CFG, "ClickUpgrades", "RowHeight"
    IniWrite fld["ClickScrollX"].Value, CFG, "ClickUpgrades", "ScrollX"
    IniWrite fld["ClickScrollY"].Value, CFG, "ClickUpgrades", "ScrollY"
    IniWrite fld["ClickHomeX"].Value,   CFG, "ClickUpgrades", "HomeX"
    IniWrite fld["ClickHomeY"].Value,   CFG, "ClickUpgrades", "HomeY"
    IniWrite fld["MacroModeGen"].Value ? "generators" : "clicks", CFG, "Main", "MacroMode"
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

StartRerollLoop(*) {
    global rerollPid, btnStartReroll, btnStopReroll
    if (rerollPid > 0 && ProcessExist(rerollPid)) {
        MsgBox "Reroll loop is already running."
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
    Run '"' ahkExe '" "' MACRO_SCRIPT '" ' hwnd ' ' wx ' ' wy ' "' deployDir '" reroll', , , &rerollPid
    btnStartReroll.Enabled := false
    btnStopReroll.Enabled  := true
}

StopRerollLoop(*) {
    global rerollPid, btnStartReroll, btnStopReroll
    if (rerollPid > 0)
        try ProcessClose(rerollPid)
    rerollPid := 0
    btnStartReroll.Enabled := true
    btnStopReroll.Enabled  := false
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
    StopRerollLoop()
    RefreshList()
}

; =============================================
;   WIRE UP
; =============================================
btnStart.OnEvent("Click", StartSelected)
btnStartShop.OnEvent("Click", StartShopLoop)
btnStopShop.OnEvent("Click", StopShopLoop)
btnStartReroll.OnEvent("Click", StartRerollLoop)
btnStopReroll.OnEvent("Click",  StopRerollLoop)
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

btnStopShop.Enabled   := false
btnStopReroll.Enabled := false
LoadSettings()
ApplyHotkeys()
RefreshList()
mainGui.Show("w1100 h685")
