#Requires AutoHotkey v2.0
#SingleInstance Force

class CustomTitleBarWindow {
    __New(Gui, ColorTheme := "000000", titleBarHeight := 31) {
        this.hwnd := Gui.hwnd
        this.Gui  := Gui
        this.titleBarHeight := titleBarHeight
        this.ColorTheme := ColorTheme
        this.Create()
    }


    Create() {
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.hwnd, "UInt", 20, "Ptr*", 1, "UInt", 4)
        this.ExtendFrameIntoClientArea()
        this.SetupMessageHandlers()
        WinGetClientPos(,,&Width, &Height, this.hwnd)
        this.title := this.Gui.AddText("x0 y0 w" Width " h" this.titleBarHeight " Background" this.ColorTheme)

        this.RefreshFrame()
        this.Gui.OnEvent("Size", (GuiObj, MinMax, Width, Height) => this.title.Move(0, 0, Width, this.titleBarHeight))
    }


    RefreshFrame() {
        WS_CAPTION := 0x00C00000
        
        style := DllCall("GetWindowLong", "Ptr", this.hwnd, "Int", -16, "Int")
        DllCall("SetWindowLong", "Ptr", this.hwnd, "Int", -16, "Int", style & ~WS_CAPTION)
        DllCall("SetWindowLong", "Ptr", this.hwnd, "Int", -16, "Int", style)
        
        DllCall("SetWindowPos", "Ptr", this.hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0027) ; SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER
    }


    ; MARGINS структура: left, right, top, bottom
    ExtendFrameIntoClientArea() {
        margins := Buffer(16), NumPut("Int", 0, "Int", 0, "Int", this.titleBarHeight, "Int", 0, margins)
        DllCall("dwmapi\DwmExtendFrameIntoClientArea", "Ptr", this.hwnd, "Ptr", margins)
    }


    SetupMessageHandlers() {
        OnMessage(0x0083, ObjBindMethod(this, "WM_NCCALCSIZE"))
        OnMessage(0x0084, ObjBindMethod(this, "WM_NCHITTEST"))
    }


    WM_NCCALCSIZE(wParam, lParam, msg, hwnd) {
        if (hwnd != this.hwnd)
            return

        if (wParam) {
            frameX := DllCall("GetSystemMetrics", "Int", 32)  ; SM_CXFRAME
            frameY := DllCall("GetSystemMetrics", "Int", 33)  ; SM_CYFRAME
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

        ; DWM (hover)
        lResult := Buffer(8, 0)
        if DllCall("dwmapi\DwmDefWindowProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr", lResult) {
            return NumGet(lResult, 0, "Ptr")
        }
        
        result := DllCall("DefWindowProc", "Ptr", hwnd, "UInt", msg, "UPtr", wParam, "Ptr", lParam, "Ptr")
        
        ; HTMINBUTTON=8, HTMAXBUTTON=9, HTCLOSE=20, HTLEFT=10, HTRIGHT=11, etc.
        if (result >= 10 && result <= 17) || (result >= 8 && result <= 9) || (result = 20)
            return result
        
        x := lParam & 0xFFFF
        y := (lParam >> 16) & 0xFFFF
        
        ; Convert to signed (for multi-monitors with negative coordinates)
        if (x > 0x7FFF)
            x := x - 0x10000
        if (y > 0x7FFF)
            y := y - 0x10000
        
        pt := Buffer(8)
        NumPut("Int", x, "Int", y, pt)
        DllCall("ScreenToClient", "Ptr", this.hwnd, "Ptr", pt)
        clientX := NumGet(pt, 0, "Int")
        clientY := NumGet(pt, 4, "Int")
        
        rect := Buffer(16)
        DllCall("GetClientRect", "Ptr", this.hwnd, "Ptr", rect)
        width := NumGet(rect, 8, "Int")
        height := NumGet(rect, 12, "Int")
        
        childPt := Buffer(8)
        NumPut("Int", x, "Int", y, childPt)
        child := DllCall("ChildWindowFromPoint", "Ptr", this.hwnd, "Int64", NumGet(childPt, 0, "Int64"), "Ptr")
        
        if (child && child != this.hwnd && child != this.title.hwnd)
            return 1  ; HTCLIENT
        
        borderSize := 8
        
        if (clientY < borderSize) {
            if (clientX < borderSize)
                return 13  ; HTTOPLEFT
            if (clientX > width - borderSize)
                return 14  ; HTTOPRIGHT
            return 12      ; HTTOP
        }
        
        if (clientY < this.titleBarHeight) {
            ; Примерно 46px на кнопку * 3 кнопки = 138px
            buttonAreaWidth := 138
            if (clientX > width - buttonAreaWidth) {
                buttonWidth := 46
                buttonIndex := (width - clientX) // buttonWidth
                
                if (buttonIndex = 0)
                    return 20  ; HTCLOSE
                else if (buttonIndex = 1)
                    return 9   ; HTMAXBUTTON
                else if (buttonIndex = 2)
                    return 8   ; HTMINBUTTON
            }
            return 2  ; HTCAPTION
        }
        return 1  ; HTCLIENT
    }
}