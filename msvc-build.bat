@echo off
rem Copyright (C) 2008-2012 Alon Bar-Lev <alon.barlev@gmail.com>
rem Copyright (C) 2017 Simon Rozman <simon@rozman.si>

setlocal

cd /d %0\..

if "%VCINSTALLDIR%"=="" (
	echo VCINSTALLDIR is not defined.
	echo This command should be called from "Developer Command Prompt for VS 2017".
	goto error
)

MSBuild.exe /help > nul 2>&1
if errorlevel 1 (
	echo MSBuild.exe not found or failed. Is path to MSBuild.exe included in path?
	echo This command should be called from "Developer Command Prompt for VS 2017".
	goto error
)

set PLATFORMS=Win32 x64
set CONFIGURATIONS=Release

for %%p in (%PLATFORMS%) do (
	if %%p=="Win32" call "%VCINSTALLDIR%Auxiliary\Build\vcvarsall.bat" x86
	if %%p=="x64"   call "%VCINSTALLDIR%Auxiliary\Build\vcvarsall.bat" amd64
	for %%c in (%CONFIGURATIONS%) do (
		rmdir /q /s %SOURCEBASE%\%%p\%%c > nul 2>&1

		MSBuild.exe openvpn.sln /p:Configuration="%%c" /p:Platform="%%p"
		if errorlevel 1 goto error
	)
)

exit /b 0
goto end

:error
exit /b 1
goto end

:end

endlocal
