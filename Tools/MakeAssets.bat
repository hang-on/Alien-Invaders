echo off
REM MakeAssets.bat

SET filename=%~n1

bmp2tile.exe %1 -savepalette %filename%Palette.inc -fullpalette -savetiles %filename%Tiles.inc -savetilemap %filename%Tilemap.inc -exit

REM Write palette
SET incfile=%filename%Assets.inc
ECHO %filename%Palette: > %incfile%
TYPE %filename%Palette.inc >> %incfile%

REM Write tilemap
ECHO.>> %incfile%
ECHO %filename%Tilemap: >> %incfile%
TYPE %filename%Tilemap.inc >> %incfile%

REM Write tiles
ECHO.>> %incfile%
ECHO %filename%Tiles: >> %incfile%
TYPE %filename%Tiles.inc >> %incfile%

REM Clean up mess
del %filename%Palette.inc
del %filename%Tiles.inc
del %filename%Tilemap.inc
