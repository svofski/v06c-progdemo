#!/bin/sh
set -x
set -e
PNG2DB=tools/png2db-arzak.py
SALVADOR=tools/salvador.exe
PASM=prettyasm/main.js
YM6BRK=tools/ym6break.py

SONGE="sparkmonty53"
#SONGE="manofart"
#SONGE="kurtibm"
#SONGE="exengine"

if ! test -e songe.inc ; then
  $YM6BRK music/$SONGE.ym songA_
  mv $SONGE.inc songe.inc
fi

SRCPIC=$1
SRCPIC2=$2
SRCPIC3=$3
name=`basename $SRCPIC .png`
spiralpic=$name.pic
spiralpal=$name.pal
spiralpiz=$name.piz

name2=`basename $SRCPIC2 .png`
spiralpic2=$name2.pic
spiralpal2=$name2.pal
spiralpiz2=$name2.piz

name3=`basename $SRCPIC3 .png`
spiralpic3=$name3.pic
spiralpal3=$name3.pal
spiralpiz3=$name3.piz

$PASM grad.asm -o grad.bin

$PNG2DB -mode spiralbox $SRCPIC
$PNG2DB -mode spiralbox $SRCPIC2
$PNG2DB -mode spiralbox $SRCPIC3

cat $spiralpal $spiralpic $spiralpal2 $spiralpic2 $spiralpal3 $spiralpic3 > tmp/pic2.pic
$SALVADOR -w 256 -classic tmp/pic2.pic $spiralpiz
#$SALVADOR -w 256 -classic $spiralpic $spiralpiz
# 
cat grad.bin $spiralpal $spiralpiz >$name.rom
