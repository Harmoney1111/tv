@echo off
title Revell T.V
rem Opens the Revell T.V channels in VLC media player. The list is read from
rem the web every time, so it is always the latest one.
set "LIST=https://harmoney1111.github.io/tv/english-tv.m3u"

set "VLC=%ProgramFiles%\VideoLAN\VLC\vlc.exe"
if exist "%VLC%" goto watch
set "VLC=%ProgramFiles(x86)%\VideoLAN\VLC\vlc.exe"
if exist "%VLC%" goto watch

echo.
echo  VLC media player is not installed yet.
echo  The VLC website will open now. Click "Download VLC", run the file,
echo  and when it has finished, double-click Revell-TV again.
echo.
start "" "https://www.videolan.org/vlc/"
pause
exit /b 1

:watch
start "" "%VLC%" "%LIST%"
exit /b 0
