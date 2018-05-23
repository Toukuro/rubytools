@echo off
if "%1" == "" goto USAGE

:DISPLAY
ruby c:\tools\dump.rb %1 %2 %3 %4
goto END

:USAGE
echo "usage: dump [-z] <in-files>"

:END
