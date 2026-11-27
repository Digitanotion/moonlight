#!/bin/zsh
# keyall.sh <gift> → k/<gift>/f*.png
cd ${0:A:h}/..
g=$1
case $g in
  eagle|car|gold_ring|diamond|gold|cucumber|jewelry|universe|handbag|rose|wine|perfume|pizza|bible|quran) w=540;;
  ice_cream|milk|satsuma|elephant|kiwi|cranberry) w=360;;
  *) w=480;;
esac
rm -rf k/$g 2>/dev/null
warm=1; lo=30; hi=70; fade=0
case $g in
  bible|elephant|kiwi) warm=2;;   # purple glow → gold
  wine) lo=14; hi=38;;       # dark glass that reflects the backdrop stays solid
  car) fade=0.22;;           # road fades out at the bottom
esac
WARM=$warm FADE=$fade tool/vk key src/$g.mp4 k/$g $w 24 $lo $hi | grep -E "mode|frames" | tr '\n' ' '
echo " $g w=$w"
