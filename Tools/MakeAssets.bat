echo off
REM MakeAssets.bat

SET filename=%~n1

bmp2tile.exe %1 -savepalette %filename%Palette.inc -savetiles %filename%Tiles.inc -savetilemap %filename%Tilemap.inc -exit

SET incfile=%filename%Assets.inc
ECHO %filename%Palette: > %incfile%
TYPE %filename%Palette.inc >> %incfile%
ECHO.>> %incfile%
ECHO %filename%Tiles: >> %incfile%
TYPE %filename%Tiles.inc >> %incfile%
ECHO.>> %incfile%
ECHO %filename%Tilemap: >> %incfile%
TYPE %filename%Tilemap.inc >> %incfile%

del %filename%Palette.inc
del %filename%Tiles.inc
del %filename%Tilemap.inc
