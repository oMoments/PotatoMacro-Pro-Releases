#Requires AutoHotkey v2.0
#SingleInstance Off

if A_Args.Length < 3 {
    MsgBox "Run this via PotatoLauncher_Pro.ahk"
    ExitApp
}

TARGET_HWND := Integer(A_Args[1])
WIN_X       := Integer(A_Args[2])
WIN_Y       := Integer(A_Args[3])

cfg := A_ScriptDir "\PotatoConfig_Pro.ini"

GEN_BTN_X      := Integer(IniRead(cfg, "Generators", "BtnX",      1454))
GEN_BTN_Y_TOP  := Integer(IniRead(cfg, "Generators", "YTop",       121))
GEN_BTN_Y_BOT  := Integer(IniRead(cfg, "Generators", "YBot",       930))
GEN_ROW_HEIGHT := Integer(IniRead(cfg, "Generators", "RowHeight",    20))
SCROLL_X       := Integer(IniRead(cfg, "Generators", "ScrollX",     948))
SCROLL_Y       := Integer(IniRead(cfg, "Generators", "ScrollY",     583))

SELL_TAB_X := Integer(IniRead(cfg, "Sell", "GoldenTabX", 1183))
SELL_TAB_Y := Integer(IniRead(cfg, "Sell", "GoldenTabY",  591))
SELL_ALL_X := Integer(IniRead(cfg, "Sell", "SellAllX",   1277))
SELL_ALL_Y := Integer(IniRead(cfg, "Sell", "SellAllY",    712))

PRESTIGE_NOW_X := Integer(IniRead(cfg, "Prestige", "NowX",     831))
PRESTIGE_NOW_Y := Integer(IniRead(cfg, "Prestige", "NowY",     404))
PRESTIGE_CON_X := Integer(IniRead(cfg, "Prestige", "ConfirmX", 875))
PRESTIGE_CON_Y := Integer(IniRead(cfg, "Prestige", "ConfirmY", 708))

ASCEND_ENABLED := Integer(IniRead(cfg, "Ascend", "Enabled",        0))
ASCEND_PATH    := Integer(IniRead(cfg, "Ascend", "Path",            1))
ASCEND_ABU_X   := Integer(IniRead(cfg, "Ascend", "BtnAbundanceX", 654))
ASCEND_ABU_Y   := Integer(IniRead(cfg, "Ascend", "BtnAbundanceY", 232))
ASCEND_PRE_X   := Integer(IniRead(cfg, "Ascend", "BtnPrestigeX",  621))
ASCEND_PRE_Y   := Integer(IniRead(cfg, "Ascend", "BtnPrestigeY",  343))
ASCEND_CON_X   := Integer(IniRead(cfg, "Ascend", "ConfirmX",      883))
ASCEND_CON_Y   := Integer(IniRead(cfg, "Ascend", "ConfirmY",      688))

COLOR_GREEN    := 0x48BB78
COLOR_PRESTIGE := 0xBD69FF
TOLERANCE      := 20
running        := true

; =============================================
ActivateTarget() {
    global TARGET_HWND, WIN_X, WIN_Y
    WinActivate "ahk_id " TARGET_HWND
    WinWaitActive "ahk_id " TARGET_HWND, , 2
    WinGetPos &wx, &wy, , , "ahk_id " TARGET_HWND
    WIN_X := wx
    WIN_Y := wy
    Sleep 50
}

ColorMatches(c1, c2, tol) {
    r1 := (c1 >> 16) & 0xFF, g1 := (c1 >> 8) & 0xFF, b1 := c1 & 0xFF
    r2 := (c2 >> 16) & 0xFF, g2 := (c2 >> 8) & 0xFF, b2 := c2 & 0xFF
    return (Abs(r1-r2) <= tol && Abs(g1-g2) <= tol && Abs(b1-b2) <= tol)
}

WiggleClick(rx, ry) {
    global WIN_X, WIN_Y
    ax := WIN_X + rx
    ay := WIN_Y + ry
    MouseMove ax, ay, 3
    Sleep 50
    MouseMove ax, ay+6, 2
    MouseMove ax, ay, 2
    Sleep 50
    SendInput "{LButton Down}"
    Sleep 50
    SendInput "{LButton Up}"
}

; =============================================
SellGolden() {
    global WIN_X, WIN_Y, SELL_TAB_X, SELL_TAB_Y, SELL_ALL_X, SELL_ALL_Y
    ActivateTarget()
    Send "3"
    Sleep 250
    MouseMove WIN_X+SELL_TAB_X, WIN_Y+SELL_TAB_Y, 3
    Sleep 80
    MouseMove WIN_X+SELL_TAB_X, WIN_Y+SELL_TAB_Y-6, 2
    MouseMove WIN_X+SELL_TAB_X, WIN_Y+SELL_TAB_Y, 2
    Sleep 80
    SendInput "{LButton Down}"
    Sleep 50
    SendInput "{LButton Up}"
    Sleep 250
    MouseMove WIN_X+SELL_TAB_X, WIN_Y+SELL_TAB_Y, 3
    MouseMove WIN_X+SELL_ALL_X, WIN_Y+SELL_ALL_Y, 3
    Sleep 100
    MouseMove WIN_X+SELL_ALL_X, WIN_Y+SELL_ALL_Y-6, 2
    MouseMove WIN_X+SELL_ALL_X, WIN_Y+SELL_ALL_Y, 2
    Sleep 50
    SendInput "{LButton Down}"
    Sleep 50
    SendInput "{LButton Up}"
    Sleep 80
}

; =============================================
BuyAtCurrentScrollRange(yTop, yBot, maxBottomClicks := 0, clickUp := 0) {
    global WIN_X, WIN_Y, GEN_BTN_X, GEN_ROW_HEIGHT, COLOR_GREEN, TOLERANCE
    Sleep 150
    lowestY := -1
    y := yBot
    while (y >= yTop) {
        if ColorMatches(PixelGetColor(WIN_X+GEN_BTN_X, WIN_Y+y), COLOR_GREEN, TOLERANCE) {
            lowestY := y
            break
        }
        y -= GEN_ROW_HEIGHT
    }
    if (lowestY = -1)
        return

    safeY := (clickUp > 0 && ColorMatches(PixelGetColor(WIN_X+GEN_BTN_X, WIN_Y+lowestY-clickUp), COLOR_GREEN, TOLERANCE))
        ? lowestY - clickUp : lowestY
    clickCount := 0
    loop {
        if !ColorMatches(PixelGetColor(WIN_X+GEN_BTN_X, WIN_Y+lowestY), COLOR_GREEN, TOLERANCE)
            break
        if (maxBottomClicks > 0 && clickCount >= maxBottomClicks)
            break
        WiggleClick(GEN_BTN_X, safeY)
        clickCount++
        Sleep 60
    }

    if (maxBottomClicks = 0) {
        y2 := lowestY - GEN_ROW_HEIGHT
        if (y2 >= yTop) {
            loop {
                if !ColorMatches(PixelGetColor(WIN_X+GEN_BTN_X, WIN_Y+y2), COLOR_GREEN, TOLERANCE)
                    break
                WiggleClick(GEN_BTN_X, y2)
                Sleep 60
            }
        }
        y3 := lowestY - (GEN_ROW_HEIGHT * 2)
        if (y3 >= yTop) {
            loop {
                if !ColorMatches(PixelGetColor(WIN_X+GEN_BTN_X, WIN_Y+y3), COLOR_GREEN, TOLERANCE)
                    break
                WiggleClick(GEN_BTN_X, y3)
                Sleep 60
            }
        }
    }
}

ScrollAndBuy(maxBottomClicks := 0, scrollFull := false) {
    global WIN_X, WIN_Y, SCROLL_X, SCROLL_Y, GEN_BTN_X, GEN_BTN_Y_TOP, GEN_BTN_Y_BOT, GEN_ROW_HEIGHT, COLOR_GREEN, TOLERANCE
    ActivateTarget()
    Send "2"
    Sleep 600
    MouseMove WIN_X+SCROLL_X, WIN_Y+SCROLL_Y, 0
    Sleep 100

    loop 20
        Send "{WheelDown}"
    Sleep 250

    loop 30 {
        lowestGreenY := -1
        y := GEN_BTN_Y_BOT
        while (y >= GEN_BTN_Y_TOP) {
            if ColorMatches(PixelGetColor(WIN_X+GEN_BTN_X, WIN_Y+y), COLOR_GREEN, TOLERANCE) {
                lowestGreenY := y
                break
            }
            y -= GEN_ROW_HEIGHT
        }
        if (lowestGreenY != -1) {
            Sleep 100
            BuyAtCurrentScrollRange(GEN_BTN_Y_TOP, GEN_BTN_Y_BOT, maxBottomClicks, 5)
            return
        }
        Send "{WheelUp}"
        Sleep 150
    }
}

; =============================================
DoAscend() {
    global WIN_X, WIN_Y, ASCEND_PATH, ASCEND_ABU_X, ASCEND_ABU_Y, ASCEND_PRE_X, ASCEND_PRE_Y, ASCEND_CON_X, ASCEND_CON_Y
    ActivateTarget()
    Send "6"
    Sleep 1000

    ActivateTarget()
    if (ASCEND_PATH = 1) {
        MouseMove WIN_X+ASCEND_ABU_X, WIN_Y+ASCEND_ABU_Y, 3
        Sleep 200
        MouseMove WIN_X+ASCEND_ABU_X, WIN_Y+ASCEND_ABU_Y-6, 2
        MouseMove WIN_X+ASCEND_ABU_X, WIN_Y+ASCEND_ABU_Y, 2
    } else {
        MouseMove WIN_X+ASCEND_PRE_X, WIN_Y+ASCEND_PRE_Y, 3
        Sleep 200
        MouseMove WIN_X+ASCEND_PRE_X, WIN_Y+ASCEND_PRE_Y-6, 2
        MouseMove WIN_X+ASCEND_PRE_X, WIN_Y+ASCEND_PRE_Y, 2
    }
    Sleep 100
    SendInput "{LButton Down}"
    Sleep 50
    SendInput "{LButton Up}"
    Sleep 1200

    MouseMove WIN_X+ASCEND_CON_X, WIN_Y+ASCEND_CON_Y, 3
    Sleep 200
    MouseMove WIN_X+ASCEND_CON_X, WIN_Y+ASCEND_CON_Y-6, 2
    MouseMove WIN_X+ASCEND_CON_X, WIN_Y+ASCEND_CON_Y, 2
    Sleep 100
    SendInput "{LButton Down}"
    Sleep 50
    SendInput "{LButton Up}"
    Sleep 500
}

; =============================================
DoPrestige(loopStart) {
    global WIN_X, WIN_Y, PRESTIGE_NOW_X, PRESTIGE_NOW_Y, PRESTIGE_CON_X, PRESTIGE_CON_Y

    elapsed   := A_TickCount - loopStart
    remaining := 29000 - 2200 - elapsed
    if (remaining > 0)
        Sleep remaining

    SellGolden()
    ActivateTarget()
    Send "5"
    Sleep 700
    MouseMove WIN_X+PRESTIGE_NOW_X, WIN_Y+PRESTIGE_NOW_Y, 3

    elapsed   := A_TickCount - loopStart
    remaining := 29000 - elapsed
    if (remaining > 0)
        Sleep remaining

    MouseMove WIN_X+PRESTIGE_NOW_X, WIN_Y+PRESTIGE_NOW_Y-6, 2
    MouseMove WIN_X+PRESTIGE_NOW_X, WIN_Y+PRESTIGE_NOW_Y, 2
    Sleep 50
    SendInput "{LButton Down}"
    Sleep 50
    SendInput "{LButton Up}"
    Sleep 400

    ActivateTarget()
    MouseMove WIN_X+PRESTIGE_CON_X, WIN_Y+PRESTIGE_CON_Y, 3
    Sleep 50
    MouseMove WIN_X+PRESTIGE_CON_X, WIN_Y+PRESTIGE_CON_Y-6, 2
    MouseMove WIN_X+PRESTIGE_CON_X, WIN_Y+PRESTIGE_CON_Y, 2
    Sleep 50
    SendInput "{LButton Down}"
    Sleep 50
    SendInput "{LButton Up}"
    Sleep 500
}

; =============================================
RunLoop() {
    global running, TARGET_HWND, ASCEND_ENABLED
    while running {
        loopStart := A_TickCount
        SellGolden()
        ScrollAndBuy(2)
        SellGolden()
        ScrollAndBuy(2)
        SellGolden()
        ScrollAndBuy(2)
        SellGolden()
        ScrollAndBuy(2)
        SellGolden()
        ScrollAndBuy(3)
        SellGolden()
        if ASCEND_ENABLED
            ScrollAndBuy(0)
        else
            ScrollAndBuy(0, true)
        DoPrestige(loopStart)
        if ASCEND_ENABLED
            DoAscend()
        elapsed := A_TickCount - loopStart
        ToolTip "Loop: " Round(elapsed/1000, 2) "s"
        SetTimer () => ToolTip(), -3000
    }
}

SetTimer RunLoop, -1
