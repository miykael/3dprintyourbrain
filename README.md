# 3D print your brain

So, you want to 3D print your own brain? The following is a step by step guide that will show you how you can 3D print a brain, all coming from a structural image (T1) like this:

<img src="static/brain.png" width="400">

**Note:** To create a 3D surface model of your brain we will use FreeSurfer and meshlab. Therefore you should make sure that those two softwares are already installed on your system.


1. Specify Variables
--------------------

Let's first specify all necessary variables that we need for this to work:

```bash
export EXPERIMENT_DIR=/users/mnotter/tmp
export SUBJECTS_DIR=$EXPERIMENT_DIR/freesurfer
export subjectName=sub001
```


<img src="static/message_duplicates.png">
<img src="static/message_export.png">
<img src="static/cortical_rough.png">
<img src="static/laplacian_smooth.png">
<img src="static/cortical_smooth.png">
<img src="static/subcortical.png">










mkdir -p $SUBJECTS_DIR/${s}/mri/orig
mri_convert $EXPERIMENT_DIR/data/${s}.nii.gz $SUBJECTS_DIR/${s}/mri/orig/001.mgz
recon-all -subjid ${s} -all -time -log logfile -nuintensitycor-3T -openmp 12












#######
# Start

# Go into the parent folder that contains the freesurfer output folder


#######################
# Create Cortical Model

mris_convert --combinesurfs sub*/surf/lh.pial sub*/surf/rh.pial ./cortex.stl
meshlab cortex.stl

# Use MeshLab Filters to optimize surface quality
#   Filters > Smoothing, Fairing, and Deformation > ScaleDependent Laplacian Smooth > 100 iteration + 0.1 perc on

# File > Export Mesh - under cortex.stl, but not as binary!

#close meshlab

##########################
# Create Subcortical Model
mri_convert sub*/mri/aseg.mgz subcortical.nii
mri_binarize --i subcortical.nii --match 2 3 24 31 41 42 63 72 77 51 52 13 12 43 50 4 11 26 58 49 10 17 18 53 54 44 5 80 14 15 30 62 --inv --o bin.nii
fslmaths subcortical.nii -mul bin.nii subcortical.nii.gz

# Pre-tessellate
cp subcortical.nii.gz subcortical_filled.nii.gz
gunzip -f subcortical_filled.nii.gz

for i in 7 8 16 28 46 47 60 251 252 253 254 255
do
    mri_pretess subcortical_filled.nii $i sub*/mri/norm.mgz subcortical_filled.nii
done

# Tessellate
fslmaths subcortical_filled.nii -bin subcortical_bin.nii
#freeview -v subcortical_bin.nii.gz # Manually clean unconnected voxels
mri_tessellate subcortical_bin.nii.gz 1 subcortical
mris_convert subcortical ./subcortical.stl

meshlab subcortical.stl

#   Filters > Smoothing, Fairing,...> ScaleDependent Laplacian Smooth > 100 iteration + 0.1 perc on

# Export mesh under cortex.stl, but not as binary!

# Clean up all the data
rm bin.nii subcortical_bin.nii.gz subcortical_filled.nii subcortical.nii subcortical.nii.gz subcortical


##########################################
# Combine Cortical and Subcortical Surface

echo 'solid ./final.stl' > final.stl
sed '/solid .\/cortex.stl/d' cortex.stl >> final.stl
sed '/solid .\/subcortical.stl/d' subcortical.stl >> final.stl
echo 'endsolid ./final.stl' >> final.stl


################
# Postprocessing
meshlab final.stl




###############
# Supplementary

# To visualize the data you need meshlab and blender
# sudo apt-get install meshlab blender

# To print evtl. use - https://www.shapeways.com/model/upload-and-buy
