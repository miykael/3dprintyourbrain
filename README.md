# 3D print your brain

So, you want to 3D print your own brain? The following is a step by step guide that will tell you how to 3D print a brain. All coming from a structural image (T1) like this:

<img src="static/brain.png" width="400">

**Note:** To create a 3D surface model of your brain we will use `FreeSurfer <http://freesurfer.net/>`_ and `meshlab <http://meshlab.sourceforge.net/>`_. Therefore you should make sure that those two softwares are already installed on your system.


## 1. Specify Variables

Let's first specify all necessary variables that we need for this to work:

```bash
# Main folder for the whole project
export EXPERIMENT_DIR=/users/mnotter/3dbrain

# Path to the FreeSurfer folder
export SUBJECTS_DIR=$EXPERIMENT_DIR/freesurfer

# Name of the subject
export subject=sub001

# Path to the structural image
export subjT1=$EXPERIMENT_DIR/${subject}/struct.nii.gz
```


## 2. Create Surface Model with FreeSurfer

Assuming that you have your structural image in NIfTI format, run the following code:

```bash
mkdir -p $SUBJECTS_DIR/${subject}/mri/orig
mri_convert ${subjT1} $SUBJECTS_DIR/${subject}/mri/orig/001.mgz
recon-all -subjid ${subject} -all -time -log logfile -nuintensitycor-3T
```

**Note:** This step might take some time. Between 6-18h. If you want to run ``recon-all`` in parallel and speed-up the whole process, add `` -openmp N`` to the end of the ``recon-all`` command, where **N** stands for the number of CPUs to use.


## 3. Create 3D Model of cortical Areas

```bash
mris_convert --combinesurfs sub*/surf/lh.pial sub*/surf/rh.pial ./cortex.stl
meshlab cortex.stl

# Use MeshLab Filters to optimize surface quality
#   Filters > Smoothing, Fairing, and Deformation > ScaleDependent Laplacian Smooth > 100 iteration + 0.1 perc on

# File > Export Mesh - under cortex.stl, but not as binary!

#close meshlab
```

<img src="static/message_duplicates.png">
<img src="static/message_export.png">
<img src="static/cortical_rough.png">
<img src="static/laplacian_smooth.png">
<img src="static/cortical_smooth.png">
<img src="static/subcortical.png">


## 4. Create 3D Model of subcortial Areas

```bash
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
```

## 5. Combine Cortical and Subcortial 3D Models

```bash
echo 'solid ./final.stl' > final.stl
sed '/solid .\/cortex.stl/d' cortex.stl >> final.stl
sed '/solid .\/subcortical.stl/d' subcortical.stl >> final.stl
echo 'endsolid ./final.stl' >> final.stl
```

## 6. Clean-up Temporary Output

```bash
rm bin.nii subcortical_bin.nii.gz subcortical_filled.nii subcortical.nii subcortical.nii.gz subcortical
```

## 7. Final Result

```bash
meshlab final.stl
```

## 8. Print 3D Model Per Internet

To print evtl. use - https://www.shapeways.com/model/upload-and-buy
