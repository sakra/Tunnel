@echo off

setlocal enabledelayedexpansion
cd /D "%~dp0"

if not defined MATHEMATICA_BASE (
	if defined ALLUSERSAPPDATA (
		set MATHEMATICA_BASE=!ALLUSERSAPPDATA!\Mathematica
	) else if defined ProgramData (
		set MATHEMATICA_BASE=!ProgramData!\Mathematica
	) else (
		set MATHEMATICA_BASE=!APPDATA:%USERPROFILE%=%ALLUSERSPROFILE%!\Mathematica
	)
)
if not defined MATHEMATICA_USERBASE (
	set MATHEMATICA_USERBASE=!APPDATA!\Mathematica
)

mkdir "%MATHEMATICA_BASE%\Kernel"
xcopy /Y ".\scripts\tunnel.m" "%MATHEMATICA_BASE%\Kernel"
mkdir "%MATHEMATICA_USERBASE%\FrontEnd"
xcopy /Y ".\scripts\tunnel.bat" "%MATHEMATICA_USERBASE%\FrontEnd"
xcopy /Y ".\scripts\tunnel_sub.bat" "%MATHEMATICA_USERBASE%\FrontEnd"

if "%~f0" == "%~0" pause
