#!/bin/bash

# Prepare a single T1w head MRI in stereotactic space for image analysis
# 12 parameter stereotactic regigstration
# Assume default installation for BEAST library and configuration files
# default template_path = '/opt/minc/share/icbm152_model_09c'
# Yiming Xiao, Feb 1, 2017


function usage {
echo "
Usage:
   T1-preprocess.sh <target_image.mnc> <template_path> <BEAST_path> <output_basename>
   The script outputs basename_stx.mnc, basename_mask_stx.mnc, base_name_stx.xfm, and base_name_pik.png
   The processed image is in ICBM152 space
"
}

set -e

input="$1"
template_PATH="$2"
BEAST_PATH="$3"
basename="$4"


if [ $# -ne 3 ]; then
  usage;
  exit 1;
fi

if [[ ! -d $template_PATH ] || [ ! -d $BEAST_PATH ] || [ ! -f $input]];then
  echo "one of the input/paths does not exist!"
  exit 1;
fi


TDIR=`mktemp -d`
trap "{ cd - ; rm -rf $TDIR; exit 255; }" SIGINT


# list of intermediate and final files
nu_1= $TDIR/$basename_nu_1.mnc
nu_2= $TDIR/$basename_nu_2.mnc
head_mni= $TDIR/$basename_head_mni.mnc
mask_mni= $TDIR/$basename_mask_mni.mnc
toTalxfm_1= $TDIR/$basename_toTal.xfm
toTalxfm_2= $basename_stx.xfm
mask= $TDIR/$basename_mask_native.mnc
brain= $TDIR/$basename_brain_native.mnc
final= $TDIR/$basename_final.mnc
final_2= $TDIR/$basename_final2.mnc
final_3= $TDIR/$basename_final3.mnc
norm= $basename_stx.mnc
pik= $basename_pik.png
mask_template= $basename_mask_stx.mnc


# 1. rough non-uniformity correction
N4BiasFieldCorrection -d 3 -b [200] -c [200x200x200x200,0.0] -i $input -o $nu_1

# 2.1 BEast skull stripping while putting the brain to the MNI space
beast_normalize $nu_1 $head_mni $toTalxfm_1 -modeldir $template_PATH
mincbeast -fill -median -conf $BEAST_PATH/default.1mm.conf $BEAST_PATH $head_mni $mask_mni

# 2.2 resample the mask back to the native space
mincresample $mask_mni -like $input -invert_transformation -transform $toTalxfm_1 $mask -short -nearest

# 2.3 remove the skull in the native space
minccalc -expr "A[0]>0.5?A[1]:0" $mask $input $brain -short -unsigned

# 3. refined N4 non-uniformity correction
N4BiasFieldCorrection -d 3 --verbose -r 1 -x $mask -b [400] -c [300x300x300x300x300,0.0] -i $brain -o $nu_2 --histogram-sharpening [0.05,0.01,1000]

# 4.1 Linear registration to target template ICBM152 or ADNI local
bestlinreg_s -lsq12 -nmi -source_mask $mask -target_mask $template_PATH/mni_icbm152_t1_tal_nlin_sym_09c_mask.mnc $nu_2 $template_PATH/mni_icbm152_t1_tal_nlin_sym_09c.mnc $toTalxfm_2 -clobber
#bestlinreg.pl -lsq12 -source_mask $mask -target_mask $MNItemplatePATH/mni_icbm152_t1_tal_nlin_sym_09c_mask.mnc $nu_2 $MNItemplatePATH/mni_icbm152_t1_tal_nlin_sym_09c.mnc $toTalxfm_2 -clobber

# 4.2 resample the image to ICBM sapce with 12 param registration
itk_resample --short --transform $toTalxfm_2 --like $template_PATH/mni_icbm152_t1_tal_nlin_sym_09c.mnc $nu_2 $final --clobber
mincresample -short -transform $toTalxfm_2 -like $template_PATH/mni_icbm152_t1_tal_nlin_sym_09c.mnc $nu_2 $final_2 -trilinear -clobber
minccalc -expr "A[0]<0?A[1]:A[0]" $final $final_2 $final_3 -short -signed -clobber

#5. intensity normalization
mincresample $mask -like $template_PATH/mni_icbm152_t1_tal_nlin_sym_09c.mnc -transform $toTalxfm_2 $mask_template -short -nearest
volume_pol --verbose --clobber --order 1 --noclamp --source_mask $mask_template --target_mask $template_PATH/mni_icbm152_t1_tal_nlin_sym_09c_mask.mnc $final_3 $template_PATH/mni_icbm152_t1_tal_nlin_sym_09c.mnc $norm

#6. quality check
mincpik --scale 2 $norm --slice 60 -z $pik -clobber



cd -
rm -rf $TDIR
exit 0
