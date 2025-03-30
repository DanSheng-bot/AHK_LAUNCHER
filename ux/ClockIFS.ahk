/************************************************************************
 * @description 时钟,在全屏窗口中显示当前时间。
 ***********************************************************************/
#Requires AutoHotkey v2.0
#NoTrayIcon
#Include ..\lib\TextRender.ahk

Clock.Show()

Class Clock {

    static trCfg := {
        Y: 20, ; 窗口Y坐标
        c: "None", ; 背景色
    }
    static textStyle := "s:52.7 color:White outline:(stroke:1 glow:4 tint:Black) dropShadow:(blur:5px color:White opacity:0.5 size:15)"
    static tr := TextRender()
    static trTimer := ObjBindMethod(this, "UpTime")
    static minutes := A_Min ; 记录当前分钟数

    static __New() {
        this.tr.None() ; 无事件
        this.tr.ClickThrough() ; 点击穿透
        this.tr.NoActivate() ; 不激活窗口
    }

    static Show() {
        this.minutes := A_Min ; 记录当前分钟数
        this.tr.Render(FormatTime(A_Now, "HH:mm"), this.trCfg, this.textStyle) ; 显示当前时间
        SetTimer(this.trTimer, 1000) ; 每秒更新一次
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