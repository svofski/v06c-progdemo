set P1=absinthe-diag
set P2=fille-diag
set P3=monty2
set LION=rousseau-crop

set PNG2PIC="tools\png2db-arzak.py"
set SALVADOR="tools\salvador.exe"

python3 %PNG2PIC% -mode spiralbox %P1%.png
python3 %PNG2PIC% -mode spiralbox %P2%.png
python3 %PNG2PIC% -mode spiralbox %P3%.png
python3 %PNG2PIC% -mode spiralbox -zdb %LION%.png
del /s lion.inc
ren %LION%.inc lion.inc

tasm\tasm -85 -b grad.asm

copy /b %P1%.pal+%P1%.pic+%P2%.pal+%P2%.pic+%P3%.pal+%P3%.pic tmp\pic2.pic
%SALVADOR% -classic -w 256 tmp\pic2.pic tmp\piz.dat
copy /b grad.bin+tmp\piz.dat progdemo2.rom


