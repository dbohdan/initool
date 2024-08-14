@echo off
setlocal enabledelayedexpansion

for %%a in (%*) do (
    if "%%a"=="-h" (
        goto :help
    )
    if "%%a"=="--help" (
        goto :help
    )
)

if "%~2"=="" (
    goto :error_usage
)

set "command=%~1"
set "file=%~2"
set status=0
set overwrite=1

if "%command%"=="e" (
    set overwrite=0
)
if "%command%"=="exists" (
    set overwrite=0
)

if "%file%"=="-" (
    echo file must not be "-" 1>&2
    exit /b 2
)

:create_temp
set "temp=%temp%\initool-in-place-%random%.tmp"
if exist "!temp!" goto :create_temp

if defined INITOOL (
    "!INITOOL!" %* > "!temp!"
) else (
    initool %* > "!temp!"
)

set status=%errorlevel%
if %status% equ 0 (
    if %overwrite% equ 1 (
        copy /y "!temp!" "%file%" > nul
    )
)

:cleanup
del "%temp%"
exit /b %status%

:error_usage
echo usage: %~nx0 command file [arg ...] 1>&2
exit /b 2

:help
echo Modify the input file with initool.
echo.
echo usage: %~nx0 command file [arg ...]
echo.
echo You can give the path to initool in the environment variable "INITOOL".
exit /b
