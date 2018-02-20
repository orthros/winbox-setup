; User config! 
; This section binds the key combo to the switch/create/delete actions
#1::
#2::
#3::
#4::
#5::
#6::
#7::
#8::
#9::
{
     StringTrimLeft, number, A_ThisHotkey, 1
     switchDesktopByNumber(number)
     return
}
#0::switchDesktopByNumber(10)
^#d::createVirtualDesktop()
#f4::deleteVirtualDesktop()

; This section binds the key combo to send a window to a specific desktop
; ^#1::
; ^#2::
; ^#3::
; ^#4::
; ^#5::
; ^#6::
; ^#7::
; ^#8::
; ^#9::
; {
;      StringTrimLeft, number, A_ThisHotkey, 2
;      sendWindowToDesktop(number)
;      return
; }
; ^#0::sendWindowToDesktop(10)

; Globals
DesktopCount = 1        ; Windows starts with however many desktops were last open at boot, we just set this to 1 because we map the desktopcount from the registry later
CurrentDesktop = 1      ; Desktop count is 1-indexed (Microsoft numbers them this way)
CurrentDesktopId = 0

;
; This function examines the registry to build an accurate list of the current virtual desktops and which one we're currently on.
; Current desktop UUID appears to be in HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SessionInfo\1\VirtualDesktops
; List of desktops appears to be in HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops
;
mapDesktopsFromRegistry() {
    global CurrentDesktop, DesktopCount, CurrentDesktopId
    
    
    ; Get the current session ID so we know where to look for the desktop UUID
	; https://msdn.microsoft.com/en-us/library/windows/desktop/aa383835
	SessionInfoNumber := DllCall("WTSGetActiveConsoleSessionId")
	
	; Get the current desktop UUID. Length should be 32 always, but there's no guarantee this couldn't change in a later Windows release so we check.
    RegRead, CurrentDesktopId, HKEY_CURRENT_USER, SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SessionInfo\%SessionInfoNumber%\VirtualDesktops, CurrentVirtualDesktop
    IdLength := StrLen(CurrentDesktopId)


    ; Get a list of the UUIDs for all virtual desktops on the system
    RegRead, DesktopList, HKEY_CURRENT_USER, SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops, VirtualDesktopIDs
    DesktopListLength := StrLen(DesktopList)

    ; Figure out how many virtual desktops there are
    DesktopCount := DesktopListLength/IdLength

    ; Parse the REG_DATA string that stores the array of UUID's for virtual desktops in the registry.
    i := 0
    while (i < DesktopCount) {
        StartPos := (i * IdLength) + 1
        DesktopIter := SubStr(DesktopList, StartPos, IdLength)
        OutputDebug, The iterator is pointing at %DesktopIter% and count is %i%.
		
        ; Break out if we find a match in the list. If we didn't find anything, keep the 
        ; old guess and pray we're still correct :-D.
        if (DesktopIter = CurrentDesktopId) {
            CurrentDesktop := i + 1
            OutputDebug, Current desktop number is %CurrentDesktop% with an ID of %DesktopIter%.
            break
        }
        i++
    }
}

;
; This function switches to the desktop number provided.
;
switchDesktopByNumber(targetDesktop)
{
    global CurrentDesktop, DesktopCount
    
    ; Re-generate the list of desktops and where we fit in that. We do this because 
    ; the user may have switched desktops via some other means than the script.
    mapDesktopsFromRegistry()
    
    ; If the user is trying to swap to a desktop that isn't valid, don't let
    ; them because we'd lose track of numbering. Unfortunately, we have to assume
    ; that this script was started when there were three desktops because we have
    ; no way to check.
    if (targetDesktop > DesktopCount) {
        return
    }
    
    ; Go right until we reach the desktop we want
    while(CurrentDesktop < targetDesktop) {
        Send ^#{Right}  
        CurrentDesktop++
        OutputDebug, [right] target: %targetDesktop% current: %CurrentDesktop%
    }
    
    ; Go left until we reach the desktop we want
    while(CurrentDesktop > targetDesktop) {
        Send ^#{Left}
        CurrentDesktop--
        OutputDebug, [left] target: %targetDesktop% current: %CurrentDesktop%
    }
}

;
; This function sends the current window to the target desktop
;
sendWindowToDesktop(targetDesktop)
{
    global CurrentDesktop, DesktopCount, CurrentDesktopID
    
    ; Re-generate the list of desktops and where we fit in that. We do this because 
    ; the user may have switched desktops via some other means than the script.
    mapDesktopsFromRegistry()
    
	; If the user is trying to send the window to a desktop that doesn't exist,
	; or the one we're already on, don't do anything.	
    if (targetDesktop > DesktopCount || CurrentDesktop == targetDesktop)
    {
        return
    }	
	
	; This part figures out how many times we need to hit Tab to get to the
	; monitor with the window we are trying to send to another desktop.	
	activemonitor := MonitorFromWindow()
	SysGet, monitorcount, MonitorCount
	SysGet, primarymonitor, MonitorPrimary
	
	If (activemonitor > primarymonitor)
	{
		monitoriter := activemonitor - primarymonitor
	}
	else If (activemonitor < primarymonitor)
	{
		monitoriter := monitorcount - primarymonitor + activemonitor
	}
	else
	{
		monitoriter := 0
	}
	monitoriter *= 2
	
	; This part figures out how many times we need to push down within the context menu to get the desktop we want.	
	if (targetDesktop > CurrentDesktop)
	{
	    targetDesktop -= 2
	}
	else
	{
	    targetdesktop--
	}
	
	; This part does the dirty work and sends the keypresses needed to send the
	; window to another desktop based on the variables we figured out above.	
	Send #{tab}
	winwait, ahk_class MultitaskingViewFrame
	
	Send {Tab %monitoriter%}
	
	Send {Appskey}m{Down %targetDesktop%}{Enter}
	Send #{tab}
}

;
; This function returns the monitor number of the current window
;
MonitorFromWindow()
{
	WinGetActiveTitle, activewindow
	WinGetPos, x, y, width, height, %activewindow%	
	; MsgBox, Window Position/Size:`nX: %X%`nY: %Y%`nWidth: %width%`nHeight: %height%	
	SysGet, monitorcount, MonitorCount
	SysGet, primarymonitor, MonitorPrimary	
	; MsgBox, Monitor Count: %MonitorCount%	
	Loop %monitorcount%
	{
		SysGet, mon, Monitor, %a_index%
		; MsgBox, Primary Monitor: %primarymonitor%`nDistance between monitor #%a_index%'s right border and Primary monitor's left border (Left < 0, Right > 0):`n%monRight%px		
		If (x < monRight - width / 2 || monitorcount = a_index)
		{
			return %a_index%
		}
	}
}

;
; This function creates a new virtual desktop and switches to it
;
createVirtualDesktop()
{
    global CurrentDesktop, DesktopCount
    if (DesktopCount = 10) {
        return
    }
    Send, #^d
    DesktopCount++
    CurrentDesktop = %DesktopCount%
    OutputDebug, [create] desktops: %DesktopCount% current: %CurrentDesktop%
}

;
; This function deletes the current virtual desktop
;
deleteVirtualDesktop()
{
    global CurrentDesktop, DesktopCount
    Send, #^{F4}
    DesktopCount--
    CurrentDesktop--
    OutputDebug, [delete] desktops: %DesktopCount% current: %CurrentDesktop%
}

; Main

mapDesktopsFromRegistry()
OutputDebug, [loading] desktops: %DesktopCount% current: %CurrentDesktop%
