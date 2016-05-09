@echo off
set mosmlc1="C:\Program Files\mosml\bin\mosmlc.exe"
set mosmlc2="C:\Program Files (x86)\mosml\bin\mosmlc.exe"

if exist %mosmlc1% set mosmlc=%mosmlc1%
if exist %mosmlc2% set mosmlc=%mosmlc2%

if not exist %mosmlc% (
    echo Error: mosmlc.exe not found
    exit /b 1
)

echo on
del *.ui *.uo
%mosmlc% -toplevel stringtrim.sml ini-sig.sml ini.sml initool.sml -o initool.exe

@if not !%1%!==!/s! pause
@exit /b 0
