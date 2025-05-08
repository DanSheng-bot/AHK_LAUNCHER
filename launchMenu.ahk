#Requires AutoHotkey v2.0
#SingleInstance Ignore
#Include lib\AppUtils.ahk
#Include lib\DirTreeMenu.ahk
#Include lib\LauncherJumpList.ahk
#Include lib\ThemeUtils.ahk
#Include lib\WatchFolder.ahk
#Include lib\DescriptionUtils.ahk
#Include lib\AhkScriptUtils.ahk

AppUtils.SetCurrentProcessExplicitAppUserModelID(AppUserModelID)
;@Ahk2Exe-SetMainIcon res\launcher.ico
TraySetIcon("res\launcher.ico")
KeyHistory(0)
CoordMode "Mouse", "Screen"
CoordMode "Menu", "Screen"
DetectHiddenWindows True
Persistent true

launcherLnk := A_ScriptDir "\launchDir.lnk"

if !FileExist(launcherLnk) {
    AppUtils.SelectLaunchDir()
    if !FileExist(launcherLnk) {
        ExitApp
    }
}

try {
    FileGetShortcut launcherLnk, &launcherPath
} catch {
    try FileDelete(launcherLnk)
    MsgBox("导航文件夹出错,请重新选择!")
    ExitApp
}

showOnLoaded := false
InitArg()

WM_INITMENUPOPUP := 0x0117
WM_MENURBUTTONUP := 0x0122
WM_UNINITMENUPOPUP := 0x0125
WM_MENUSELECT := 0x11F ;当用户选择菜单项时发送到菜单的所有者窗口。
OnMessage(WM_INITMENUPOPUP, MenuShowCallback)
OnMessage(WM_MENURBUTTONUP, MenuRButtonUpCallback)
OnMessage(WM_UNINITMENUPOPUP, MenuUnPopupCallback)
OnMessage(WM_MENUSELECT, MenuSelectCallback)
OnMessage(AppMsgNum, AppMsgCallback)

A_IconTip := "导航菜单"
A_TrayMenu.Delete()
A_TrayMenu.Add("Config", (*) => Run(A_AhkPath " Config.ahk"))
A_TrayMenu.Default := "1&"
A_TrayMenu.Add("Reload", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Add()
A_TrayMenu.Add("SelectLaunchDir", SelectLaunchDir)
A_TrayMenu.Add("OpenLaunchDir", (*) => Run(launcherLnk))
A_TrayMenu.Add("OpenAppDir", (*) => Run("explorer " A_ScriptDir))
A_TrayMenu.Add()

dpiZom := A_ScreenDPI / 96
IconSize := Integer(32 * dpiZom)

BuildLauncherMenu()

if showOnLoaded {
    ShowLauncherMenu()
}

watchLauncherDir := WatchFolder(launcherPath, "LaunchChangeCallback", true, 0x00000013)
Run '"' A_AhkPath '" "' A_ScriptDir '\Autorun.ahk"'

return

InitArg() {
    for arg in A_Args {
        if arg = "show" {
            global showOnLoaded
            showOnLoaded := true
            return
        }
    }
}

BuildLauncherMenu() {
    try {
        launchTree := DirTreeMenu.getDirTree(launcherPath)
    } catch TimeoutError as err {
        MsgBox(err.Message)
        return
    }

    global launcherMenu
    global scriptMenu
    launcherMenu := DirTreeMenu.createMenu(launchTree, IconSize, LauncherMenuCallback)

    loadAhkScript := IniRead(configIni, "config", "loadAhkScript", 0)

    if loadAhkScript {
        scriptMenu := Menu()
        scriptMenu.DefineProp("data", { Value: Array() })

        loop files A_ScriptDir "\ux\*.ahk", "F" {
            menuName := SubStr(A_LoopFileName, 1, StrLen(A_LoopFileName) - 4)
            scriptMenu.Add(menuName, LauncherMenuCallback)
            scriptMenu.data.Push({ path: A_LoopFileFullPath, name: menuName })
        }

        launcherMenu.Add("AhkScript", scriptMenu)
        launcherMenu.SetIcon("AhkScript", A_AhkPath, 1, IconSize)
    }

    A_TrayMenu.Add("Launcher", launcherMenu)
}

AppMsgCallback(wParam, lParam, *) {
    switch wParam {
        case 1111:
            ShowLauncherMenu()
        case 1112:
            BuildLauncherMenu()
    }
}

ShowLauncherMenu() {
    if !IsSet(launcherMenu) {
        global showOnLoaded
        showOnLoaded := true
        return
    }

    global dpiZom
    global IconSize
    nowDpiZom := A_ScreenDPI / 96
    if nowDpiZom != dpiZom {
        dpiZom := nowDpiZom
        IconSize := Integer(32 * dpiZom)
        BuildLauncherMenu()
        ShowLauncherMenu()
        return
    }

    MouseGetPos(&mouseX, &mouseY)
    ; default menu pos to mouse pos
    menu_x := mouseX, menu_y := mouseY
    ; 获取活动区域
    MonitorGetWorkArea(, &wLeft, &wTop, &wRight, &wBottom)

    menuW := 80 * dpiZom

    if mouseX > menuW {
        menu_x := mouseX - menuW
    }

    if mouseY > wBottom {
        menu_y := wBottom
    }
    launcherMenu.Show(menu_x, menu_y)
}

MenuShowCallback(wParam, lParam, *) {
    if wParam = A_TrayMenu.Handle {
        ThemeUtils.darkMenuMode(ThemeUtils.SysIsDarkMode)
    } else if IsSet(launcherMenu) && wParam = launcherMenu.Handle {
        ThemeUtils.darkMenuMode(ThemeUtils.SysIsDarkMode)
    } else if IsSet(scriptMenu) && wParam = scriptMenu.Handle {
        for item in scriptMenu.data {
            if WinExist(item.path " - AutoHotkey") {
                scriptMenu.SetIcon(item.name, "%SystemRoot%\system32\shell32.dll", 295)
            } else {
                scriptMenu.SetIcon(item.name, "*")
            }
        }
    }
}

LauncherMenuCallback(ItemName, ItemPos, MyMenu) {
    rPath := MyMenu.data[ItemPos].path
    if !DirExist("recent") {
        DirCreate("recent")
    }
    if rPath ~= ".*?.ahk$" {
        Run('"' A_AhkPath '" "' rPath '"')
        return
    }
    try {
        Run(rPath)
        FileCreateShortcut(rPath, "recent\" ItemName)
    } catch {
        FileGetShortcut(rPath, &outTarget, &outWrkDir, &outArgs)
        try {
            Run(outTarget " " outArgs, outWrkDir)
            FileCreateShortcut(outTarget, "recent\" ItemName, outWrkDir, outArgs)
        } catch {
            try {
                pf64 := EnvGet("ProgramW6432")
                _outTarget64 := StrReplace(outTarget, A_ProgramFiles, pf64, , , 1)
                Run(_outTarget64 " " outArgs, outWrkDir)
                FileCreateShortcut(_outTarget64, "recent\" ItemName, outWrkDir, outArgs)
            } catch {
                MsgBox("运行" rPath "失败." A_LastError)
            }
        }
    }
    LauncherJumpList.up(AppUserModelID)
}

MenuSelectCallback(wParam, lParam, *) {
    HideToolTip()
}

MenuRButtonUpCallback(wParam, lParam, *) {
    menuItem := DirTreeMenu.findMenu(launcherMenu.data, lParam, wParam)
    if menuItem {
        path := menuItem.path
        if path ~= ".*?.lnk$" {
            FileGetShortcut path, &path
        }
        if GetKeyState("Control", "P") {
            Run("explorer /select,`"" menuItem.path "`"")
        } else {
            ToolTip(path "`n按住Ctrl右击打开文件夹")
        }
    } else if lParam = scriptMenu.Handle {
        ahkPath := scriptMenu.data[wParam + 1].path
        if GetKeyState("Ctrl", "P") {
            AhkScript.Exit(ahkPath)
            scriptMenu.SetIcon(wParam + 1 "&", "*")
        } else {
            description := DescriptionUtils.getAhkDescription(ahkPath)
            ToolTip(description "`n按住Ctrl右击结束脚本")
        }
    }
}

MenuUnPopupCallback(wParam, lParam, *) {
    HideToolTip()
}

LaunchChangeCallback(path, notifications) {
    SetTimer(BuildLauncherMenu, -1000)
}

SelectLaunchDir(*) {
    if AppUtils.SelectLaunchDir() {
        Reload
    }
}

HideToolTip(*) {
    ToolTip()
}