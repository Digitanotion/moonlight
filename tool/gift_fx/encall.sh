#!/bin/zsh
cd ${0:A:h}/..
g=$1
case $g in
  eagle|car|gold_ring|diamond|gold|cucumber|jewelry|universe|handbag) br=2400000;;
  elephant) br=1500000;;
  rose|wine|perfume|pizza|bible|quran) br=2000000;;
  ice_cream|milk|satsuma|kiwi|cranberry) br=900000;;
  *) br=1200000;;
esac
tool/sbs k/$g src/$g.mp4 fx/$g.mp4 24 $br >/dev/null 2>&1 && echo "$g $(stat -f %z fx/$g.mp4)" || echo "$g FAILED"
