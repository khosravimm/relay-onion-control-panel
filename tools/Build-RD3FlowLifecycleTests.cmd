@echo off
call "F:\Software\Embarcadero\Studio\37.0\bin\rsvars.bat"
"F:\Software\Embarcadero\Studio\37.0\bin\dcc64.exe" -B -NS"System;System.Win;Winapi;Vcl" -U"source" -E"tools" "tools\RD3FlowLifecycleTests.dpr"
exit /b %errorlevel%
