/************************************************************************
 * @description 时钟,在全屏窗口中显示当前时间。
 ***********************************************************************/
#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
#Include ..\lib\TextRender.ahk
#Include ..\lib\WinEvent.ahk
#Include ..\lib\WinUtils.ahk

WinEvent.Active(WinActiveCallback) ; 监听窗口激活事件

WinActiveCallback(*) {
    SetTimer(UpClockStatus, 100) ; 设置定时器，100ms后执行UpClockStatus函数
}

UpClockStatus() {
    if (WinUtils.IsFullScreen()) ; 如果当前窗口是全屏窗口
    {
        Clock.Show() ; 显示时钟
    }
    else
    {
        Clock.Hide() ; 隐藏时钟
    }
}

Class Clock {

    static trCfg := {
        Y: 20, ; 窗口Y坐标
        c: "None", ; 背景色
    }
    static textStyle := { s: 52.7,
        color: "White",
        outline: { stroke: 1, glow: 4, tint: "Black" },
        dropShadow: { blur: "5px", color: "White", opacity: 0.5, size: 15 }
    }
    static tr := TextRender()
    static trTimer := ObjBindMethod(this, "UpTime")
    static minutes := A_Min ; 记录当前分钟数

    static __New() {
        this.tr.None() ; 无事件
        this.tr.ClickThrough() ; 点击穿透
        this.tr.NoActivate() ; 不激活窗口
        this.tr.AlwaysOnTop() ; 始终在最上层
    }

    static Show() {
        this.minutes := A_Min ; 记录当前分钟数
        this.tr.Render(FormatTime(A_Now, "HH:mm"), this.trCfg, this.textStyle) ; 显示当前时间
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
            this.tr.Clear()
            this.tr.Render(FormatTime(A_Now, "HH:mm"), this.trCfg, this.textStyle) ; 更新显示的时间
        }
    }
}