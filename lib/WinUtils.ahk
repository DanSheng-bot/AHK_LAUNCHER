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
        uid := WinExist("A")
        if (!uid) {
            Return False
        }
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
        return false
    }
}