@echo off
rem Detect the path to mosmlc.exe and MOSMLLIB.
set mosml1=C:\Program Files\mosml
set mosml2=C:\Program Files (x86)\mosml

if exist "%mosml1%\bin\mosmlc.exe" set mosml=%mosml1%
if exist "%mosml2%\bin\mosmlc.exe" set mosml=%mosml2%
set mosmlc="%mosml%\bin\mosmlc.exe"
set mosmllib=%mosml%\lib\mosml

if not exist %mosmlc% (
    echo Error: mosmlc.exe not found
    exit /b 1
)

rem Process the command line arguments.
set flag_batch=0
for %%a in (%*) do (
    if !%%a!==!/batch! set flag_batch=1
)

rem Build initool.
echo on
del *.ui *.uo
%mosmlc% -toplevel stringtrim.sml ini-sig.sml ini.sml initool.sml -o initool.exe
@if errorlevel 1 exit /b 1

@rem Perform optional actions based on the flags that are set.
@if !%flag_batch%!==!0! pause
@exit /b 0
