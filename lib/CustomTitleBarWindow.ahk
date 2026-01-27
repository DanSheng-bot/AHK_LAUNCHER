#Requires AutoHotkey v2.0
#SingleInstance Force

class CustomTitleBarWindow {
    /**
     * @param {GuiObj} gui
     * @param {Color} colorTheme - Header color in RGB format.
     * @param {Integer} titleBarHeight - Header height in pixels.
     * @param {Integer} showSystemMenu - Will the system menu be displayed when right-clicking on the title [true || false].
     * @param {Integer} winLimitMaximized - All windows in WinApi have title bars that shift by 7-8 pixels when resizing to their maximum size. This can be fixed:
     * Keep in mind that the top border of the window is the window's client area, meaning you can place controls there. Keep this in mind when selecting the `winLimitMaximized` flag.
     * ```ahk
     * winLimitMaximized := 0 ; If you set the value to "0" the window will behave as usual.
     * winLimitMaximized := 1 ; If you set the value to "1", then when the window is resized to its maximum size, the title will not go beyond the screen (including the border).
     * winLimitMaximized := 2 ; If you set the value to "2" the window will behave similarly to [winLimitMaximized := 1], except that the top border of the window will go off the screen.
     * ```
     * @param {Integer} fixTopBorder - If `fixTopBorderColor := false`, then the top border color will be equal to [`colorTheme` title bar color + color interpolation + opacity]. If `fixTopBorderColor := true`, then the border will have the system color [approximately "0x80000000"].
     */
    __New(gui, colorTheme := "000000", titleBarHeight := 31, showSystemMenu := true, winLimitMaximized := 1, fixTopBorderColor := false) {
        this.hwnd := gui.hwnd
        this.gui := gui
        this.titleBarHeight := titleBarHeight
        this.colorTheme := colorTheme
        this.showSystemMenu := showSystemMenu
        this.winLimitMaximized := winLimitMaximized
        this.fixTopBorderColor := fixTopBorderColor
        this.Create()
    }


    Create() {
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.hwnd, "UInt", 20, "Ptr*", 1, "UInt", 4)
        this.ExtendFrameIntoClientArea()
        this.SetupMessageHandlers()

        ;this.GetClientRect(&width, &height)
        ;this.title := this.gui.AddText("x0 y0 w" Width " h" this.titleBarHeight " Background" this.colorTheme)
        ;this.gui.OnEvent("Size", (GuiObj, MinMax, Width, Height) => this.title.Move(0, 0, Width, this.titleBarHeight))
        this.DrawTitle()
        this.RefreshFrame()
    }


    DrawTitle() {
        this.GetClientRect(&width, &height)
        this.title := this.gui.AddText("x0 y0 w" width " h" this.titleBarHeight " Background" this.colorTheme)
        if (this.fixTopBorderColor)
            borderTitle := this.gui.AddText("x0 y0 w" width " h1 Background000000")

        this.gui.OnEvent("Size", ReSizeEvent)
        if (this.fixTopBorderColor)
            borderTitle.Redraw()

        ReSizeEvent(GuiObj, MinMax, Width, Height) {
            this.title.Move(0, 0, Width, this.titleBarHeight)
            if (this.fixTopBorderColor)
                borderTitle.Move(0, 0, Width, 1)
        }
    }


    GetCoord(lParam, &x, &y, mode := "Screen") {
        x := (x := lParam & 0xFFFF) > 0x7FFF ? x - 0x10000 : x
        y := (y := (lParam >> 16) & 0xFFFF) > 0x7FFF ? y - 0x10000 : y

        if (mode = "Client") {
            pt := Buffer(8), NumPut("Int", x, "Int", y, pt)
            DllCall("ScreenToClient", "Ptr", this.hwnd, "Ptr", pt)
            x := NumGet(pt, 0, "Int"), y := NumGet(pt, 4, "Int")
        }
    }


    GetClientRect(&width, &height) {
        DllCall("GetClientRect", "Ptr", this.hwnd, "Ptr", rect := Buffer(16))
        width := NumGet(rect, 8, "Int"), height := NumGet(rect, 12, "Int")
    }


    ; Когда окно развёрнуто, часть уходит за экран
    GetMaximizedOffset() {
        frameY := DllCall("GetSystemMetrics", "Int", 33)   ; SM_CYFRAME
        padding := DllCall("GetSystemMetrics", "Int", 92)  ; SM_CXPADDEDBORDER
        return frameY + padding  ; ~7-8 пикселей
    }


    WinMaximizedOffsetWorkArea(width, height) {
        static minMaxOffset := this.GetMaximizedOffset()
        monitor := DllCall("MonitorFromWindow", "Ptr", this.hwnd, "UInt", 2) ; MONITOR_DEFAULTTONEAREST
        mi := Buffer(40), NumPut("UInt", 40, mi) ; cbSize
        DllCall("GetMonitorInfo", "Ptr", monitor, "Ptr", mi)

        workLeft := NumGet(mi, 20, "Int") ; rcWork.left
        workTop := NumGet(mi, 24, "Int") ; rcWork.top
        workRight := NumGet(mi, 28, "Int") ; rcWork.right
        workBottom := NumGet(mi, 32, "Int") ; rcWork.bottom

        workWidth := workRight - workLeft
        workHeight := workBottom - workTop
        threshold := minMaxOffset

        if (width >= workWidth - threshold && height >= workHeight - threshold) {
            this.gui.Move(workLeft - minMaxOffset, workTop -= (this.winLimitMaximized = 2) ? 1 : 0)
            return 1
        }
        return 0
    }


    RefreshFrame() {
        DllCall("SetWindowPos", "Ptr", this.hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0027) ; SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER
    }


    ExtendFrameIntoClientArea() {
        margins := Buffer(16), NumPut("Int", 0, "Int", 0, "Int", this.titleBarHeight, "Int", 0, margins)
        DllCall("dwmapi\DwmExtendFrameIntoClientArea", "Ptr", this.hwnd, "Ptr", margins)
    }


    SetupMessageHandlers() {
        OnMessage(0x0083, ObjBindMethod(this, "WM_NCCALCSIZE"))
        OnMessage(0x0084, ObjBindMethod(this, "WM_NCHITTEST"))
        if (this.showSystemMenu)
            OnMessage(0x00A5, ObjBindMethod(this, "WM_NCRBUTTONUP"))
    }


    WM_NCCALCSIZE(wParam, lParam, msg, hwnd) {
        if (hwnd != this.hwnd)
            return

        if (wParam) {
            frameX := DllCall("GetSystemMetrics", "Int", 32) ; SM_CXFRAME
            frameY := DllCall("GetSystemMetrics", "Int", 33) ; SM_CYFRAME
            padding := DllCall("GetSystemMetrics", "Int", 92) ; SM_CXPADDEDBORDER

            NumPut("Int", NumGet(lParam, 0, "Int") + frameX + padding, lParam, 0)   ; left
            NumPut("Int", NumGet(lParam, 4, "Int"), lParam, 4)                      ; top (без изменений)
            NumPut("Int", NumGet(lParam, 8, "Int") - frameX - padding, lParam, 8)   ; right
            NumPut("Int", NumGet(lParam, 12, "Int") - frameY - padding, lParam, 12) ; bottom
            return 0
        }
    }


    WM_NCHITTEST(wParam, lParam, msg, hwnd) {
        if (hwnd != this.hwnd)
            return

        ; DWM сначала для hover эффектов кнопок
        if DllCall("dwmapi\DwmDefWindowProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr", lResult := Buffer(8))
            return NumGet(lResult, 0, "Ptr")

        ; Клиентские координаты
        this.GetCoord(lParam, &clientX, &clientY, "Client")

        ; Размер окна (W / H)
        this.GetClientRect(&width, &height)

        ; Смещение GUI относительно рабочей области "A" монитора. Если окно развернуто, то весь заголовок HTCAPTION.
        if (this.winLimitMaximized) {
            if (this.WinMaximizedOffsetWorkArea(width, height)) {
                return clientY < this.titleBarHeight ? 2 : 1 ; HTCAPTION || HTCLIENT
            }
        }

        ; Размер области resize
        borderSize := 5
        switch {
            case clientY < borderSize && clientX < borderSize: return 13 ; HTTOPLEFT
            case clientY < borderSize && clientX > width - borderSize: return 14 ; HTTOPRIGHT
            case clientY < borderSize: return 12 ; HTTOP
            case clientY > height - borderSize && clientX < borderSize: return 16 ; HTBOTTOMLEFT
            case clientY > height - borderSize && clientX > width - borderSize: return 17 ; HTBOTTOMRIGHT
            case clientY > height - borderSize: return 15 ; HTBOTTOM
            case clientX < borderSize: return 10 ; HTLEFT
            case clientX > width - borderSize: return 11 ; HTRIGHT
            case clientY < this.titleBarHeight: return 2  ; HTCAPTION
        }
        return 1 ; HTCLIENT
    }


    WM_NCRBUTTONUP(wParam, lParam, msg, hwnd) {
        if (hwnd != this.hwnd)
            return

        static TPM_RETURNCMD := 0x0100
        static TPM_RIGHTBUTTON := 0x0002
        static WM_SYSCOMMAND := 0x0112
        static MF_ENABLED := 0x0000
        static MF_GRAYED := 0x0001
        static SC_RESTORE := 0xF120
        static SC_MOVE := 0xF010
        static SC_SIZE := 0xF000
        static SC_MINIMIZE := 0xF020
        static SC_MAXIMIZE := 0xF030
        static SC_CLOSE := 0xF060
        static HTCAPTION := 2

        if (wParam = HTCAPTION) {
            this.GetCoord(lParam, &x, &y, "Screen")
            hMenu := DllCall("GetSystemMenu", "Ptr", this.hwnd, "Int", 0, "Ptr")
            isMaximized := DllCall("IsZoomed", "Ptr", this.hwnd, "Int")
            isMinimized := DllCall("IsIconic", "Ptr", this.hwnd, "Int")
            DllCall("EnableMenuItem", "Ptr", hMenu, "UInt", SC_RESTORE, "UInt", (isMaximized || isMinimized) ? MF_ENABLED : MF_GRAYED)
            DllCall("EnableMenuItem", "Ptr", hMenu, "UInt", SC_MOVE, "UInt", isMaximized ? MF_GRAYED : MF_ENABLED)
            DllCall("EnableMenuItem", "Ptr", hMenu, "UInt", SC_SIZE, "UInt", isMaximized ? MF_GRAYED : MF_ENABLED)
            DllCall("EnableMenuItem", "Ptr", hMenu, "UInt", SC_MAXIMIZE, "UInt", isMaximized ? MF_GRAYED : MF_ENABLED)
            ;DllCall("EnableMenuItem", "Ptr", hMenu, "UInt", SC_CLOSE, "UInt", MF_ENABLED)
            cmd := DllCall("TrackPopupMenu", "Ptr", hMenu, "UInt", TPM_RETURNCMD | TPM_RIGHTBUTTON, "Int", x, "Int", y, "Int", 0, "Ptr", this.hwnd, "Ptr", 0, "UInt")

            if (cmd)
                PostMessage(WM_SYSCOMMAND, cmd, 0, , this.hwnd)
            return 0
        }
    }
}