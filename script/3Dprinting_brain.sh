#!/bin/bash
#3dprintyourbrain

# >>> PREREQUISITES:
#     Install FreeSurfer (v6.0.0), FSL and MeshLab on Linux.   
# 
# >>> FOLDER STRUCTURE:
#     3dbrain  -----   sub-01  -- input  -- struct.nii or struct.nii.gz
#      | smoothing.xml         -- output -- .stl files and intermediate folders   
#
#     !! The final smoothed full brain .stl file = final_s.stl
#                                  
# >>> INSTRUCTIONS:
#     * Create the folder structure so that you have: 
#       - a subject folder (e.g., sub-01) within the main folder (i.e., 3dbrain) containing 
#         struct.nii or struct.nii.gz which is a T1 MPRAGE NifTI file.
#       - the smoothing.xml file in your main folder (i.e., 3dbrain).
#     * Type in the command terminal, WITHIN the directory where this script resides:
#       ./3Dprinting_brain.sh  $MAIN_DIR $subject $MESHLAB_DIR
#       Three arguments: 
#       !! Change: 1. $MAIN_DIR to the correct 3dbrain directory, e.g. "/media/sofie/my_brains/3dbrain"
#                  2. $subject to the correct subject folder name, e.g., "sub-01"
#                  3. $MESHLAB_DIR to the correct MeshLab directory 
#                     (containing meshlabserver), e.g. "/usr/bin/"
#       => example: ./3Dprinting_brain.sh  "/media/sofie/my_brains/3dbrain" "me" "/usr/bin"

# REMARK: This script is the result of a BrainHackGhent2018 project 
#         (https://brainhackghent.github.io/#3Dprint), part of BrainHackGlobal2018
#         by Sofie Van Den Bossche, James Deraeve, Thibault Sanders and Robin De Pauw.
#         Further adaptations could include: the creation of seperate L and R hemispheres, 
#         hollowing the inside of the 3D brain model in order to cut the price, 
#         rescaling the 3D brain model, etc.

#==========================================================================================
# 1. Specify variables
#==========================================================================================

# Main folder for the whole project
export MAIN_DIR=$1

# Name of the subject
export subject=$2

# Path to the structural image (input folder)
cd $MAIN_DIR/${subject}/input/
if [ -z "$(find . -maxdepth 1 -name '*struct.nii.gz*')" ]; then
    gzip struct.nii
fi
export subjT1=$MAIN_DIR/${subject}/input/struct.nii.gz

# Path to the subject (output folder)
export SUBJECTS_DIR=$MAIN_DIR/${subject}/output

# Path to meshlabserver 
export MESHLAB_DIR=$3

#==========================================================================================
#2. Create Surface Model with FreeSurfer
#==========================================================================================

mkdir -p $SUBJECTS_DIR/mri/orig
mri_convert ${subjT1} $SUBJECTS_DIR/mri/orig/001.mgz
recon-all -subjid "output" -all -time -log logfile -nuintensitycor-3T -sd "$MAIN_DIR/${subject}/" -parallel

#==========================================================================================
#3. Create 3D Model of Cortical and Subcortical Areas
#==========================================================================================

# CORTICAL
# Convert output of step (2) to fsl-format
mris_convert --combinesurfs $SUBJECTS_DIR/surf/lh.pial $SUBJECTS_DIR/surf/rh.pial \
             $SUBJECTS_DIR/cortical.stl

# SUBCORTICAL
mkdir -p $SUBJECTS_DIR/subcortical
# First, convert aseg.mgz into NIfTI format
mri_convert $SUBJECTS_DIR/mri/aseg.mgz $SUBJECTS_DIR/subcortical/subcortical.nii

# Second, binarize all areas that you're not interested and inverse the binarization
mri_binarize --i $SUBJECTS_DIR/subcortical/subcortical.nii \
             --match 2 3 24 31 41 42 63 72 77 51 52 13 12 43 50 4 11 26 58 49 10 17 18 53 54 44 5 80 14 15 30 62 \
             --inv \
             --o $SUBJECTS_DIR/subcortical/bin.nii

# Third, multiply the original aseg.mgz file with the binarized files
fslmaths $SUBJECTS_DIR/subcortical/subcortical.nii \
         -mul $SUBJECTS_DIR/subcortical/bin.nii \
         $SUBJECTS_DIR/subcortical/subcortical.nii.gz

# Fourth, copy original file to create a temporary file
cp $SUBJECTS_DIR/subcortical/subcortical.nii.gz $SUBJECTS_DIR/subcortical/subcortical_tmp.nii.gz

# Fifth, unzip this file
gunzip -f $SUBJECTS_DIR/subcortical/subcortical_tmp.nii.gz

# Sixth, check all areas of interest for wholes and fill them out if necessary
for i in 7 8 16 28 46 47 60 251 252 253 254 255
do
    mri_pretess $SUBJECTS_DIR/subcortical/subcortical_tmp.nii \
    $i \
    $SUBJECTS_DIR/mri/norm.mgz \
    $SUBJECTS_DIR/subcortical/subcortical_tmp.nii
done

# Seventh, binarize the whole volume
fslmaths $SUBJECTS_DIR/subcortical/subcortical_tmp.nii -bin $SUBJECTS_DIR/subcortical/subcortical_bin.nii

# Eighth, create a surface model of the binarized volume with mri_tessellate
mri_tessellate $SUBJECTS_DIR/subcortical/subcortical_bin.nii.gz 1 $SUBJECTS_DIR/subcortical/subcortical

# Ninth, convert binary surface output into stl format
mris_convert $SUBJECTS_DIR/subcortical/subcortical $SUBJECTS_DIR/subcortical.stl

#==========================================================================================
#4. Combine Cortical and Subcortial 3D Models
#==========================================================================================

echo 'solid '$SUBJECTS_DIR'/final.stl' > $SUBJECTS_DIR/final.stl
sed '/solid vcg/d' $SUBJECTS_DIR/cortical.stl >> $SUBJECTS_DIR/final.stl
sed '/solid vcg/d' $SUBJECTS_DIR/subcortical.stl >> $SUBJECTS_DIR/final.stl
echo 'endsolid '$SUBJECTS_DIR'/final.stl' >> $SUBJECTS_DIR/final.stl

#==========================================================================================
#5. ScaleDependent Laplacian Smoothing, create a smoother surface: MeshLab
#==========================================================================================

$MESHLAB_DIR/meshlabserver -i $SUBJECTS_DIR/final.stl -o $SUBJECTS_DIR/final_s.stl -s $MAIN_DIR/smoothing.mlx
