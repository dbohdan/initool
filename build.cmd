@echo off
rem Detect the path to mosmlc.exe and MOSMLLIB.
set mosml1=mosml
set mosml2=C:\Program Files\mosml
set mosml3=C:\Program Files (x86)\mosml
set mosml4=C:\mosml

if exist "%mosml1%\bin\mosmlc.exe" set mosml=%mosml1%
if exist "%mosml2%\bin\mosmlc.exe" set mosml=%mosml2%
if exist "%mosml3%\bin\mosmlc.exe" set mosml=%mosml3%
if exist "%mosml4%\bin\mosmlc.exe" set mosml=%mosml4%
set mosmlc="%mosml%\bin\mosmlc.exe"
set mosmllib=%mosml%\lib\mosml

if not exist %mosmlc% (
    echo Error: mosmlc.exe not found
    exit /b 1
)

rem Process the command line arguments.
set flag_batch=0
set flag_package=0
for %%a in (%*) do (
    if "%%a"=="/batch" set flag_batch=1
    if "%%a"=="/package" set flag_package=1
)

rem Build initool.
echo on
del *.ui *.uo
%mosmlc% -toplevel stringtrim.sml ini.sml initool.sml -o initool.exe
@echo off
if errorlevel 1 exit /b 1

rem Perform optional actions based on the flags that are set.
if "%flag_package%"=="1" goto package
:package_return
if "%flag_batch%"=="0" pause
exit /b 0

rem ----------------------------------------------------------------------------

rem The packaging subroutine. Packages camlrt.dll and initool.exe in a ZIP
rem archive. Requires that 7z.exe be available. Includes the current commit
rem in the archive's filename if git.exe is.
:package
echo on
copy "%mosml%\bin\camlrt.dll" .
@echo off

rem Read the initool version.
set /p version=<VERSION

rem Get the current commit's SHA-1.
set commit=current
git rev-parse HEAD > current-commit
if not errorlevel 1 set /p commit=<current-commit
del current-commit > nul

rem Create the ZIP archive.
set archive=initool-v%version%-%commit:~0,7%-win32.zip

echo on
7z a %archive% camlrt.dll initool.exe
@echo off
if errorlevel 1 exit /b 1

goto package_return
