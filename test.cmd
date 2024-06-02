@echo off

rem Process command-line arguments.
set flag_batch=0
for %%a in (%*) do (
    if "%%a"=="/batch" set flag_batch=1
)

echo on
busybox.exe sh -c "INITOOL=./initool.exe sh test.sh"
@echo off

if "%flag_batch%"=="0" pause
exit /b 0
