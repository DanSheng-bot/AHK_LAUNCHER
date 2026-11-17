/************************************************************************
 * @description 清理资源管理器图标缓存
 ***********************************************************************/

#Requires AutoHotkey v2.0
#NoTrayIcon

clearIconCache := MsgBox("是否删除 IconCache 后重启 Explorer？`n选择“否”将直接重启 Explorer。", "清理图标缓存", "YesNo") = "Yes"

ProcessClose("explorer.exe")

if clearIconCache {
    iconCache := "%localappdata%\Iconcache.db"
    if FileExist(iconCache)
        try FileDelete(iconCache)
        catch as err
            MsgBox("删除 IconCache 失败：" err.Message, "清理图标缓存", "Iconx")
}

Run("explorer.exe")