#!/bin/bash

# multi-class label fusion with fuzzy labels
# the atlas library should only contain basenames of the templates and label maps
# for example, $basename_t1.mnc & $basename_label.mnc
# Yiming Xiao, March 4th, 2017


function usage {
echo "

Usage:
   MultiLabelfusion.sh <target_image.mnc> <library_list.txt> <ref_vol> <workdir> <output.mnc>

   library_list.txt should only contain the basename of the lib subject

"
}

set -e

target="$1"
libList="$2"
ref_vol="$3"
workDir="$4"
output="$5"


if [[ ! -d $workDir ]];then
  mkdir $workDir
else
  echo "$workDir exists!"
  usage;
  exit 1;
fi


# read the first lable file
modellabel=$(head -n 1 $libList)
print_all_labels $modellabel-label.mnc >> $workDir/labelfile.txt
labelList=$workDir/labelfile.txt
classNum=$(wc -l < $labelList)


if [ $# -ne 5 ] || [ $classNum -lt 2 ]; then
  usage;
  exit 1;
fi


# get the label number and IDs

declare -a labelID

idCount=0
while IFS= read -r line
do

  IFS=':' read -r title content <<< "$line"
  IFS=' ' read -r id vox <<< "$content"

  labelID[$idCount]=$id # read in all the label IDs
  idCount=$[idCount + 1]
  echo $id

done <"$labelList"

echo "${labelID[0]}"



COUNT=0
# go through the library list to genate deformation and resample labels
for file in $(<$libList)
do

  COUNT=$[COUNT + 1] # ID number for library subject
  atlas=$file-label.mnc  # label files
  t1=$file-T1.mnc # T1 images # not really very useful in stx space
  t2=$file-T2.mnc # T2 images



  # do nonlinear local region registration
  antsRegistration --minc -a 1 -d 3 -m CC[$t2,$target,1,4] -s 4x2x1x0vox -f 6x4x2x1 -c [100x100x70x20,1e-6,10] -t SyN[0.25,3,0] -o $workDir/Libsub$COUNT-to-target


  # isolate the labels from the general map, then deform them

  for j in $(seq 1 $classNum)
  do

     k=${labelID[$[j - 1]]}

    Lup=$(echo "scale=2; $k + 0.5" | bc)
    Lup=$(printf "%.2g" $Lup)
    Lbl=$(echo "scale=2; $k - 0.5" | bc)
    Lbl=$(printf "%.2g" $Lbl)

    # named labels
    minccalc -expr "(A[0]<$Lup && A[0]>$Lbl)?1:0"  $atlas $workDir/Libsub$COUNT-label-$j.mnc -byte -clobber
    mincresample $workDir/Libsub$COUNT-label-$j.mnc -like $ref_vol -transform $workDir/Libsub$COUNT-to-target.xfm $workDir/Libsub$COUNT-label-$j-deform.mnc -short -clobber

  done
  # background label
  minccalc -expr "A[0]>0.5?1:0" $atlas $workDir/Libsub$COUNT-label-all.mnc -byte -clobber
  mincresample $workDir/Libsub$COUNT-label-all.mnc -like $ref_vol -transform $workDir/Libsub$COUNT-to-target.xfm $workDir/Libsub$COUNT-alllabels-deform.mnc -short -clobber

  # normalize labels
  minccalc -expr "1-A[0]" $workDir/Libsub$COUNT-alllabels-deform.mnc $workDir/Libsub$COUNT-label-0-norm.mnc -short -clobber


  # sum over all labels
  mincaverage $workDir/Libsub$COUNT-label-*-deform.mnc $workDir/Libsub$COUNT-labels.mnc -short -clobber
  minccalc -expr "A[0]*$classNum" $workDir/Libsub$COUNT-labels.mnc $workDir/Libsub$COUNT-labels-baseline.mnc -short -clobber


  for i in $(seq 1 $classNum)
  do

    minccalc -expr "A[0]*A[1]/A[2]" $workDir/Libsub$COUNT-alllabels-deform.mnc $workDir/Libsub$COUNT-label-$i-deform.mnc $workDir/Libsub$COUNT-labels-baseline.mnc  $workDir/Libsub$COUNT-label-$i-norm.mnc -clobber -short

  done

done


# average all the lib subjects for particular labels
for i in $(seq 0 $classNum)
do

  mincaverage  $workDir/Libsub*-label-$i-norm.mnc  $workDir/All-label-$i-norm.mnc -short -clobber

done


# first deal with the background
# update label
minccalc -expr "A[0]>A[1]?0:${labelID[0]}"  $workDir/All-label-0-norm.mnc $workDir/All-label-1-norm.mnc $workDir/Final-label-1-norm.mnc -short -clobber
# update prob map
minccalc -expr "A[0]>A[1]?A[0]:A[1]" $workDir/All-label-0-norm.mnc $workDir/All-label-1-norm.mnc $workDir/Final-value-1-norm.mnc -short -clobber


# deal with the rest of the labels to produce the final labels
for i in $(seq 2 $classNum)
do

  k=${labelID[$[i - 1]]}
  # update label
  minccalc -expr "A[0]>A[1]?A[2]:$k"  $workDir/Final-value-$[i - 1]-norm.mnc $workDir/All-label-$i-norm.mnc $workDir/Final-label-$[i - 1]-norm.mnc $workDir/Final-label-$i-norm.mnc -short -clobber
  # update prob map
  minccalc -expr "A[0]>A[1]?A[0]:A[1]" $workDir/Final-value-$[i - 1]-norm.mnc $workDir/All-label-$i-norm.mnc $workDir/Final-value-$i-norm.mnc -short -clobber


done

# fix the output
cp $workDir/Final-label-$classNum-norm.mnc  $output

# remove the work directory
#rm -r $workDir
