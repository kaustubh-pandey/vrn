#!/usr/bin/env bash


INPUT="examples/"            
OUTPUT="output/"             
VRN_MODEL="vrn-unguided.t7"  
CUDA_VISIBLE_DEVICES=0       

######################################################################
# The rest of the code
mkdir -p $OUTPUT
mkdir -p $INPUT/scaled

pushd face-alignment > /dev/null
th main.lua -model 2D-FAN-300W.t7 \
   -input ../$INPUT/ \
   -detectFaces true \
   -mode generate \
   -output ../$INPUT/ \
   -device gpu \
   -outputFormat txt
popd > /dev/null


pushd $INPUT > /dev/null
ls -1 *.txt | \
    while read fname; do
	awk -F, 'BEGIN {
                   minX=1000;
                   maxX=0;
                   minY=1000;
                   maxY=0;
                 }
                 $1 > maxX { maxX=$1 }
                 $1 < minX { minX=$1 }
                 $2 > maxY { maxY=$2 }
                 $2 < minY { minY=$2 }
                 END {
                   scale=90/sqrt((minX-maxX)*(minY-maxY));
                   width=maxX-minX;
                   height=maxY-minY;
                   cenX=width/2;
                   cenY=height/2;
                   printf "%s %s %s %s\n",
                     FILENAME,
                     (minX-cenX)*scale,
                     (minY-cenY)*scale,
                     (scale)*100
        }' $fname
    done > crop.tmp


cat crop.tmp | sed 's/.txt/.jpg/' | \
    while read fname x y scale; do
	convert $fname \
		-scale $scale% \
		-crop 192x192+$x+$y \
		-background white \
		-gravity center \
		-extent 192x192 \
		scaled/$fname
	 echo "Cropped and scaled $fname"
     done

rm crop.tmp
popd > /dev/null


th process.lua \
   --model $VRN_MODEL \
   --input $INPUT/scaled \
   --output $OUTPUT \
   --device gpu


pushd output > /dev/null
ls -1 *.raw | sed 's/.raw//' | while read fname ; do
    python ../vis.py \
	   --image ../$INPUT/scaled/$fname.jpg \
	   --volume $fname.raw
    done
popd > /dev/null

