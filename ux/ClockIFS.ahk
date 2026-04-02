/************************************************************************
 * @description 时钟,在全屏窗口中显示当前时间。
 ***********************************************************************/
#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-ExeName %A_ScriptDir%\program\ClockIFS.exe
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
A_TrayMenu.Add("退出", (*) => ExitApp())

UpClockStatus() ; 启动时检查一次当前窗口状态

WinEvent.Active(WinActiveCallback) ; 监听窗口激活事件
WinEvent.Move(WinActiveCallback) ; 监听窗口移动事件

WinActiveCallback(*) {
    SetTimer(UpClockStatus, 0) ; 删除之前的定时器
    SetTimer(UpClockStatus, -100) ; 设置定时器，100ms后执行UpClockStatus函数
}

UpClockStatus() {
    if (Clock.alwaysShow or WinUtils.IsFullScreen() or ConfigUi.isShow) ; 如果始终显示 或 当前窗口是全屏窗口
    {
        Clock.Show() ; 显示时钟 
    }
    else
    {
        Clock.Hide() ; 隐藏时钟
    }
}

Class Clock {

    static configPath := A_ScriptDir "\data\ClockIFS.ini"

    static trCfg := {
        top: 20, ; 窗口Y坐标
        color: "None", ; 背景色
    }
    static textStyle := {
        size: IniRead(this.configPath, "Text", "FontSize", 52), ; 字体大小
        font: IniRead(this.configPath, "Text", "FontFamily", "微软雅黑"), ; 字体
        color: "White",
        outline: { stroke: 1, glow: 4, tint: "Black" },
        dropShadow: { blur: "5px", color: "White", opacity: 0.5, size: 15 }
    }
    static tr := TextRender()
    static trTimer := ObjBindMethod(this, "UpTime")
    static minutes := A_Min ; 记录当前分钟数
    static alwaysShow := IniRead(this.configPath, "General", "AlwaysShow", 0)

    static __New() {
        this.tr.NoEvents() ; 不响应鼠标事件
        this.tr.ClickThrough() ; 点击穿透
        this.tr.NoActivate() ; 不激活窗口
    }

    static Show() {
        this.minutes := A_Min ; 记录当前分钟数
        this.tr.Render(FormatTime(A_Now, "HH:mm"), this.trCfg, this.textStyle) ; 显示当前时间
        this.tr.TopMost() ; 窗口置顶
        SetTimer(this.trTimer, 1000) ; 每秒更新一次
    }

    static Hide() {
        this.tr.Clear() ; 清除显示的时间
        SetTimer(this.trTimer, 0) ; 关闭定时器
    }

    static UpTime()
    {
        if (A_Min != this.minutes) ; 如果分钟数发生变化
        {
            this.minutes := A_Min ; 更新分钟数
            this.tr.Render(FormatTime(A_Now, "HH:mm"), this.trCfg, this.textStyle) ; 更新显示的时间
        }
    }
}

Class ConfigUi {

    static isShow := false

    static __New() {
        this.ui := Gui()
        this.ui.Title := "ColckIFS设置"
        this.ui.Add("Text", "x20 y12 w60 h20", "字体大小:")
        this.fontSizeInput := this.ui.Add("Edit", "Number x80 y10 w50 h20", Clock.textStyle.size)
        this.fontSizeInput.OnEvent("Change", this.FontSizeInputChangeHandler.Bind(this))
        ; 始终显示时间选项
        this.alwaysShow := Clock.alwaysShow
        this.alwaysCheck := this.ui.Add("CheckBox", "x20 y40 w200 h20 " . (this.alwaysShow ? "Checked" : ""), "始终显示时间")
        this.alwaysCheck.OnEvent("Click", this.AlwaysShowChangeHandler.Bind(this))
        this.ui.OnEvent("Close", this.OnClose.Bind(this))
    }

    static show() {
        this.ui.Show("w620 h420")
        this.isShow := true
    }

    static OnClose(*) {
        this.isShow := false
    }

    static FontSizeInputChangeHandler(Ctrl, *) {
        Clock.textStyle.size := this.fontSizeInput.Value
        IniWrite(Clock.textStyle.size, Clock.configPath, "Text", "FontSize")
        Clock.Show()
    }

    static AlwaysShowChangeHandler(Ctrl, *) {
        Clock.alwaysShow := Ctrl.Value
        IniWrite(Clock.alwaysShow ? 1 : 0, Clock.configPath, "General", "AlwaysShow")
        UpClockStatus()
    }

}