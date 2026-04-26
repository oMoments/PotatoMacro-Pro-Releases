#Requires AutoHotkey v2.0
#SingleInstance Off
#Include OCR.ahk

if A_Args.Length < 3 {
    MsgBox "Run this via PotatoLauncher_Pro.ahk"
    ExitApp
}

TARGET_HWND := Integer(A_Args[1])
WIN_X       := Integer(A_Args[2])
WIN_Y       := Integer(A_Args[3])
ASSET_DIR   := A_Args.Length >= 4 ? A_Args[4] : A_ScriptDir
MODE        := A_Args.Length >= 5 ? A_Args[5] : "loop"

cfg := ASSET_DIR "\PotatoConfig_Pro.ini"

WIN_W := Integer(IniRead(cfg, "Window", "ResW", 1920))
WIN_H := Integer(IniRead(cfg, "Window", "ResH", 1080))

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

INV_PRES_X   := Integer(IniRead(cfg, "Inventory", "PresPotatoX", 0))
INV_PRES_Y   := Integer(IniRead(cfg, "Inventory", "PresPotatoY", 0))
INV_PRES_EQX := Integer(IniRead(cfg, "Inventory", "PresEquipX",  0))
INV_PRES_EQY := Integer(IniRead(cfg, "Inventory", "PresEquipY",  0))
INV_BON_X    := Integer(IniRead(cfg, "Inventory", "BonPotatoX",  0))
INV_BON_Y    := Integer(IniRead(cfg, "Inventory", "BonPotatoY",  0))
INV_BON_EQX  := Integer(IniRead(cfg, "Inventory", "BonEquipX",   0))
INV_BON_EQY  := Integer(IniRead(cfg, "Inventory", "BonEquipY",   0))
INV_SWAP_ON  := Integer(IniRead(cfg, "Inventory", "Enabled", 0))
INV_ENABLED  := (INV_SWAP_ON && INV_PRES_X > 0 && INV_BON_X > 0)

SHOP_BTNS := []
loop 8 {
    bx := Integer(IniRead(cfg, "Shop", "L2Btn" A_Index "X", 0))
    by := Integer(IniRead(cfg, "Shop", "L2Btn" A_Index "Y", 0))
    SHOP_BTNS.Push(Map("x", bx, "y", by))
}

SHOP_SKIP_ROCKS := Integer(IniRead(cfg, "Shop", "SkipRocks",   1))
SHOP_AUTO       := Integer(IniRead(cfg, "Shop", "AutoEnabled", 0))
SHOP_ENABLED    := (SHOP_AUTO && SHOP_BTNS[1]["x"] > 0)

; Rock Box (offset+size from BUY anchor) — defines ImageSearch region
SHOP_ROCK_DX := Integer(IniRead(cfg, "Shop", "RockOffX", 0))
SHOP_ROCK_DY := Integer(IniRead(cfg, "Shop", "RockOffY", 0))
SHOP_ROCK_W  := Integer(IniRead(cfg, "Shop", "RockW",    32))
SHOP_ROCK_H  := Integer(IniRead(cfg, "Shop", "RockH",    32))

lastShopTime := 0

ASCEND_ENABLED := Integer(IniRead(cfg, "Ascend", "Enabled",        0))
ASCEND_PATH    := Integer(IniRead(cfg, "Ascend", "Path",            1))
ASCEND_ABU_X   := Integer(IniRead(cfg, "Ascend", "BtnAbundanceX", 654))
ASCEND_ABU_Y   := Integer(IniRead(cfg, "Ascend", "BtnAbundanceY", 232))
ASCEND_PRE_X   := Integer(IniRead(cfg, "Ascend", "BtnPrestigeX",  621))
ASCEND_PRE_Y   := Integer(IniRead(cfg, "Ascend", "BtnPrestigeY",  343))
ASCEND_CON_X   := Integer(IniRead(cfg, "Ascend", "ConfirmX",      883))
ASCEND_CON_Y   := Integer(IniRead(cfg, "Ascend", "ConfirmY",      688))

REROLL_BTN_X   := Integer(IniRead(cfg, "Reroll", "BtnX",           0))
REROLL_BTN_Y   := Integer(IniRead(cfg, "Reroll", "BtnY",           0))
REROLL_CON_X   := Integer(IniRead(cfg, "Reroll", "ConfirmX",       0))
REROLL_CON_Y   := Integer(IniRead(cfg, "Reroll", "ConfirmY",       0))
REROLL_SCAN_X  := Integer(IniRead(cfg, "Reroll", "ScanX",          0))
REROLL_SCAN_Y  := Integer(IniRead(cfg, "Reroll", "ScanY",          0))
REROLL_MYTHIC  := Integer(IniRead(cfg, "Reroll", "StopMythic",     0))
REROLL_SECRET  := Integer(IniRead(cfg, "Reroll", "StopSecret",     0))
REROLL_POTATO  := Integer(IniRead(cfg, "Reroll", "StopPotatoProd", 0))
REROLL_GENBON  := Integer(IniRead(cfg, "Reroll", "StopGenBonus",   0))
REROLL_PRESPNT := Integer(IniRead(cfg, "Reroll", "StopPresPoints", 0))
REROLL_GOLDCON := Integer(IniRead(cfg, "Reroll", "StopGoldConv",   0))
REROLL_COSMIC  := Integer(IniRead(cfg, "Reroll", "StopCosmicConv", 0))

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

DirectClick(rx, ry) {
    global WIN_X, WIN_Y
    MouseMove WIN_X + rx, WIN_Y + ry, 3
    Sleep 60
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
BuyAtCurrentScrollRange(yTop, yBot, maxBottomClicks := 0) {
    global WIN_X, WIN_Y, GEN_BTN_X, GEN_ROW_HEIGHT, COLOR_GREEN, TOLERANCE
    Sleep 150

    ; Coarse scan bottom→up in row steps to find deepest green button
    lowestY := -1
    y := yBot
    while (y >= yTop) {
        if ColorMatches(PixelGetColor(WIN_X+GEN_BTN_X, WIN_Y+y), COLOR_GREEN, TOLERANCE) {
            lowestY := y
            break
        }
        y -= GEN_ROW_HEIGHT
    }
    ; Fine scan: look below coarse position for deeper green pixels
    if (lowestY != -1) {
        fineY := lowestY + GEN_ROW_HEIGHT - 1
        while (fineY > lowestY) {
            if (fineY <= yBot && ColorMatches(PixelGetColor(WIN_X+GEN_BTN_X, WIN_Y+fineY), COLOR_GREEN, TOLERANCE)) {
                lowestY := fineY
                break
            }
            fineY -= 2
        }
    }
    if (lowestY = -1)
        return

    ; Find button center: scan upward from lowestY until green ends, click midpoint
    topY := lowestY
    while (topY > yTop && ColorMatches(PixelGetColor(WIN_X+GEN_BTN_X, WIN_Y+topY-1), COLOR_GREEN, TOLERANCE))
        topY--
    clickY := (topY + lowestY) // 2

    clickCount := 0
    loop {
        if !ColorMatches(PixelGetColor(WIN_X+GEN_BTN_X, WIN_Y+clickY), COLOR_GREEN, TOLERANCE)
            break
        if (maxBottomClicks > 0 && clickCount >= maxBottomClicks)
            break
        WiggleClick(GEN_BTN_X, clickY)
        clickCount++
        Sleep 60
    }

    if (maxBottomClicks = 0) {
        y2 := clickY - GEN_ROW_HEIGHT
        if (y2 >= yTop) {
            loop {
                if !ColorMatches(PixelGetColor(WIN_X+GEN_BTN_X, WIN_Y+y2), COLOR_GREEN, TOLERANCE)
                    break
                WiggleClick(GEN_BTN_X, y2)
                Sleep 60
            }
        }
        y3 := clickY - (GEN_ROW_HEIGHT * 2)
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
            BuyAtCurrentScrollRange(GEN_BTN_Y_TOP, GEN_BTN_Y_BOT, maxBottomClicks)
            return
        }
        Send "{WheelUp}"
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
    MouseMove WIN_X+ASCEND_CON_X, WIN_Y+ASCEND_CON_Y-1, 2
    MouseMove WIN_X+ASCEND_CON_X, WIN_Y+ASCEND_CON_Y, 2
    Sleep 100
    SendInput "{LButton Down}"
    Sleep 50
    SendInput "{LButton Up}"
    Sleep 500
}

; =============================================
EquipPotato(rx, ry, eqX, eqY) {
    ActivateTarget()
    Send "8"
    Sleep 600
    WiggleClick(rx, ry)
    Sleep 200
    WiggleClick(eqX, eqY)
    Sleep 300
}

; =============================================
DoPrestige(loopStart) {
    global WIN_X, WIN_Y, PRESTIGE_NOW_X, PRESTIGE_NOW_Y, PRESTIGE_CON_X, PRESTIGE_CON_Y
    global INV_ENABLED, INV_PRES_X, INV_PRES_Y, INV_PRES_EQX, INV_PRES_EQY
    global INV_BON_X, INV_BON_Y, INV_BON_EQX, INV_BON_EQY
    global SHOP_ENABLED, lastShopTime

    elapsed   := A_TickCount - loopStart
    remaining := 29000 - 2200 - elapsed
    if (remaining > 0)
        Sleep remaining

    SellGolden()
    ; Shop runs here — after the very last sell of the loop, before prestiging
    if (SHOP_ENABLED && A_TickCount - lastShopTime >= 300000) {
        DoShop()
        lastShopTime := A_TickCount
    }
    if INV_ENABLED
        EquipPotato(INV_PRES_X, INV_PRES_Y, INV_PRES_EQX, INV_PRES_EQY)
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
    if INV_ENABLED
        EquipPotato(INV_BON_X, INV_BON_Y, INV_BON_EQX, INV_BON_EQY)
}

; =============================================
IsRockByName(rx, ry) {
    ; Scan the item name at the top of the slot (centered on button X)
    ; Use the live window size (not config) so it works even if the window is resized
    global WIN_X, WIN_Y, TARGET_HWND
    ToolTip  ; clear any previous tooltip so it can't overlap the scan area
    Sleep 80
    WinGetPos , , &ww, &wh, "ahk_id " TARGET_HWND
    scaleX := ww / 1920
    scaleY := wh / 1080
    x := WIN_X + rx - Round(240 * scaleX)
    y := WIN_Y + ry - Round(115 * scaleY)
    w := Round(420 * scaleX)
    h := Round(65 * scaleY)
    try {
        result := OCR.FromRect(x, y, w, h, "en")
        return InStr(result.Text, "Rock") > 0
    } catch {
        return false
    }
}

DoShop() {
    global WIN_X, WIN_Y, SHOP_BTNS, SHOP_SKIP_ROCKS
    ActivateTarget()
    Send "0"
    Sleep 2000
    for btn in SHOP_BTNS {
        if (btn["x"] = 0)
            continue
        if SHOP_SKIP_ROCKS && IsRockByName(btn["x"], btn["y"])
            continue
        WiggleClick(btn["x"], btn["y"])
        Sleep 300
    }
}

; =============================================
DoReroll() {
    global WIN_X, WIN_Y, REROLL_BTN_X, REROLL_BTN_Y, REROLL_CON_X, REROLL_CON_Y
    ActivateTarget()
    WiggleClick(REROLL_BTN_X, REROLL_BTN_Y)
    Sleep 300
    WiggleClick(REROLL_CON_X, REROLL_CON_Y)
}

; =============================================
IsTargetGenetic() {
    global WIN_X, WIN_Y, REROLL_SCAN_X, REROLL_SCAN_Y
    global REROLL_MYTHIC, REROLL_SECRET, REROLL_POTATO, REROLL_GENBON, REROLL_PRESPNT, REROLL_GOLDCON, REROLL_COSMIC
    ToolTip
    Sleep 50
    try {
        result := OCR.FromRect(WIN_X + REROLL_SCAN_X, WIN_Y + REROLL_SCAN_Y, 300, 65, "en")
        t := result.Text

        rarities := []
        if REROLL_MYTHIC
            rarities.Push("Mythic")
        if REROLL_SECRET
            rarities.Push("Secret")

        names := []
        if REROLL_POTATO
            names.Push("Potato Production")
        if REROLL_GENBON
            names.Push("Generator Bonus")
        if REROLL_PRESPNT
            names.Push("Prestige Points")
        if REROLL_GOLDCON {
            names.Push("Gold Conversion")
            names.Push("Golden Conversion")
        }
        if REROLL_COSMIC
            names.Push("Cosmic")

        if (rarities.Length > 0 && names.Length > 0) {
            for r in rarities
                for n in names
                    if InStr(t, r " " n)
                        return true
        } else if rarities.Length > 0 {
            for r in rarities
                if InStr(t, r)
                    return true
        } else if names.Length > 0 {
            for n in names
                if InStr(t, n)
                    return true
        }
    } catch {
        return false
    }
    return false
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

if (MODE = "shop") {
    loop {
        DoShop()
        Sleep 300000
    }
} else if (MODE = "reroll") {
    ActivateTarget()
    Send "7"
    Sleep 800
    loop {
        DoReroll()
        Sleep 5000
        if IsTargetGenetic() {
            ToolTip "Target genetic found!"
            break
        }
    }
} else {
    SetTimer RunLoop, -1
}
