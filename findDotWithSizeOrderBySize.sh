#! /bin/bash 

find . -type f -printf "%s %p\n" | sort -n -k 1,1 $@
