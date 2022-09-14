#!/bin/sh
set -x
set -e
PNG2DB=tools/png2db-arzak.py
SALVADOR=tools/salvador.exe
PASM=prettyasm/main.js
YM6BRK=tools/ym6break.py

#SONGE="manofart"
#SONGE="kurtibm"
SONGE="exengine"

if ! test -e songe.inc ; then
  $YM6BRK music/$SONGE.ym songA_
  mv $SONGE.inc songe.inc
fi

SRCPIC=$1
name=`basename $SRCPIC .png`
spiralpic=$name.pic
spiralpal=$name.pal
spiralpiz=$name.piz

$PASM grad.asm -o grad.bin

$PNG2DB -mode spiralbox $SRCPIC

$SALVADOR -w 256 -classic $spiralpic $spiralpiz
 
cat grad.bin $spiralpal $spiralpiz >$name.rom
