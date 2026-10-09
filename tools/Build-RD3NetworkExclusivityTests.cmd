@echo off
call "F:\Software\Embarcadero\Studio\37.0\bin\rsvars.bat"
"F:\Software\Embarcadero\Studio\37.0\bin\dcc64.exe" -B -NS"System;System.Win;Winapi;Vcl" -U"source;E:\Projects\third-party\dependencies\synapse" -E"tools" "tools\RD3NetworkExclusivityTests.dpr"
exit /b %errorlevel%
