#! /bin/bash

co=0
w=2
PFX="i"

for i in *.jpg; do
    echo mv "$i" "$(printf "$PFX%0${w}d.jpg" $co )"
    co=$(( $co + 1 ))
done
