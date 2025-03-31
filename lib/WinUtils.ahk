class WinUtils
{
    /*!
    Checks if a window is in fullscreen mode.
    ______________________________________________________________________________________________________________
    
    	Usage: isFullScreen()
    	Return: True/False
    
    	GitHub Repo: https://github.com/Nigh/isFullScreen
    */
    static IsFullScreen()
    {
        uid := WinExist("A")
        if (!uid) {
            Return False
        }
        wid := "ahk_id " uid
        c := WinGetClass(wid)
        If (uid = DllCall("GetDesktopWindow") Or (c = "Progman") Or (c = "WorkerW")) {
            Return False
        }
        WinGetClientPos(&cx, &cy, &cw, &ch, wid)
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
        Return False
    }
}