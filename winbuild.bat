set P1=absinthe-diag
set P2=fille-diag
set P3=monty2
set LION=rousseau-cropx

set PNG2PIC="tools\png2db-arzak.py"
set SALVADOR="tools\salvador.exe"

python3 %PNG2PIC% -mode spiralbox -leftofs 32 %P1%.png
python3 %PNG2PIC% -mode spiralbox -leftofs 64 -topofs 16 %P2%.png
python3 %PNG2PIC% -mode spiralbox -topofs 16 %P3%.png
python3 %PNG2PIC% -mode spiralbox -zdb -leftofs 160 -topofs 104 %LION%.png
del /s lion.inc
ren %LION%.inc lion.inc

tasm\tasm -85 -b grad.asm grad.bin  || exit /b 1

copy /b %P1%.pal+%P1%.pic+%P2%.pal+%P2%.pic+%P3%.pal+%P3%.pic tmp\pic2.pic
%SALVADOR% -classic -w 256 tmp\pic2.pic tmp\piz.dat
copy /b grad.bin+tmp\piz.dat progdemo.rom


