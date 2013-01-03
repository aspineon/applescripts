(* TogglePowerSave
This script changes keyboard and display settings, turns on/off AirPort and BlueTooth, and
launches/quits certain applications (in input list powerHungryApps).  The script 
creates/removes a file called .powerSaveOn in its working directory in order to tell 
whether or not power save mode is on/off.

The script also requires that "Enable access for assistive devices" be selected in 
the Universal Access window of System Preferences.
*)

on run {powerHungryApps}
	(* Check if UI scripting is enabled. If not, then show a dialog explaining that it must be enabled and open the window in which it can be enabled. *)
	tell application "System Events" to set isUIScriptingEnabled to UI elements enabled
	if isUIScriptingEnabled = false then
		tell application "System Preferences"
			activate
			set current pane to pane "com.apple.preference.universalaccess"
			display dialog "Your system is not properly configured to run this script. 

Please select the \"Enable access for assistive devices\" checkbox and trigger the script again to proceed."
			return 0
		end tell
	end if
	
	(* Apps to turn on/off *)
	set powerHungryApps to {"Thunderbird", "iTunes", "Notify", "Google Notifier"}
	
	(* Get path to working directory *)
	set d to text item delimiters
	set text item delimiters to "/"
	set workingDir to (POSIX path of (path to me))'s text 1 thru text item -2 & "/"
	set text item delimiters to d
	
	(* 
Check if /data/.powerSaveOn exists to determine if the script
should enter or exit power save mode.
If powerSaveOn exists, then set powerMode to "off" because the script
will turn powerMode off. 
*)
	set toggleFile to workingDir & ".powerSaveOn"
	set testCmd to "if test -e " & toggleFile & "; then echo off; else echo on; fi"
	set powerMode to do shell script testCmd
	
	(* 
Do three things based on powerMode state:
1. create/delete .powerSaveOn to signal that power save mode is on/off
2. set checkBoxVal to 1/0.  System preferences checkboxes will only be toggled if they have this value.
3. set the screen brightness value to 0.06/0.6
*)
	if (powerMode is "on") then
		do shell script "touch " & toggleFile
		
		set checkBoxVal to 1
		set brightness to 0.06
		
		set airPortCheck to "On"
		set newAirPortState to "off"
	else if (powerMode is "off") then
		do shell script "rm " & toggleFile
		
		set checkBoxVal to 0
		set brightness to 1
		
		set airPortCheck to "Off"
		set newAirPortState to "on"
	end if
	
	(*
Use UI scripting of System Preferences to change settings of screen brightness, automatic screen brightness adjustment, keyboard backlight, and BlueTooth power.
*)
	activate application "System Preferences"
	
	tell application "System Events"
		tell process "System Preferences"
			click menu item "Bluetooth" of menu "View" of menu bar 1
			delay 2
			if (value of checkbox "On" of window "Bluetooth" is checkBoxVal) then
				click checkbox "On" of window "Bluetooth"
			end if
			
			click menu item "Keyboard" of menu "View" of menu bar 1
			delay 2
			click radio button "Keyboard" of tab group 1 of window "Keyboard"
			delay 1
			if (value of checkbox "Illuminate keyboard in low light conditions" of tab group 1 of window "Keyboard" is checkBoxVal) then
				click checkbox "Illuminate keyboard in low light conditions" of tab group 1 of window "Keyboard"
			end if
			
			try --use try here because this part will fail if there are other monitors connected 
				click menu item "Displays" of menu "View" of menu bar 1
				delay 2
				if (value of checkbox "Automatically adjust brightness as ambient light changes" of group 2 of tab group 1 of window "Color LCD" is checkBoxVal) then
					click checkbox "Automatically adjust brightness as ambient light changes" of group 2 of tab group 1 of window "Color LCD"
				end if
				set value of slider 1 of group 2 of tab group 1 of window "Color LCD" to brightness
			end try
		end tell
	end tell
	
	tell application "System Preferences" to quit
	
	
	(*
For fun, use networksetup and shell commands to turn off AirPort rather than System Preference UI scripting

*)
	
	(* Get AirPort device name *)
	set devName to do shell script "networksetup -listallhardwareports | grep -A1 \"AirPort\" | awk '{ if ($1 == \"Device:\") print $2 }'"
	(* Get AirPort power state *)
	set airportPower to do shell script "networksetup -getairportpower " & devName & " | awk '{print $4}'"
	(* Toggle AirPort power state if necessary *)
	if (airportPower is airPortCheck) then
		do shell script "networksetup -setairportpower " & devName & " " & newAirPortState
	end if
	
	(*
Turn on/off certain applications that are typically left running in the background but eat power.
*)
	repeat with appName in powerHungryApps
		if (powerMode is "on") then
			try
				tell application appName to quit
			end try
		else if (powerMode is "off") then
			activate application appName
		end if
	end repeat
	(* Hide applications after giving them a second to launch *)
	if (powerMode is "off") then
		delay 1
		repeat with appName in powerHungryApps
			tell application "Finder"
				try
					set visible of process appName to false
				end try
			end tell
		end repeat
	end if
end run