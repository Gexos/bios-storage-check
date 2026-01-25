#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=bios-storage-check_bios.ico
#AutoIt3Wrapper_Outfile=bios-storage-check.exe
#AutoIt3Wrapper_Outfile_x64=bios-storage-check_x64.exe
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Comment=Best-effort BIOS storage mode inference (AHCI vs RST/VMD) + disk bus detection (NVMe vs SATA)
#AutoIt3Wrapper_Res_Description=bios-storage-check
#AutoIt3Wrapper_Res_Fileversion=6.2.1.0
#AutoIt3Wrapper_Res_ProductName=bios-storage-check
#AutoIt3Wrapper_Res_ProductVersion=6.2.1.0
#AutoIt3Wrapper_Res_CompanyName=Giorgos Xanthopoulos (gexos)
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****


#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <MsgBoxConstants.au3>

#include <GDIPlus.au3>
#include <WinAPISys.au3>
#include <WinAPIGdi.au3>
Opt("MustDeclareVars", 1)

; ---------------- App constants ----------------
Global Const $APP_NAME   = "BIOS Storage Mode + Disk Bus Info (Best-effort)"
Global Const $APP_VER    = "v6.2.1"
Global Const $CREDITS_PNG = "credits.png"
Global Const $AUTHOR     = "Giorgos Xanthopoulos (aka gexos)"
Global Const $LICENSETXT = "Open-source (see project repository)"
Global Const $GITHUB_URL = "https://github.com/Gexos/bios-storage-check"
Global Const $BLOG_URL   = "https://gexos.org"
Global Const $HELP_FILE  = @ScriptDir & "\help.txt"

Global $g_sReport = _BuildReport()

; ---------------- GUI ----------------
Local $hGUI = GUICreate($APP_NAME & " " & $APP_VER, 980, 640, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU, $WS_MINIMIZEBOX))
GUISetFont(11, 800, 0, "Segoe UI")
Local $idEdit = GUICtrlCreateEdit($g_sReport, 10, 10, 960, 545, BitOR($ES_READONLY, $ES_MULTILINE, $WS_VSCROLL, $ES_AUTOVSCROLL))
GUICtrlSetFont($idEdit, 9, 400, 0, "Consolas")

; ---------------- Menus (replaces bottom buttons) ----------------
Local $mFile = GUICtrlCreateMenu("&File")
Local $miCopy     = GUICtrlCreateMenuItem("&Copy Output	Ctrl+C", $mFile)
Local $miSaveTxt  = GUICtrlCreateMenuItem("Save as &TXT...", $mFile)
Local $miSaveHtml = GUICtrlCreateMenuItem("Save as &HTML...", $mFile)
Local $miSaveJson = GUICtrlCreateMenuItem("Save as &JSON...", $mFile)
Local $miSaveCsv  = GUICtrlCreateMenuItem("Save as &CSV...", $mFile)
GUICtrlCreateMenuItem("", $mFile)
Local $miRefresh  = GUICtrlCreateMenuItem("&Refresh	F5", $mFile)
GUICtrlCreateMenuItem("", $mFile)
Local $miExit     = GUICtrlCreateMenuItem("E&xit", $mFile)

Local $mHelp = GUICtrlCreateMenu("&Help")
Local $miHelp   = GUICtrlCreateMenuItem("&Help", $mHelp)
Local $miGitHub = GUICtrlCreateMenuItem("Open &GitHub", $mHelp)
Local $miBlog   = GUICtrlCreateMenuItem("Open &Blog", $mHelp)
GUICtrlCreateMenuItem("", $mHelp)
Local $miAbout  = GUICtrlCreateMenuItem("&About", $mHelp)

; Keyboard shortcuts
Local $aAccel[3][2] = [["^c", $miCopy], ["{F5}", $miRefresh], ["^s", $miSaveTxt]]
GUISetAccelerators($aAccel, $hGUI)

GUISetState(@SW_SHOW)

While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE, $miExit
            ExitLoop

        Case $miCopy
            ClipPut(GUICtrlRead($idEdit))
            MsgBox($MB_ICONINFORMATION, "Copied", "Output copied to clipboard.")

        Case $miSaveTxt
            _SaveReportAsTxt(GUICtrlRead($idEdit))

        Case $miSaveHtml
            _SaveReportAsHtml(GUICtrlRead($idEdit))

        Case $miSaveJson
            _SaveReportAsJson(GUICtrlRead($idEdit))

        Case $miSaveCsv
            _SaveReportAsCsv(GUICtrlRead($idEdit))

        Case $miRefresh
            $g_sReport = _BuildReport()
            GUICtrlSetData($idEdit, $g_sReport)

        Case $miHelp
            _OpenHelpFile()

        Case $miGitHub
            ShellExecute($GITHUB_URL)

        Case $miBlog
            ShellExecute($BLOG_URL)

        Case $miAbout
            _ShowAbout($hGUI)
    EndSwitch
WEnd

; ---------------- Save with better default filename ----------------
Func _SaveReportAsTxt($reportText)
    Local $defaultName = _DefaultReportFileName()
    Local $pathSave = FileSaveDialog("Save report as TXT", @ScriptDir, "Text files (*.txt)", 16, $defaultName)
    If @error Or $pathSave = "" Then Return

    Local $h = FileOpen($pathSave, 2 + 8) ; overwrite + UTF-8
    If $h = -1 Then
        MsgBox($MB_ICONERROR, "Error", "Cannot write file:" & @CRLF & $pathSave)
        Return
    EndIf
    FileWrite($h, $reportText)
    FileClose($h)
    MsgBox($MB_ICONINFORMATION, "Saved", "Saved to:" & @CRLF & $pathSave)
EndFunc


; ---------------- Extra export formats (HTML / JSON / CSV) ----------------

Func _SaveReportAsHtml($reportText)
    Local $defaultName = StringReplace(_DefaultReportFileName(), ".txt", ".html")
    Local $pathSave = FileSaveDialog("Save report as HTML", @ScriptDir, "HTML files (*.html)", 16, $defaultName)
    If @error Or $pathSave = "" Then Return

    Local $title = $APP_NAME & " " & $APP_VER
    Local $body = "<!doctype html>" & @CRLF & _
                  "<html><head><meta charset=""utf-8"">" & _
                  "<meta name=""viewport"" content=""width=device-width,initial-scale=1"">" & _
                  "<title>" & _HtmlEscape($title) & "</title>" & _
                  "<style>body{font-family:Segoe UI,Arial,sans-serif;margin:18px;background:#0b1220;color:#e9eef7;} " & _
                  "h1{font-size:18px;margin:0 0 12px 0;} pre{white-space:pre-wrap;word-break:break-word;" & _
                  "background:#0f1a2e;border:1px solid rgba(255,255,255,.14);padding:14px;border-radius:10px;" & _
                  "font-family:Consolas,ui-monospace,monospace;font-size:13px;line-height:1.35}</style>" & _
                  "</head><body>" & _
                  "<h1>" & _HtmlEscape($title) & "</h1>" & _
                  "<pre>" & _HtmlEscape($reportText) & "</pre>" & _
                  "</body></html>"

    _WriteUtf8File($pathSave, $body)
    MsgBox($MB_ICONINFORMATION, "Saved", "Saved to:" & @CRLF & $pathSave)
EndFunc

Func _SaveReportAsJson($reportText)
    Local $defaultName = StringReplace(_DefaultReportFileName(), ".txt", ".json")
    Local $pathSave = FileSaveDialog("Save report as JSON", @ScriptDir, "JSON files (*.json)", 16, $defaultName)
    If @error Or $pathSave = "" Then Return

    Local $json = _BuildJsonPayloadExpanded($reportText)
    _WriteUtf8File($pathSave, $json)
    MsgBox($MB_ICONINFORMATION, "Saved", "Saved to:" & @CRLF & $pathSave)
EndFunc

Func _SaveReportAsCsv($reportText)
    Local $defaultName = StringReplace(_DefaultReportFileName(), ".txt", ".csv")
    Local $pathSave = FileSaveDialog("Save report as CSV", @ScriptDir, "CSV files (*.csv)", 16, $defaultName)
    If @error Or $pathSave = "" Then Return

    Local $csv = _BuildCsvLines($reportText)
    _WriteUtf8File($pathSave, $csv)
    MsgBox($MB_ICONINFORMATION, "Saved", "Saved to:" & @CRLF & $pathSave)
EndFunc

Func _WriteUtf8File($path, $text)
    Local $h = FileOpen($path, 2 + 8) ; overwrite + UTF-8
    If $h = -1 Then
        MsgBox($MB_ICONERROR, "Error", "Cannot write file:" & @CRLF & $path)
        Return
    EndIf
    FileWrite($h, $text)
    FileClose($h)
EndFunc

Func _HtmlEscape($s)
    $s = StringReplace($s, "&", "&amp;")
    $s = StringReplace($s, "<", "&lt;")
    $s = StringReplace($s, ">", "&gt;")
    $s = StringReplace($s, '"', "&quot;")
    $s = StringReplace($s, "'", "&#39;")
    Return $s
EndFunc

Func _JsonEscape($s)
    ; Basic JSON escaping for strings
    $s = StringReplace($s, "\", "\\")
    $s = StringReplace($s, '"', '\"')
    $s = StringReplace($s, @CRLF, "\n")
    $s = StringReplace($s, @CR, "\n")
    $s = StringReplace($s, @LF, "\n")
    Return $s
EndFunc

Func _JsonBool($b)
    If $b Then Return "true"
    Return "false"
EndFunc

Func _BuildCsvLines($reportText)
    ; Simple CSV: one column "Line" with each report line (max compatibility)
    Local $csv = "Line" & @CRLF
    Local $lines = StringSplit($reportText, @CRLF, 1)
    Local $i
    For $i = 1 To $lines[0]
        Local $ln = $lines[$i]
        $ln = StringReplace($ln, '"', '""')
        $csv &= '"' & $ln & '"' & @CRLF
    Next
    Return $csv
EndFunc

Func _BuildJsonPayloadExpanded($reportText)
    ; Expanded JSON: metadata + signals + controllers + drivers + disks + full report text
    Local $ts = @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & _
                " " & StringFormat("%02d", @HOUR) & ":" & StringFormat("%02d", @MIN) & ":" & StringFormat("%02d", @SEC)

    Local $json = "{"
    $json &= '"appName":"' & _JsonEscape($APP_NAME) & '",'
    $json &= '"appVersion":"' & _JsonEscape($APP_VER) & '",'
    $json &= '"generated":"' & _JsonEscape($ts) & '",'
    $json &= '"computer":"' & _JsonEscape(@ComputerName) & '",'
    $json &= '"user":"' & _JsonEscape(@UserName) & '",'
    $json &= '"os":"' & _JsonEscape(@OSVersion & " / " & @OSBuild & " (" & @OSArch & ")") & '",'
    $json &= '"topSummary":"' & _JsonEscape(_TopSummary()) & '",'
    $json &= '"signals":' & _GetSignalsJson() & ","
    $json &= '"controllers":' & _GetControllersJsonArray() & ","
    $json &= '"drivers":' & _GetDriversJsonArray() & ","
    $json &= '"disks":' & _GetDisksJsonArray() & ","
    $json &= '"reportText":"' & _JsonEscape($reportText) & '"'
    $json &= "}"
    Return $json
EndFunc

Func _GetSignalsJson()
    Local $hasVMD = False, $hasRstPremium = False, $hasRaidController = False
    Local $hasIAStor = False, $hasStorAHCI = False, $hasAnyDiskBusRaid = False

    Local $oStorage = ObjGet("winmgmts:\\.\root\Microsoft\Windows\Storage")
    If Not @error And IsObj($oStorage) Then
        Local $col = $oStorage.ExecQuery("SELECT BusType FROM MSFT_PhysicalDisk")
        If Not @error And IsObj($col) Then
            Local $obj
            For $obj In $col
                If Number($obj.BusType) = 8 Then $hasAnyDiskBusRaid = True
            Next
        EndIf
    EndIf

    Local $oWMI = ObjGet("winmgmts:\\.\root\cimv2")
    If Not @error And IsObj($oWMI) Then
        Local $col2 = $oWMI.ExecQuery("SELECT Name, Service, PNPClass FROM Win32_PnPEntity WHERE (PNPClass='HDC' OR PNPClass='SCSIAdapter' OR PNPClass='System')")
        If Not @error And IsObj($col2) Then
            Local $x
            For $x In $col2
                Local $nameL = StringLower(_Safe($x.Name))
                Local $svcL  = StringLower(_Safe($x.Service))

                If StringInStr($nameL, "vmd") Or StringInStr($nameL, "volume management device") Then $hasVMD = True
                If StringInStr($nameL, "rst premium") Then $hasRstPremium = True
                If StringInStr($nameL, "raid controller") Or (StringInStr($nameL, "raid") And Not StringInStr($nameL, "hydra")) Then $hasRaidController = True

                If StringInStr($svcL, "iastor") Then $hasIAStor = True
                If $svcL = "storahci" Then $hasStorAHCI = True
            Next
        EndIf
    EndIf

    Local $j = "{"
    $j &= '"VMD":' & _JsonBool($hasVMD) & ","
    $j &= '"RSTPremium":' & _JsonBool($hasRstPremium) & ","
    $j &= '"RaidControllerName":' & _JsonBool($hasRaidController) & ","
    $j &= '"iaStorServiceSeen":' & _JsonBool($hasIAStor) & ","
    $j &= '"storahciServiceSeen":' & _JsonBool($hasStorAHCI) & ","
    $j &= '"anyDiskBusTypeRAID":' & _JsonBool($hasAnyDiskBusRaid)
    $j &= "}"
    Return $j
EndFunc

Func _GetControllersJsonArray()
    Local $oWMI = ObjGet("winmgmts:\\.\root\cimv2")
    If @error Or Not IsObj($oWMI) Then Return "[]"

    Local $arr = "["
    Local $first = True

    Local $colIDE = $oWMI.ExecQuery("SELECT Name, Manufacturer, PNPDeviceID FROM Win32_IDEController")
    If Not @error And IsObj($colIDE) Then
        Local $c
        For $c In $colIDE
            If Not $first Then $arr &= ","
            $first = False
            $arr &= "{"
            $arr &= '"type":"IDEController",'
            $arr &= '"name":"' & _JsonEscape(_Safe($c.Name)) & '",'
            $arr &= '"manufacturer":"' & _JsonEscape(_Safe($c.Manufacturer)) & '",'
            $arr &= '"pnpDeviceId":"' & _JsonEscape(_Safe($c.PNPDeviceID)) & '"'
            $arr &= "}"
        Next
    EndIf

    Local $colSCSI = $oWMI.ExecQuery("SELECT Name, Manufacturer, PNPDeviceID FROM Win32_SCSIController")
    If Not @error And IsObj($colSCSI) Then
        Local $sc
        For $sc In $colSCSI
            If Not $first Then $arr &= ","
            $first = False
            $arr &= "{"
            $arr &= '"type":"SCSIController",'
            $arr &= '"name":"' & _JsonEscape(_Safe($sc.Name)) & '",'
            $arr &= '"manufacturer":"' & _JsonEscape(_Safe($sc.Manufacturer)) & '",'
            $arr &= '"pnpDeviceId":"' & _JsonEscape(_Safe($sc.PNPDeviceID)) & '"'
            $arr &= "}"
        Next
    EndIf

    $arr &= "]"
    Return $arr
EndFunc

Func _GetDriversJsonArray()
    Local $oWMI = ObjGet("winmgmts:\\.\root\cimv2")
    If @error Or Not IsObj($oWMI) Then Return "[]"

    Local $names[10] = ["storahci", "stornvme", "iaStorA", "iaStorAC", "iaStorVD", "iaStorV", "vmd", "nvme", "amd_sata", "amd_xata"]
    Local $arr = "["
    Local $first = True

    Local $i
    For $i = 0 To UBound($names) - 1
        Local $n = $names[$i]
        Local $q = "SELECT Name, State, StartMode FROM Win32_SystemDriver WHERE Name='" & $n & "'"
        Local $col = $oWMI.ExecQuery($q)

        If Not $first Then $arr &= ","
        $first = False

        If Not @error And IsObj($col) Then
            Local $obj, $found = False
            For $obj In $col
                $found = True
                $arr &= "{"
                $arr &= '"name":"' & _JsonEscape($n) & '",'
                $arr &= '"present":true,'
                $arr &= '"state":"' & _JsonEscape(_Safe($obj.State)) & '",'
                $arr &= '"startMode":"' & _JsonEscape(_Safe($obj.StartMode)) & '"'
                $arr &= "}"
            Next
            If Not $found Then
                $arr &= '{"name":"' & _JsonEscape($n) & '","present":false}'
            EndIf
        Else
            $arr &= '{"name":"' & _JsonEscape($n) & '","present":null}'
        EndIf
    Next

    $arr &= "]"
    Return $arr
EndFunc

Func _GetDisksJsonArray()
    Local $oStorage = ObjGet("winmgmts:\\.\root\Microsoft\Windows\Storage")
    If @error Or Not IsObj($oStorage) Then Return "[]"

    Local $col = $oStorage.ExecQuery("SELECT FriendlyName, SerialNumber, Size, BusType, MediaType FROM MSFT_PhysicalDisk")
    If @error Or Not IsObj($col) Then Return "[]"

    Local $arr = "["
    Local $first = True
    Local $obj
    For $obj In $col
        If Not $first Then $arr &= ","
        $first = False

        Local $name = _Safe($obj.FriendlyName)
        Local $ser  = _Safe($obj.SerialNumber)
        Local $size = _Safe($obj.Size)
        Local $bus  = _BusTypeToText($obj.BusType)
        Local $med  = _MediaTypeToText(_SafeNum($obj.MediaType))

        $arr &= "{"
        $arr &= '"name":"' & _JsonEscape($name) & '",'
        $arr &= '"serial":"' & _JsonEscape($ser) & '",'
        $arr &= '"sizeBytes":' & Number($size) & ","
        $arr &= '"sizeHuman":"' & _JsonEscape(_FmtBytes(_SafeNum($size))) & '",'
        $arr &= '"busType":"' & _JsonEscape($bus) & '",'
        $arr &= '"mediaType":"' & _JsonEscape($med) & '"'
        $arr &= "}"
    Next

    $arr &= "]"
    Return $arr
EndFunc



Func _DefaultReportFileName()
    Local $ts = @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & "_" & _
                StringFormat("%02d", @HOUR) & StringFormat("%02d", @MIN) & StringFormat("%02d", @SEC)
    Local $pc = StringRegExpReplace(@ComputerName, "[^A-Za-z0-9_\-]", "_")
    Return "Storage_Report_" & $pc & "_" & $ts & ".txt"
EndFunc

; ---------------- About window ----------------
Func _ShowAbout($hParent)
    Local $w = 520, $h = 250
    Local $hAbout = GUICreate("About - " & $APP_NAME, $w, $h, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU), -1, $hParent)

GUISetFont(11, 800, 0, "Segoe UI")
    Local $y = 14
    GUICtrlCreateLabel($APP_NAME, 14, $y, $w - 28, 22)
    GUICtrlSetFont(-1, 10, 800)

    $y += 28
    GUICtrlCreateLabel("Version: " & $APP_VER, 14, $y, $w - 28, 18)
    $y += 20
    GUICtrlCreateLabel("Open-source AutoIt tool by Giorgos Xanthopoulos (aka Gexos).", 14, $y, $w - 28, 18)
    $y += 26
    GUICtrlCreateLabel("Links (click to open):", 14, $y, $w - 28, 18)
    $y += 22

    Local $idGit = GUICtrlCreateLabel($GITHUB_URL, 14, $y, $w - 28, 18, $SS_NOTIFY)
    GUICtrlSetColor($idGit, 0x1E90FF)
    GUICtrlSetFont($idGit, 11, 800, 4) ; underline + bold

    $y += 20
    Local $idBlog = GUICtrlCreateLabel($BLOG_URL, 14, $y, $w - 28, 18, $SS_NOTIFY)
    GUICtrlSetColor($idBlog, 0x1E90FF)
    GUICtrlSetFont($idBlog, 11, 800, 4) ; underline + bold

    $y += 26
    GUICtrlCreateLabel("Close this window with the X button.", 14, $y, $w - 28, 18)

    GUICtrlCreateLabel("Icon credits: Hristos Kalaitzis", 20, 90, 420, 24)
Local $idCredPic = GUICtrlCreatePic("", 450, 82, 36, 36)
Local $hCredBmp = 0
Local $pngPath = @ScriptDir & "\\" & $CREDITS_PNG
If FileExists($pngPath) Then
    $hCredBmp = _SetPicFromPng($idCredPic, $pngPath)
EndIf
GUISetState(@SW_SHOW, $hAbout)

    While 1
        Local $msg = GUIGetMsg()
        Switch $msg
            Case $GUI_EVENT_CLOSE
                ExitLoop
            Case $idGit
                ShellExecute($GITHUB_URL)
            Case $idBlog
                ShellExecute($BLOG_URL)
        EndSwitch
    WEnd

    If $hCredBmp <> 0 Then _WinAPI_DeleteObject($hCredBmp)
    GUIDelete($hAbout)
EndFunc

Func _OpenHelpFile()
    If FileExists($HELP_FILE) Then
        ShellExecute($HELP_FILE)
        Return
    EndIf

    MsgBox($MB_ICONINFORMATION, "Help", "Help file not found:" & @CRLF & $HELP_FILE & @CRLF & @CRLF & _
        "You can add it later (for example help.txt) and this menu entry will open it.")
EndFunc


; ---------------- Report builder ----------------
Func _BuildReport()
    Local $s = ""

    ; Top Summary (1 line)
    $s &= _TopSummary() & @CRLF & @CRLF

    $s &= $APP_NAME & " - " & $APP_VER & @CRLF
    $s &= "Generated: " & @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & _
          " " & StringFormat("%02d", @HOUR) & ":" & StringFormat("%02d", @MIN) & ":" & StringFormat("%02d", @SEC) & @CRLF
    $s &= "Computer: " & @ComputerName & @CRLF
    $s &= "User: " & @UserName & @CRLF
    $s &= "OS: " & @OSVersion & " / " & @OSBuild & " (" & @OSArch & ")" & @CRLF
    $s &= @CRLF

    $s &= _VerdictQuick() & @CRLF & @CRLF
    $s &= _SummaryClearPaths() & @CRLF & @CRLF
    $s &= _ListControllersDeviceManagerStyle() & @CRLF & @CRLF
    $s &= _DetectControllerModeWithService() & @CRLF & @CRLF
    $s &= _ListCommonStorageDrivers() & @CRLF & @CRLF
    $s &= _ListDisksBusType() & @CRLF & @CRLF

    $s &= "Notes:" & @CRLF
    $s &= "- Windows usually cannot read the BIOS/UEFI 'AHCI vs RAID/RST' toggle directly." & @CRLF
    $s &= "- This tool infers the mode from controller names + driver service names + RST/VMD keywords." & @CRLF
    $s &= "- On Intel VMD/RST, NVMe drives may be presented behind a RAID controller; BusType may show RAID." & @CRLF
    Return $s
EndFunc

; ---------------------------
; Top Summary (very short, 1 line)
; ---------------------------
Func _TopSummary()
    Local $nvmeSvc = ""
    Local $biosGuess = "Unknown"
    Local $nvmeDetected = False
    Local $sataAhciDetected = False

    Local $oStorage = ObjGet("winmgmts:\\.\root\Microsoft\Windows\Storage")
    If Not @error And IsObj($oStorage) Then
        Local $colD = $oStorage.ExecQuery("SELECT BusType FROM MSFT_PhysicalDisk")
        If Not @error And IsObj($colD) Then
            Local $d
            For $d In $colD
                If Number($d.BusType) = 17 Then $nvmeDetected = True
            Next
        EndIf
    EndIf

    Local $hasVMD = False, $hasRstPremium = False, $hasRaidName = False
    Local $oWMI = ObjGet("winmgmts:\\.\root\cimv2")
    If Not @error And IsObj($oWMI) Then
        Local $col = $oWMI.ExecQuery("SELECT Name, Service, PNPClass FROM Win32_PnPEntity WHERE (PNPClass='HDC' OR PNPClass='SCSIAdapter' OR PNPClass='System')")
        If Not @error And IsObj($col) Then
            Local $x
            For $x In $col
                Local $name = _Safe($x.Name)
                Local $svc  = _Safe($x.Service)
                Local $nameL = StringLower($name)

                If (StringInStr($nameL, "nvm") Or StringInStr($nameL, "nvme") Or StringInStr($nameL, "nvm express")) Then
                    If $svc <> "N/A" And $nvmeSvc = "" Then $nvmeSvc = $svc
                EndIf

                If (StringInStr($nameL, "sata") Or StringInStr($nameL, "ahci")) Then
                    If StringInStr($nameL, "ahci") Then $sataAhciDetected = True
                EndIf

                If StringInStr($nameL, "vmd") Or StringInStr($nameL, "volume management device") Then $hasVMD = True
                If StringInStr($nameL, "rst premium") Then $hasRstPremium = True
                If StringInStr($nameL, "raid controller") Or (StringInStr($nameL, "raid") And Not StringInStr($nameL, "hydra")) Then $hasRaidName = True
            Next
        EndIf
    EndIf

    Local $busRaid = _AnyDiskBusTypeRaid()
    If $hasVMD Or $hasRstPremium Or ($busRaid And StringInStr(StringLower($nvmeSvc), "iastor")) Then
        $biosGuess = "RAID/RST/VMD"
    ElseIf $hasRaidName Then
        $biosGuess = "Possibly RAID/RST"
    Else
        $biosGuess = "AHCI"
    EndIf

    If $nvmeSvc = "" Then $nvmeSvc = "Unknown"
    Local $nvmeDriverText = $nvmeSvc
    If StringLower($nvmeSvc) = "stornvme" Then $nvmeDriverText = "Microsoft driver"
    If StringInStr(StringLower($nvmeSvc), "iastor") Then $nvmeDriverText = "Intel RST driver"

    Local $sataText = "Unknown"
    If $sataAhciDetected Then $sataText = "AHCI"

    Local $line = "Detected: "
    If $nvmeDetected Then
        $line &= "NVMe SSD (" & $nvmeDriverText & "). "
    Else
        $line &= "No NVMe detected. "
    EndIf
    $line &= "SATA controller: " & $sataText & ". "
    $line &= "BIOS mode guess: " & $biosGuess & "."

    Return $line
EndFunc

Func _VerdictQuick()
    Local $hasVMD = False, $hasRstPremium = False, $hasRaidController = False
    Local $hasIAStor = False, $hasStorAHCI = False, $hasAnyDiskBusRaid = False

    Local $oStorage = ObjGet("winmgmts:\\.\root\Microsoft\Windows\Storage")
    If Not @error And IsObj($oStorage) Then
        Local $col = $oStorage.ExecQuery("SELECT BusType FROM MSFT_PhysicalDisk")
        If Not @error And IsObj($col) Then
            Local $obj
            For $obj In $col
                If Number($obj.BusType) = 8 Then $hasAnyDiskBusRaid = True
            Next
        EndIf
    EndIf

    Local $oWMI = ObjGet("winmgmts:\\.\root\cimv2")
    If @error Or Not IsObj($oWMI) Then Return "Verdict: UNKNOWN (WMI not accessible)"

    Local $col2 = $oWMI.ExecQuery("SELECT Name, Service, PNPClass FROM Win32_PnPEntity WHERE (PNPClass='HDC' OR PNPClass='SCSIAdapter' OR PNPClass='System')")
    If Not @error And IsObj($col2) Then
        Local $x
        For $x In $col2
            Local $nameL = StringLower(_Safe($x.Name))
            Local $svcL  = StringLower(_Safe($x.Service))

            If StringInStr($nameL, "vmd") Or StringInStr($nameL, "volume management device") Then $hasVMD = True
            If StringInStr($nameL, "rst premium") Then $hasRstPremium = True
            If StringInStr($nameL, "raid controller") Or (StringInStr($nameL, "raid") And Not StringInStr($nameL, "hydra")) Then $hasRaidController = True

            If StringInStr($svcL, "iastor") Then $hasIAStor = True
            If $svcL = "storahci" Then $hasStorAHCI = True
        Next
    EndIf

    Local $v = "Verdict: "
    If $hasVMD Or $hasRstPremium Or ($hasAnyDiskBusRaid And $hasIAStor) Then
        $v &= "VERY LIKELY Intel RST/VMD enabled (RAID mode for NVMe/Storage)"
    ElseIf $hasRaidController And $hasIAStor Then
        $v &= "LIKELY RAID/RST enabled"
    Else
        $v &= "LIKELY AHCI behavior (NVMe via stornvme; SATA may use Intel or Microsoft AHCI driver)"
    EndIf

    $v &= @CRLF & "Signals: VMD=" & _YN($hasVMD) & ", RSTPremium=" & _YN($hasRstPremium) & ", RaidControllerName=" & _YN($hasRaidController) & _
          ", iaStor*ServiceSeen=" & _YN($hasIAStor) & ", storahciServiceSeen=" & _YN($hasStorAHCI) & ", AnyDiskBusTypeRAID=" & _YN($hasAnyDiskBusRaid)

    Return $v
EndFunc

Func _YN($b)
    If $b Then Return "Yes"
    Return "No"
EndFunc

Func _SummaryClearPaths()
    Local $nvmeSvc = "", $sataSvc = ""
    Local $hasVMD = False, $hasRstPremium = False, $hasRaidControllerName = False

    Local $oWMI = ObjGet("winmgmts:\\.\root\cimv2")
    If @error Or Not IsObj($oWMI) Then Return "Summary: UNKNOWN (WMI not accessible)"

    Local $col = $oWMI.ExecQuery("SELECT Name, Service, PNPClass FROM Win32_PnPEntity WHERE (PNPClass='HDC' OR PNPClass='SCSIAdapter' OR PNPClass='System')")
    If Not @error And IsObj($col) Then
        Local $x
        For $x In $col
            Local $name = _Safe($x.Name)
            Local $svc  = _Safe($x.Service)
            Local $nameL = StringLower($name)

            If (StringInStr($nameL, "nvm") Or StringInStr($nameL, "nvme") Or StringInStr($nameL, "nvm express")) Then
                If $svc <> "N/A" And $nvmeSvc = "" Then $nvmeSvc = $svc
            EndIf

            If (StringInStr($nameL, "sata") Or StringInStr($nameL, "ahci")) Then
                If $svc <> "N/A" And $sataSvc = "" Then $sataSvc = $svc
            EndIf

            If StringInStr($nameL, "vmd") Or StringInStr($nameL, "volume management device") Then $hasVMD = True
            If StringInStr($nameL, "rst premium") Then $hasRstPremium = True
            If StringInStr($nameL, "raid controller") Or (StringInStr($nameL, "raid") And Not StringInStr($nameL, "hydra")) Then $hasRaidControllerName = True
        Next
    EndIf

    If $nvmeSvc = "" Then $nvmeSvc = "(not detected)"
    If $sataSvc = "" Then $sataSvc = "(not detected)"

    Local $busRaid = _AnyDiskBusTypeRaid()

    Local $out = "Summary (simple):" & @CRLF
    $out &= "- NVMe path driver: " & $nvmeSvc & " -> " & _ExplainNvmeSvc($nvmeSvc) & @CRLF
    $out &= "- SATA/AHCI path driver: " & $sataSvc & " -> " & _ExplainSataSvc($sataSvc) & @CRLF
    $out &= "- BIOS mode (best guess): " & _ExplainBiosGuess($hasVMD, $hasRstPremium, $hasRaidControllerName, $busRaid, $sataSvc, $nvmeSvc) & @CRLF
    $out &= @CRLF
    $out &= "What it means:" & @CRLF
    $out &= "- If NVMe path is 'stornvme' and disks show Bus=NVMe, you're not on NVMe-over-RAID/VMD." & @CRLF
    $out &= "- If SATA path is 'storahci' OR an Intel driver (like iaStorAC) but controller name says AHCI, that's still AHCI behavior." & @CRLF
    Return $out
EndFunc

Func _ExplainNvmeSvc($svc)
    Local $s = StringLower($svc)
    If $s = "stornvme" Then Return "Microsoft NVMe driver (normal)"
    If StringInStr($s, "iastor") Then Return "Intel RST driver (NVMe may be behind RST/VMD)"
    If $svc = "(not detected)" Then Return "Could not identify"
    Return "Driver service: " & $svc
EndFunc

Func _ExplainSataSvc($svc)
    Local $s = StringLower($svc)
    If $s = "storahci" Then Return "Microsoft AHCI driver"
    If StringInStr($s, "iastor") Then Return "Intel storage driver for SATA (can still be AHCI)"
    If $svc = "(not detected)" Then Return "Could not identify"
    Return "Driver service: " & $svc
EndFunc

Func _ExplainBiosGuess($hasVMD, $hasRstPremium, $hasRaidName, $busRaid, $sataSvc, $nvmeSvc)
    If $hasVMD Or $hasRstPremium Or ($busRaid And StringInStr(StringLower($nvmeSvc), "iastor")) Then
        Return "Likely RAID/RST/VMD enabled"
    EndIf
    If $hasRaidName Then Return "Possibly RAID/RST (controller named RAID)"
    Return "Likely AHCI behavior"
EndFunc

Func _AnyDiskBusTypeRaid()
    Local $oStorage = ObjGet("winmgmts:\\.\root\Microsoft\Windows\Storage")
    If @error Or Not IsObj($oStorage) Then Return False
    Local $col = $oStorage.ExecQuery("SELECT BusType FROM MSFT_PhysicalDisk")
    If @error Or Not IsObj($col) Then Return False
    Local $obj
    For $obj In $col
        If Number($obj.BusType) = 8 Then Return True
    Next
    Return False
EndFunc

Func _ListControllersDeviceManagerStyle()
    Local $oWMI = ObjGet("winmgmts:\\.\root\cimv2")
    If @error Or Not IsObj($oWMI) Then Return "Controllers (Device Manager style): UNKNOWN (WMI not accessible)"

    Local $out = "Controllers (Device Manager style):" & @CRLF

    Local $colIDE = $oWMI.ExecQuery("SELECT Name, Manufacturer, PNPDeviceID FROM Win32_IDEController")
    If Not @error And IsObj($colIDE) Then
        Local $c, $countIDE = 0
        For $c In $colIDE
            $countIDE += 1
            $out &= "- [IDEController] " & _Safe($c.Name) & " | Mfg=" & _Safe($c.Manufacturer) & @CRLF
            $out &= "  PNPDeviceID: " & _Shorten(_Safe($c.PNPDeviceID), 120) & @CRLF
        Next
        If $countIDE = 0 Then $out &= "- [IDEController] (none returned)" & @CRLF
    Else
        $out &= "- [IDEController] (query failed)" & @CRLF
    EndIf

    Local $colSCSI = $oWMI.ExecQuery("SELECT Name, Manufacturer, PNPDeviceID FROM Win32_SCSIController")
    If Not @error And IsObj($colSCSI) Then
        Local $sc, $countS = 0
        For $sc In $colSCSI
            $countS += 1
            $out &= "- [SCSIController] " & _Safe($sc.Name) & " | Mfg=" & _Safe($sc.Manufacturer) & @CRLF
            $out &= "  PNPDeviceID: " & _Shorten(_Safe($sc.PNPDeviceID), 120) & @CRLF
        Next
        If $countS = 0 Then $out &= "- [SCSIController] (none returned)" & @CRLF
    Else
        $out &= "- [SCSIController] (query failed)" & @CRLF
    EndIf

    Return $out
EndFunc

Func _DetectControllerModeWithService()
    Local $oWMI = ObjGet("winmgmts:\\.\root\cimv2")
    If @error Or Not IsObj($oWMI) Then Return "Controller mode: UNKNOWN (WMI not accessible)"

    Local $q = "SELECT Name, Manufacturer, PNPDeviceID, Service, PNPClass FROM Win32_PnPEntity WHERE (PNPClass='HDC' OR PNPClass='SCSIAdapter' OR PNPClass='System')"
    Local $col = $oWMI.ExecQuery($q)
    If @error Or Not IsObj($col) Then Return "Controller mode: UNKNOWN (query failed)"

    Local $details = ""
    Local $obj, $hits = 0
    Local $foundAHCI = False, $foundRST = False

    For $obj In $col
        Local $name = _Safe($obj.Name)
        Local $mfg  = _Safe($obj.Manufacturer)
        Local $pnp  = _Safe($obj.PNPDeviceID)
        Local $svc  = _Safe($obj.Service)
        Local $cls  = _Safe($obj.PNPClass)

        Local $nameL = StringLower($name)
        Local $svcL  = StringLower($svc)

        If Not (StringInStr($nameL, "ahci") Or StringInStr($nameL, "sata") Or StringInStr($nameL, "raid") Or _
                StringInStr($nameL, "rst") Or StringInStr($nameL, "vmd") Or StringInStr($nameL, "storage") Or _
                StringInStr($nameL, "nvme") Or StringInStr($svcL, "stor") Or StringInStr($svcL, "iastor")) Then
            ContinueLoop
        EndIf

        $hits += 1
        $details &= "- " & $name & " | Class=" & $cls & " | Service=" & $svc & " | Mfg=" & $mfg & @CRLF
        $details &= "  PNPDeviceID: " & _Shorten($pnp, 120) & @CRLF

        If StringInStr($svcL, "iastor") Or StringInStr($nameL, "rst") Or StringInStr($nameL, "vmd") Or _
           StringInStr($nameL, "rst premium") Or StringInStr($nameL, "raid") Then
            $foundRST = True
        EndIf
        If StringInStr($nameL, "ahci") Or $svcL = "storahci" Then
            $foundAHCI = True
        EndIf
    Next

    Local $mode = "UNKNOWN"
    If $foundRST And Not $foundAHCI Then
        $mode = "Likely RAID / Intel RST (or VMD enabled)"
    ElseIf $foundAHCI And Not $foundRST Then
        $mode = "Likely AHCI"
    ElseIf $foundAHCI And $foundRST Then
        $mode = "Multiple controllers detected (normal on most PCs)"
    EndIf

    Local $out = "Controller mode (detailed inference): " & $mode & @CRLF
    If $hits > 0 Then
        $out &= "Controllers (with driver service):" & @CRLF & $details
    Else
        $out &= "Controllers: (no clear storage controllers matched the filter)" & @CRLF
    EndIf
    Return $out
EndFunc

Func _ListCommonStorageDrivers()
    Local $oWMI = ObjGet("winmgmts:\\.\root\cimv2")
    If @error Or Not IsObj($oWMI) Then Return "Driver services: UNKNOWN (WMI not accessible)"

    Local $names[10] = ["storahci", "stornvme", "iaStorA", "iaStorAC", "iaStorVD", "iaStorV", "vmd", "nvme", "amd_sata", "amd_xata"]
    Local $out = "Common storage driver services (running state):" & @CRLF

    Local $i
    For $i = 0 To UBound($names) - 1
        Local $n = $names[$i]
        Local $q = "SELECT Name, State, StartMode FROM Win32_SystemDriver WHERE Name='" & $n & "'"
        Local $col = $oWMI.ExecQuery($q)

        If Not @error And IsObj($col) Then
            Local $obj, $found = False
            For $obj In $col
                $found = True
                $out &= "- " & $n & ": State=" & _Safe($obj.State) & ", StartMode=" & _Safe($obj.StartMode) & @CRLF
            Next
            If Not $found Then $out &= "- " & $n & ": (not present)" & @CRLF
        Else
            $out &= "- " & $n & ": (query failed)" & @CRLF
        EndIf
    Next

    Return $out
EndFunc

Func _ListDisksBusType()
    Local $out = "Physical disks:" & @CRLF

    Local $oStorage = ObjGet("winmgmts:\\.\root\Microsoft\Windows\Storage")
    If Not @error And IsObj($oStorage) Then
        Local $col = $oStorage.ExecQuery("SELECT FriendlyName, SerialNumber, Size, BusType, MediaType FROM MSFT_PhysicalDisk")
        If Not @error And IsObj($col) Then
            Local $obj, $count = 0
            For $obj In $col
                $count += 1
                Local $name = _Safe($obj.FriendlyName)
                Local $ser  = _Safe($obj.SerialNumber)
                Local $bus  = _BusTypeToText($obj.BusType)
                Local $size = _FmtBytes(_SafeNum($obj.Size))
                Local $med  = _MediaTypeToText(_SafeNum($obj.MediaType))

                $out &= "- " & $name & " | Bus=" & $bus & " | Media=" & $med & " | Size=" & $size
                If $ser <> "N/A" Then $out &= " | SN=" & $ser
                $out &= @CRLF
            Next
            If $count = 0 Then
                $out &= "(No MSFT_PhysicalDisk entries returned.)" & @CRLF
            Else
                $out &= "(BusType is the best indicator for NVMe vs SATA.)" & @CRLF
            EndIf
            Return $out
        EndIf
    EndIf

    Return $out & "(Disk list unavailable — MSFT_PhysicalDisk query failed.)"
EndFunc

Func _Safe($v)
    If IsObj($v) Then Return "[Object]"
    If IsArray($v) Then Return "[Array]"
    If $v = "" Then Return "N/A"
    Return $v
EndFunc

Func _SafeNum($v)
    If $v = "" Or $v = "N/A" Then Return 0
    Return Number($v)
EndFunc

Func _FmtBytes($bytes)
    If $bytes <= 0 Then Return "N/A"
    Local $gb = $bytes / (1024 * 1024 * 1024)
    If $gb >= 1 Then Return Round($gb, 2) & " GB"
    Local $mb = $bytes / (1024 * 1024)
    Return Round($mb, 2) & " MB"
EndFunc

Func _MediaTypeToText($mediaType)
    Switch Number($mediaType)
        Case 3
            Return "HDD"
        Case 4
            Return "SSD"
        Case 5
            Return "SCM"
        Case Else
            Return "Unspecified"
    EndSwitch
EndFunc

Func _BusTypeToText($busType)
    Switch Number($busType)
        Case 17
            Return "NVMe"
        Case 11
            Return "SATA"
        Case 12
            Return "SAS"
        Case 8
            Return "RAID (RST/VMD can mask NVMe here)"
        Case 7
            Return "USB"
        Case 3
            Return "ATA"
        Case 0
            Return "Unknown"
        Case Else
            Return "Other (" & $busType & ")"
    EndSwitch
EndFunc

Func _Shorten($s, $maxLen)
    If $maxLen < 10 Then Return $s
    If StringLen($s) <= $maxLen Then Return $s
    Return StringLeft($s, $maxLen - 3) & "..."
EndFunc


; Convert PNG to a temporary BMP so GUICtrlCreatePic can display it reliably
Func _PngToBmpTemp($pngPath)
    ; Some Windows/AutoIt setups do not show PNG in GUICtrlCreatePic directly.
    ; We convert to BMP in %TEMP% using GDI+ and load the BMP instead.
    Local $bmpPath = @TempDir & "\bios-storage-check_credit_" & @AutoItPID & ".bmp"
    If FileExists($bmpPath) Then FileDelete($bmpPath)

    _GDIPlus_Startup()
    Local $hImage = _GDIPlus_ImageLoadFromFile($pngPath)
    If @error Or $hImage = 0 Then
        _GDIPlus_Shutdown()
        Return ""
    EndIf

    _GDIPlus_ImageSaveToFile($hImage, $bmpPath)
    _GDIPlus_ImageDispose($hImage)
    _GDIPlus_Shutdown()

    If FileExists($bmpPath) Then Return $bmpPath
    Return ""
EndFunc


; Load a PNG into a GUI Pic control reliably using GDI+ (HBITMAP + STM_SETIMAGE)
Func _SetPicFromPng($idPic, $pngPath)
    Local Const $STM_SETIMAGE = 0x0172
    Local Const $IMAGE_BITMAP = 0

    _GDIPlus_Startup()
    Local $hImg = _GDIPlus_ImageLoadFromFile($pngPath)
    If @error Or $hImg = 0 Then
        _GDIPlus_Shutdown()
        Return 0
    EndIf

    Local $hBmp = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hImg, 0x00FFFFFF)
    _GDIPlus_ImageDispose($hImg)
    _GDIPlus_Shutdown()

    If $hBmp = 0 Then Return 0

    Local $hCtrl = GUICtrlGetHandle($idPic)
    _SendMessage($hCtrl, $STM_SETIMAGE, $IMAGE_BITMAP, $hBmp)
    Return $hBmp
EndFunc
