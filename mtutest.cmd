@echo off
:: A script to automagically determine the ideal Maximum Transmission Unit (MTU) size
::
::  Author @michealespinola https://github.com/michealespinola/mtutest

setlocal enabledelayedexpansion

:: The IP address or hostname to ping
set TARGET=1.1.1.1

:: Initial range for buffer size
set LOWER_BOUND=1
set UPPER_BOUND=65500

:: Function to perform a ping with the given buffer size
set PING_CMD=ping -n 1 -w 1000 -f -l 

echo.
echo Starting MTU buffer check for %UPPER_BOUND% bytes against %TARGET%...

echo.

call :ping_test %UPPER_BOUND%
if not defined FRAGMENTED (
    set MAX_BUFFER=%UPPER_BOUND%
) else (
    echo Ping Buffer: %UPPER_BOUND% bytes ^(fragmented^)
    set /a UPPER_BOUND-=1
)

:: Binary search to find the maximum buffer size
:binary_search
set /a MID=(LOWER_BOUND + UPPER_BOUND) / 2
call :ping_test %MID%
if not defined FRAGMENTED (
    echo Ping Buffer: %MID% bytes
    set LOWER_BOUND=%MID%
) else (
    echo Ping Buffer: %MID% bytes ^(fragmented^)
    set UPPER_BOUND=%MID%
)

SET /A LOWER_BOUND_PLUS=%LOWER_BOUND% + 1
if %UPPER_BOUND% GTR %LOWER_BOUND_PLUS% goto binary_search

:: LOWER_BOUND should now be the maximum buffer size that doesn't fragment
set MAX_BUFFER=%LOWER_BOUND%

:: Calculate the ideal MTU
set IP_HEADER=20
set ICMP_HEADER=8
set /a IDEAL_MTU=MAX_BUFFER + IP_HEADER + ICMP_HEADER

:: Final output
echo              ----
echo  Max Buffer: %MAX_BUFFER% bytes
echo   IP Header: %IP_HEADER% bytes
echo ICMP Header: %ICMP_HEADER% bytes
echo              ----
echo   IDEAL MTU: %IDEAL_MTU%
echo.
goto :end

:ping_test
set FRAGMENTED=
for /f "tokens=*" %%A in ('%PING_CMD% %1 %TARGET%') do (
    echo "%%A" | findstr "fragmented bad value" >nul
    if not errorlevel 1 (
        set FRAGMENTED=1
    )
)
goto :eof

:end

:eof
