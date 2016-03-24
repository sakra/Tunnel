@echo off
rem tunnel script for launching remote Mathematica controller kernels.
rem See https://github.com/sakra/Tunnel/blob/master/MANUAL.md for usage hints.
rem Copyright 2015-2016 Sascha Kratky, see accompanying license file.

setlocal enabledelayedexpansion

cd /D "%~dp0"

rem create log file with unique name
mkdir "Logs\%DATE:/=-%" > NUL 2>&1
set "LOGFILE=Logs\!DATE:/=-!\%~n0_!DATE:/=-!_!TIME::=-!.log"

echo !COMPUTERNAME! !DATE! !TIME! >> "%LOGFILE%"
set >> "%LOGFILE%"
echo !CMDCMDLINE! >> "%LOGFILE%"
echo "%~0" "%*" >> "%LOGFILE%"

rem path to PuTTY plink executable, see http://www.putty.org/
if defined ProgramFiles^(x86^) (
	set PLINK_EXE_PATH=!ProgramFiles^(x86^)!\putty\plink.exe
) else if defined ProgramFiles (
	set PLINK_EXE_PATH=!ProgramFiles!\putty\plink.exe
) else (
	set PLINK_EXE_PATH=C:\Program Files\putty\plink.exe
)

rem path to alternate PuTTY plinkw executable from Quest, see http://rc.quest.com/topics/putty/
if defined ProgramFiles^(x86^) (
	set PLINKW_EXE_PATH=!ProgramFiles^(x86^)!\Quest Software\PuTTY\plinkw.exe
) else if defined ProgramFiles (
	set PLINKW_EXE_PATH=!ProgramFiles!\Quest Software\PuTTY\plinkw.exe
) else (
	set PLINKW_EXE_PATH=C:\Program Files\Quest Software\PuTTY\plinkw.exe
)

rem prefer Quest PuTTY plink.exe, as it does not open a console window
rem and allows for redirection of stdout and stderr to log file
rem PuTTY options:
rem -batch  disable all interactive prompts
rem -v      show verbose messages
rem -ssh    force use of SSH protocol
rem -x      disable X11 forwarding
rem -C      enable compression
rem -A      enable agent forwarding
set PUTTY_OPTS=-batch -v -ssh -C -A -x
if exist "%PLINKW_EXE_PATH%" (
	set PUTTY_PATH=!PLINKW_EXE_PATH!
	rem Quest PuTTY options:
	rem -no_in  redirect stdin from NUL
	rem -ng     disable GSSAPI authentication
	set PUTTY_OPTS=!PUTTY_OPTS! -no_in -ng -auto_store_key_in_cache
) else if exist "%PLINK_EXE_PATH%" (
	set PUTTY_PATH=!PLINK_EXE_PATH!
) else (
	echo Error: PuTTY is not installed! >> "%LOGFILE%"
	exit /B 1
)

set "SCRIPT_PATH=%~0"
set "REMOTE_KERNEL_ADDRESS=%~1"
set "REMOTE_KERNEL_PATH=%~2"
set "LINK_NAME=%~3"

if "%LINK_NAME%"=="" (
	echo Usage: %~nx0 [user[:password]@]host[:port] "path_to_mathematica_kernel" "linkname" >> "%LOGFILE%"
	exit /B 1
)

rem parse port link name port numbers, e.g., 53994@127.0.0.1,39359@127.0.0.1
for /F "Delims=,@ Tokens=1,2,3" %%S in ("%LINK_NAME%") do (
	set MAIN_LINK_DATA_PORT=%%S
	set MAIN_LINK_HOST=%%T
	set MAIN_LINK_MESSAGE_PORT=%%U
)

if not defined MAIN_LINK_DATA_PORT (
	echo Error: "%LINK_NAME%" is not a properly formatted MathLink TCPIP protocol link name! >> "%LOGFILE%"
	exit /B 1
)

if not defined MAIN_LINK_MESSAGE_PORT (
	echo Error: "%LINK_NAME%" is not a properly formatted MathLink TCPIP protocol link name! >> "%LOGFILE%"
	exit /B 1
)

rem test if MAIN_LINK_HOST is an IPv6 address
if not "%MAIN_LINK_HOST::=%" == "%MAIN_LINK_HOST%" (
	rem SSH requires IPv6 address to be enclosed in square brackets
	set MAIN_LINK_HOST=[!MAIN_LINK_HOST!]
)

set LOOPBACK_IP_ADDR=127.0.0.1
set MAIN_LINK_LOOPBACK=!MAIN_LINK_DATA_PORT!@!LOOPBACK_IP_ADDR!,!MAIN_LINK_MESSAGE_PORT!@!LOOPBACK_IP_ADDR!

if not "%MAIN_LINK_HOST%"=="%LOOPBACK_IP_ADDR%" (
	echo Warning: "%LINK_NAME%" does not use the loopback IP address "%LOOPBACK_IP_ADDR%"! >> "%LOGFILE%"
)

rem parse user credentials from host name
for /F "Delims=@ Tokens=1,2" %%S in ("!REMOTE_KERNEL_ADDRESS!") do (
	set REMOTE_KERNEL_USER=%%S
	set REMOTE_KERNEL_HOST=%%T
)
if not defined REMOTE_KERNEL_HOST (
	set REMOTE_KERNEL_HOST=!REMOTE_KERNEL_USER!
	set REMOTE_KERNEL_USER=
)

rem parse password from user credentials
if defined REMOTE_KERNEL_USER (
	for /F "Delims=: Tokens=1,2" %%S in ("!REMOTE_KERNEL_USER!") do (
		set REMOTE_KERNEL_USER=%%S
		set REMOTE_KERNEL_PASSWORD=%%T
	)
)

rem parse SSH port number from host name
for /F "Delims=: Tokens=1,2" %%S in ("!REMOTE_KERNEL_HOST!") do (
	set REMOTE_KERNEL_HOST=%%S
	set REMOTE_KERNEL_PORT=%%T
)

rem add optional command line options
if defined REMOTE_KERNEL_USER set PUTTY_OPTS=!PUTTY_OPTS! -l "%REMOTE_KERNEL_USER%"
if defined REMOTE_KERNEL_PASSWORD set PUTTY_OPTS=!PUTTY_OPTS! -pw "%REMOTE_KERNEL_PASSWORD%"
if defined REMOTE_KERNEL_PORT set PUTTY_OPTS=!PUTTY_OPTS! -P !REMOTE_KERNEL_PORT!

rem compute port numbers to be used for preemptive and service links
if "%MAIN_LINK_DATA_PORT%" GEQ "%MAIN_LINK_MESSAGE_PORT%" (
	set BASE_PORT=!MAIN_LINK_DATA_PORT!
) else (
	set BASE_PORT=!MAIN_LINK_MESSAGE_PORT!
)
set /a PREEMPTIVE_LINK_DATA_PORT=!BASE_PORT! + 1
set /a PREEMPTIVE_LINK_MESSAGE_PORT=!BASE_PORT! + 2
set /a SERVICE_LINK_DATA_PORT=!BASE_PORT! + 3
set /a SERVICE_LINK_MESSAGE_PORT=!BASE_PORT! + 4

rem set up remote port forwardings for kernel main link
set PUTTY_OPTS=!PUTTY_OPTS! -R !LOOPBACK_IP_ADDR!:!MAIN_LINK_DATA_PORT!:!MAIN_LINK_HOST!:!MAIN_LINK_DATA_PORT!
set PUTTY_OPTS=!PUTTY_OPTS! -R !LOOPBACK_IP_ADDR!:!MAIN_LINK_MESSAGE_PORT!:!MAIN_LINK_HOST!:!MAIN_LINK_MESSAGE_PORT!

rem MathLink options
rem Mathematica kernel version >= 10.0 supports -wstp switch
if not "%REMOTE_KERNEL_PATH:10.=%" == "%REMOTE_KERNEL_PATH%" (
	set REMOTE_KERNEL_OPTS=-wstp
) else (
	set REMOTE_KERNEL_OPTS=-mathlink
)
set REMOTE_KERNEL_OPTS=!REMOTE_KERNEL_OPTS! -LinkMode Connect -LinkProtocol TCPIP -LinkName "%MAIN_LINK_LOOPBACK%"

rem Mathematica kernel options
rem force loading of the tunnel kernel init file
set REMOTE_KERNEL_OPTS=!REMOTE_KERNEL_OPTS! -initfile tunnel.m
rem -lmverbose print information to stderr on connecting to the license manager
set REMOTE_KERNEL_OPTS=!REMOTE_KERNEL_OPTS! -lmverbose

rem controller kernel specific options
rem the front end requires the launch command to stick around until kernel quits
set START_OPTS=/MIN /B /WAIT
rem set up local port forwardings for controller kernel preemptive link and service link
set PUTTY_OPTS=!PUTTY_OPTS! -L !LOOPBACK_IP_ADDR!:!PREEMPTIVE_LINK_DATA_PORT!:!LOOPBACK_IP_ADDR!:!PREEMPTIVE_LINK_DATA_PORT!
set PUTTY_OPTS=!PUTTY_OPTS! -L !LOOPBACK_IP_ADDR!:!PREEMPTIVE_LINK_MESSAGE_PORT!:!LOOPBACK_IP_ADDR!:!PREEMPTIVE_LINK_MESSAGE_PORT!
set PUTTY_OPTS=!PUTTY_OPTS! -L !LOOPBACK_IP_ADDR!:!SERVICE_LINK_DATA_PORT!:!LOOPBACK_IP_ADDR!:!SERVICE_LINK_DATA_PORT!
set PUTTY_OPTS=!PUTTY_OPTS! -L !LOOPBACK_IP_ADDR!:!SERVICE_LINK_MESSAGE_PORT!:!LOOPBACK_IP_ADDR!:!SERVICE_LINK_MESSAGE_PORT!

rem use short path form of PuTTY path to work around "start" command limitation.
rem start does not cope with spaces in the executable file path.
for %%P in ("%PUTTY_PATH%") do set PUTTY_PATH=%%~sP

rem log everything
echo REMOTE_KERNEL_ADDRESS=!REMOTE_KERNEL_ADDRESS! >> "%LOGFILE%"
echo REMOTE_KERNEL_HOST=!REMOTE_KERNEL_HOST! >> "%LOGFILE%"
if defined REMOTE_KERNEL_PORT echo REMOTE_KERNEL_PORT=!REMOTE_KERNEL_PORT! >> "%LOGFILE%"
if defined REMOTE_KERNEL_USER echo REMOTE_KERNEL_USER=!REMOTE_KERNEL_USER! >> "%LOGFILE%"
if defined REMOTE_KERNEL_PASSWORD echo REMOTE_KERNEL_PASSWORD=!REMOTE_KERNEL_PASSWORD! >> "%LOGFILE%"
echo REMOTE_KERNEL_PATH=!REMOTE_KERNEL_PATH! >> "%LOGFILE%"
if defined REMOTE_KERNEL_OPTS echo REMOTE_KERNEL_OPTS=!REMOTE_KERNEL_OPTS! >> "%LOGFILE%"
echo LINK_NAME=!LINK_NAME! >> "%LOGFILE%"
echo MAIN_LINK_DATA_PORT=!MAIN_LINK_DATA_PORT! >> "%LOGFILE%"
echo MAIN_LINK_MESSAGE_PORT=!MAIN_LINK_MESSAGE_PORT! >> "%LOGFILE%"
echo MAIN_LINK_LOOPBACK=!MAIN_LINK_LOOPBACK! >> "%LOGFILE%"
echo PREEMPTIVE_LINK_DATA_PORT=!PREEMPTIVE_LINK_DATA_PORT! >> "%LOGFILE%"
echo PREEMPTIVE_LINK_MESSAGE_PORT=!PREEMPTIVE_LINK_MESSAGE_PORT! >> "%LOGFILE%"
echo SERVICE_LINK_DATA_PORT=!SERVICE_LINK_DATA_PORT! >> "%LOGFILE%"
echo SERVICE_LINK_MESSAGE_PORT=!SERVICE_LINK_MESSAGE_PORT! >> "%LOGFILE%"
echo START_OPTS=!START_OPTS! >> "%LOGFILE%"
echo PUTTY_PATH=!PUTTY_PATH! >> "%LOGFILE%"
echo PUTTY_OPTS=!PUTTY_OPTS! >> "%LOGFILE%"

start !START_OPTS! !PUTTY_PATH! !PUTTY_OPTS! ^
	"%REMOTE_KERNEL_HOST%" ^
	"""%REMOTE_KERNEL_PATH%""" !REMOTE_KERNEL_OPTS! ^
	>> "%LOGFILE%" 2>&1
