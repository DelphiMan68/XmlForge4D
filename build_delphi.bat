@echo off
rem Builds and runs the XmlForge4D test suite with Delphi (run from a "RAD Studio Command Prompt").
setlocal
cd /d "%~dp0"
if not exist build\dcu mkdir build\dcu
if not exist build\bin mkdir build\bin
dcc64 -B -Q -U"src;tests" -I"src" -N0build\dcu -E"build\bin" tests\XmlForge4DTests.dpr || exit /b 1
build\bin\XmlForge4DTests.exe
exit /b %errorlevel%
