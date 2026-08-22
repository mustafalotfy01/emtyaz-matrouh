@echo off
title MANU Web Server (Port 3000)
cd /d "%~dp0"
echo ===================================================
echo   MANU Web Server is running on http://localhost:3000
echo ===================================================
node server.js
pause