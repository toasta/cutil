#! /bin/bash

set -eEo pipefail

e=echo
e=

url=$1
shift

TMPD=/dev/shm/recode/
mkdir -p $TMPD
EXT="rc.h265.mkv"
#EXT="rc.h265.mp4"


####################################
if [[ "$url" == http* ]]; then
    TMPF=$(mktemp -p /dev/shm/)
    curl -s -I  "$url" > $TMPF
    fn=$(cat $TMPF | grep ^content-disposition | perl -pe 's/.*filename="(.+)".*/$1/')
    size=$(cat $TMPF | grep ^content-length | perl -pe 's/^content-length: (\d+).*$/$1/')
    rm $TMPF
else
    fn=$( basename "$url" )
    size=$(stat "$url" --format "%s")
fi
####################################

oext=".mkv"

OF="${TMPD}/${fn%%$oext}.$EXT"

if [ -s "$OF" ]; then
    echo "file '$OF' already exists; exiting"
    exit 0
fi


gpu_switch=""
num_gpus=$(nvidia-smi -L | wc -l)

if [ $num_gpus -ge 2 ]; then
    echo "more than one gpu, using the one with least compute-apps running"
    echo "sleeping a random amount so not all jobs started at exactly the same"
    echo "time see all gpus as unused"
    sleep .$(( ($RANDOM % 9) + 1 ))
    best_gpu=0
    best_gpu_score=0
    selected_gpu_score=$(nvidia-smi --query-compute-apps=pid --format="csv,noheader,nounits" -i 0 | wc -l )
    best_gpu_score=$selected_gpu_score

    num_gpus=$(( $num_gpus - 1 ))

    i=1
    while [ $i -le $num_gpus ]; do
        selected_gpu_score=$(nvidia-smi --query-compute-apps=pid --format="csv,noheader,nounits" -i $i | wc -l )
        if [ $selected_gpu_score -lt $best_gpu_score ]; then
            best_gpu_score=$selected_gpu_score
            best_gpu=$i
        fi

        i=$(( $i + 1 ))
    done
    echo "Chosen gpu # $best_gpu w/ score $best_gpu_score"
    gpu_switch="-gpu $best_gpu"
fi


#e=echo

$e ffmpeg \
    -hide_banner \
    -y -nostdin \
    -i "$url" \
    -c:v hevc_nvenc \
    $gpu_switch \
    -preset p7 -tune hq \
    -rc constqp -qp 28 \
    -pix_fmt p010le \
    -rc-lookahead 100 \
    -c:a aac \
    "$OF" 
    #-c:a copy \

SIZE_R=$(stat "$OF" --format "%s")

$e ls -al "$OF"
echo "old size $size, new size $SIZE_R : $( echo "scale=2; $SIZE_R / $size" | bc -q)"

