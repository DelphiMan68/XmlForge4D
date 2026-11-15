@echo off
rem Builds and runs the XmlForge4D test suite with Free Pascal on Windows.
setlocal
cd /d "%~dp0"
if not exist build\units mkdir build\units
if not exist build\bin mkdir build\bin
set FLAGS=-Mdelphiunicode -Fusrc -Futests -Fubenchmarks -FUbuild\units -FEbuild\bin -O2 -vewnh
fpc %FLAGS% tests\XmlForge4DTests.lpr || exit /b 1
build\bin\XmlForge4DTests.exe
exit /b %errorlevel%
