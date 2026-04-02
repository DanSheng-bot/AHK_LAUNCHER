class WinUtils
{
    /*!
    Checks if a window is in fullscreen mode.
    ______________________________________________________________________________________________________________
    
    	Usage: isFullScreen()
    	Return: True/False
    
    	GitHub Repo: https://github.com/Nigh/isFullScreen
    */
    static IsFullScreen(winTitle := "A")
    {
        ; 首先使用 SHQueryUserNotificationState 检查（更可靠地检测 D3D 全屏 / 演示模式）
        state := 0
        rc := DllCall("Shell32.dll\SHQueryUserNotificationState", "UInt*", &state)
        if (rc = 0) {
            ; USER_NOTIFICATION_STATE: 3 = QUNS_RUNNING_D3D_FULL_SCREEN, 4 = QUNS_PRESENTATION_MODE, 5 = QUNS_ACCEPTS_NOTIFICATIONS
            if (state = 3 || state = 4 || state = 2) ; 2 = QUNS_BUSY (可能正在运行全屏应用，但不确定是否为 D3D 全屏)
                return true
            else
                return false
        }

        ; 回退到原有的窗口占满显示器检测方法
        uid := WinExist(winTitle)
        if (!uid) {
            Return False
        }
        try {
            winPId := WinGetPID("ahk_id " uid)
            winIdList := WinGetList("ahk_pid " winPId)
            for winId in winIdList {
                c := WinGetClass(winId)
                If (uid = DllCall("GetDesktopWindow") Or (c = "Progman") Or (c = "WorkerW")) {
                    Return False
                }
                WinGetClientPos(&cx, &cy, &cw, &ch, winId)
                cl := cx
                ct := cy
                cr := cx + cw
                cb := cy + ch

                a := []
                loop MonitorGetCount()
                {
                    MonitorGet(A_Index, &Left, &Top, &Right, &Bottom)
                    a.Push({ l: Left, t: Top, r: Right, b: Bottom })
                }

                For , v in a
                {
                    if (cl == v.l and ct == v.t and cr == v.r and cb == v.b) {
                        Return True
                    }
                }
            }
        }
        return false
    }
}