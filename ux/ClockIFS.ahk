/************************************************************************
 * @description 时钟,在全屏窗口中显示当前时间。
 ***********************************************************************/
#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-ExeName D:\Tools\ClockIFS1.0.5.exe
;@Ahk2Exe-SetMainIcon ..\res\clock.ico
#Include ..\lib\TextRender.ahk
#Include ..\lib\WinEvent.ahk
#Include ..\lib\WinUtils.ahk
;@Ahk2Exe-IgnoreBegin
;#NoTrayIcon
TraySetIcon("..\res\clock.ico") ; 设置托盘图标
;@Ahk2Exe-IgnoreEnd

Persistent true

A_IconTip := "全屏应用时钟"
A_TrayMenu.Delete()
A_TrayMenu.Add("设置", (*) => ConfigUi.show())
A_TrayMenu.Default := "1&"
A_TrayMenu.Add()
A_TrayMenu.Add("重载", (*) => Reload())
A_TrayMenu.Add("退出", (*) => ExitApp())

UpClockStatus() ; 启动时检查一次当前窗口状态

WinEvent.Active(WinActiveCallback) ; 监听窗口激活事件
WinEvent.Move(WinActiveCallback) ; 监听窗口移动事件

; 监听DPI变化事件
OnMessage(0x02E0, ObjBindMethod(Clock, "OnDpiChanged")) ; WM_DPICHANGED

WinActiveCallback(*) {
    SetTimer(UpClockStatus, 0) ; 删除之前的定时器
    SetTimer(UpClockStatus, -100) ; 设置定时器，100ms后执行UpClockStatus函数
}

UpClockStatus() {
    if (Clock.alwaysShow or WinUtils.IsFullScreen() or ConfigUi.isShow) ; 如果始终显示 或 当前窗口是全屏窗口
    {
        if (!Clock.isShow) ; 如果时钟当前未显示
            Clock.Show() ; 显示时钟
    }
    else
    { if (Clock.isShow) ; 如果时钟当前正在显示
            Clock.Hide() ; 隐藏时钟
    }
}

Class Clock {
    static dataDir := A_ScriptDir "\data"
    static configPath := A_ScriptDir "\data\ClockIFS.ini"
    static isShow := false

    static dpiScale := A_ScreenDPI / 96.0 ; DPI缩放因子
    static originalSize := IniRead(this.configPath, "Text", "FontSize", 52) ; 原始字体大小

    static trCfg := {
        top: 20, ; 窗口Y坐标
        color: "None", ; 背景色
    }
    static textStyle := {
        size: Round(this.originalSize * this.dpiScale), ; 字体大小
        color: "White",
        outline: { stroke: Round(1 * this.dpiScale), glow: Round(4 * this.dpiScale), tint: "Black" },
        dropShadow: { blur: "5px", color: "White", opacity: 0.5, size: Round(15 * this.dpiScale) }
    }
    static tr := TextRender()
    static trTimer := ObjBindMethod(this, "UpTime")
    static minutes := A_Min ; 记录当前分钟数
    static alwaysShow := IniRead(this.configPath, "General", "AlwaysShow", 0)
    static showSeconds := IniRead(this.configPath, "General", "ShowSeconds", 0)

    static __New() {
        if (!FileExist(this.dataDir)) {
            DirCreate(this.dataDir) ; 创建数据目录
        }
        this.tr.NoEvents() ; 不响应鼠标事件
        this.tr.NoActivate() ; 不激活窗口
        this.Show() ; 启动时显示一次，确保窗口被创建
        this.tr.TopMost() ; 窗口置顶
        this.tr.ClickThrough() ; 窗口穿透
    }

    ; 监听DPI变化
    static OnDpiChanged(wParam, lParam, msg, hwnd) {
        if (hwnd == this.tr.hwnd) {
            newDpi := wParam & 0xFFFF  ; 低16位是x DPI
            this.dpiScale := newDpi / 96.0
            ; 重新计算缩放参数
            this.trCfg.top := Round(20 * this.dpiScale)
            this.textStyle.size := Round(this.originalSize * this.dpiScale)
            this.textStyle.outline.stroke := Round(1 * this.dpiScale)
            this.textStyle.outline.glow := Round(4 * this.dpiScale)
            this.textStyle.dropShadow.size := Round(15 * this.dpiScale)
            if (this.isShow) {
                this.Render()
            }
        }
    }

    static Show() {
        this.minutes := A_Min ; 记录当前分钟数
        this.Render() ; 显示当前时间
        SetTimer(this.trTimer, 0) ; 删除之前的定时器
        SetTimer(this.trTimer, 1000) ; 设置定时器
    }

    static Hide() {
        this.tr.Clear() ; 清除显示的时间
        this.isShow := false
        SetTimer(this.trTimer, 0) ; 关闭定时器
    }

    static UpTime()
    {
        if (this.showSeconds || A_Min != this.minutes) ; 如果显示秒或分钟数发生变化
        {
            this.minutes := A_Min ; 更新分钟数
            this.Render() ; 更新显示的时间
        }
    }

    static Render() {
        format := this.showSeconds ? "HH:mm:ss" : "HH:mm"
        this.tr.Render(FormatTime(A_Now, format), this.trCfg, this.textStyle) ; 显示当前时间
        this.isShow := true
    }
}

Class ConfigUi {

    static isShow := false

    static __New() {
        this.ui := Gui()
        this.ui.Title := "ClockIFS设置"
        this.ui.SetFont("s10")

        ; 显示设置组
        this.ui.Add("GroupBox", "x10 y10 w280 h100", "显示设置")
        this.ui.Add("Text", "x20 y35 w80 h20", "字体大小:")
        this.fontSizeInput := this.ui.Add("Edit", "Number x100 y33 w50 h20", Clock.originalSize)
        this.fontSizeInput.OnEvent("Change", this.FontSizeInputChangeHandler.Bind(this))

        ; 时间格式设置组
        this.ui.Add("GroupBox", "x10 y120 w280 h80", "时间格式")
        this.alwaysShow := Clock.alwaysShow
        this.alwaysCheck := this.ui.Add("CheckBox", "x20 y145 w120 h20 " . (this.alwaysShow ? "Checked" : ""), "始终显示时间")
        this.alwaysCheck.OnEvent("Click", this.AlwaysShowChangeHandler.Bind(this))

        this.showSeconds := Clock.showSeconds
        this.secondsCheck := this.ui.Add("CheckBox", "x150 y145 w100 h20 " . (this.showSeconds ? "Checked" : ""), "显示秒")
        this.secondsCheck.OnEvent("Click", this.ShowSecondsChangeHandler.Bind(this))

        this.ui.OnEvent("Close", this.OnClose.Bind(this))
    }

    static show() {
        this.ui.Show("w320 h220")
        Clock.tr.ClickThrough() ; 进入设置界面时关闭穿透，方便拖动窗口
        Clock.tr.OnLeftMouseDown((this) => this.EventMoveWindowStorePosition())
        this.isShow := true
    }

    static OnClose(*) {
        Clock.tr.NoEvents()
        Clock.tr.OnLeftMouseDown()
        Clock.tr.ClickThrough() ; 关闭设置界面时重新开启穿透
        this.isShow := false
    }

    static FontSizeInputChangeHandler(Ctrl, *) {
        Clock.originalSize := this.fontSizeInput.Value
        Clock.textStyle.size := Round(Clock.originalSize * Clock.dpiScale)
        IniWrite(Clock.originalSize, Clock.configPath, "Text", "FontSize")
        Clock.Show()
    }

    static AlwaysShowChangeHandler(Ctrl, *) {
        Clock.alwaysShow := Ctrl.Value
        IniWrite(Clock.alwaysShow ? 1 : 0, Clock.configPath, "General", "AlwaysShow")
        UpClockStatus()
    }

    static ShowSecondsChangeHandler(Ctrl, *) {
        Clock.showSeconds := Ctrl.Value
        IniWrite(Clock.showSeconds ? 1 : 0, Clock.configPath, "General", "ShowSeconds")
        Clock.Show()
    }

}