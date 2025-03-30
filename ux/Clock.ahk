/************************************************************************
 * @description 时钟,这个脚本是一个简单的时钟程序，在全屏窗口中显示当前时间和日期。
 ***********************************************************************/

#Requires AutoHotkey v2.0
#NoTrayIcon
#Include ..\lib\TextRender.ahk

trCfg := {
    Y: 20, ; 窗口Y坐标
    c: "None", ; 背景色
}
textStyle := "s:52.7 color:White outline:(stroke:1 glow:4 tint:Black) dropShadow:(blur:5px color:White opacity:0.5 size:15)"
tr := TextRender()
tr.None() ; 无事件
tr.ClickThrough() ; 点击穿透
tr.NoActivate() ; 不激活窗口
minutes := A_Min ; 记录当前分钟数
tr.Render(FormatTime(A_Now, "HH:mm"), trCfg, textStyle) ; 显示当前时间

SetTimer(UpTime, 1000) ; 每秒更新一次

UpTime()
{
    global minutes
    if (A_Min != minutes) ; 如果分钟数发生变化
    {
        minutes := A_Min ; 更新分钟数
        tr.Clear()
        tr.Render(FormatTime(A_Now, "HH:mm"), trCfg, textStyle) ; 更新显示的时间
    }
}