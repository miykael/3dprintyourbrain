# 3D print your brain

[![GitHub issues](https://img.shields.io/github/issues/miykael/3dprintyourbrain.svg)](https://github.com/miykael/3dprintyourbrain/issues/)
[![GitHub pull-requests](https://img.shields.io/github/issues-pr/miykael/3dprintyourbrain.svg)](https://github.com/miykael/3dprintyourbrain/pulls/)
[![GitHub contributors](https://img.shields.io/github/contributors/miykael/3dprintyourbrain.svg)](https://GitHub.com/miykael/3dprintyourbrain/graphs/contributors/)
[![GitHub Commits](https://github-basic-badges.herokuapp.com/commits/miykael/3dprintyourbrain.svg)](https://github.com/miykael/3dprintyourbrain/commits/master)
[![GitHub size](https://github-size-badge.herokuapp.com/miykael/3dprintyourbrain.svg)](https://github.com/miykael/3dprintyourbrain/archive/master.zip)

So, you want to 3D print your own brain? The following is a step by step guide that will tell you exactly how to do that. You can either run the steps by yourself or use the amazing `3Dprinting_brain.sh` script, developed by [Sofie Van Den Bossche](https://github.com/sofievdbos), James Deraeve, Thibault Sanders and [Robby De Pauw](https://twitter.com/RobbyDePauw) that is located in the `script` folder.

In short, the script will allow you to create a 3D model of your brain, all coming from a structural image (T1) like this:

<img src="static/brain.png" width="400">

**Note:** To create a 3D surface model of your brain we will use [FreeSurfer](http://freesurfer.net/), [meshlab](http://meshlab.sourceforge.net/) and [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki). Therefore you should make sure that those are already installed on your system.

## Step 1 - Specify Variables

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


## Step 2 - Create Surface Model with FreeSurfer

Assuming that you have your structural image in NIfTI format, run the following code:

```bash
mkdir -p $SUBJECTS_DIR/${subject}/mri/orig
mri_convert ${subjT1} $SUBJECTS_DIR/${subject}/mri/orig/001.mgz
recon-all -subjid ${subject} -all -time -log logfile -nuintensitycor-3T -sd $SUBJECTS_DIR -parallel
```

**Note:** This step might take some time. Between 3-9h. By default it runs in parallel across 4 cores, this can be overridden by adding the flag `` -openmp N`` after ``-parallel``, where ``N`` stands for the number of CPUs to use.


## Step 3 - Create 3D Model of Cortical Areas

The following code will take the reconstructed surface model of both hemisphere's, concatenate them and save them under ``cortical.stl``

```bash
mris_convert --combinesurfs $SUBJECTS_DIR/${subject}/surf/lh.pial $SUBJECTS_DIR/${subject}/surf/rh.pial \
             $SUBJECTS_DIR/cortical.stl
```

Now let's look at the data with ``meshlab``. Therefore use the following code:

```bash
meshlab $SUBJECTS_DIR/cortical.stl
```

You should see something like this:

<img src="static/cortical_rough.png">

**Note:** If you have the following display message, just accept with **OK**.

<img src="static/message_duplicates.png">

This version of your surface reconstruction is still rather rough. So lets smooth it abit. Therefore, go to

```
Filters
    > Smoothing, Fairing, and Deformation
        > ScaleDependent Laplacian Smooth
```

This should open up the following window:

<img src="static/laplacian_smooth.png">

Just set ``Smoothing steps`` to ``100`` and ``perc on`` under ``delta (abs and %)`` to ``0.100``. And finally press ``Apply``. You should now have something that looks like this:

<img src="static/cortical_smooth.png">

After this step, click on ``File`` and ``Export Mesh`` and save the whole thing without ``Binary encoding``, i.e.:

<img src="static/message_export.png">

Press ``OK`` and close ``meshlab`` again.


## Step 4 - Extract the Subcortial Areas of Interest

Now, FreeSurfer creates a very nice 3D model of the surface. Which unfortunately it doesn't do for subcortical structures, cerebellum and brainstem. Assuming that you want to print those areas too, we have to create a 3D surface model of them first. One way to do this is to use FreeSurfer's segmentation file ``aseg.mgz``.

```bash
# First, convert aseg.mgz into NIfTI format
mri_convert $SUBJECTS_DIR/${subject}/mri/aseg.mgz $SUBJECTS_DIR/subcortical.nii

# Second, binarize all Areas that you're not interested and inverse the binarization
mri_binarize --i $SUBJECTS_DIR/subcortical.nii \
             --match 2 3 24 31 41 42 63 72 77 51 52 13 12 43 50 4 11 26 58 49 10 17 18 53 54 44 5 80 14 15 30 62 \
             --inv \
             --o $SUBJECTS_DIR/bin.nii

# Third, multiply the original aseg.mgz file with the binarized files
fslmaths $SUBJECTS_DIR/subcortical.nii \
         -mul $SUBJECTS_DIR/bin.nii \
         $SUBJECTS_DIR/subcortical.nii.gz
```

**Note:** To figure out the value of the areas of no interest in the second step open ``aseg.mgz`` in the NIfTI viewer of your choice. With FreeSurfer it would be as follows: ``freeview -v $SUBJECTS_DIR/${subject}/mri/aseg.mgz -colormap lut``

After this step you'll have a NIfTI file that only contains the areas you were interested in. It should look something like this:

<img src="static/subcortical_aseg.png"  width="400">

## Step 5 - Create 3D Model of Subcortical Areas

The next step is now to turn those subcortical regions into a 3D model.

```bash
# Copy original file to create a temporary file
cp $SUBJECTS_DIR/subcortical.nii.gz $SUBJECTS_DIR/subcortical_tmp.nii.gz

# Unzip this file
gunzip -f $SUBJECTS_DIR/subcortical_tmp.nii.gz

# Check all areas of interest for wholes and fill them out if necessary
for i in 7 8 16 28 46 47 60 251 252 253 254 255
do
    mri_pretess $SUBJECTS_DIR/subcortical_tmp.nii \
    $i \
    $SUBJECTS_DIR/${subject}/mri/norm.mgz \
    $SUBJECTS_DIR/subcortical_tmp.nii
done

# Binarize the whole volume
fslmaths $SUBJECTS_DIR/subcortical_tmp.nii -bin $SUBJECTS_DIR/subcortical_bin.nii

# Create a surface model of the binarized volume with mri_tessellate
mri_tessellate $SUBJECTS_DIR/subcortical_bin.nii.gz 1 $SUBJECTS_DIR/subcortical

# Convert binary surface output into stl format
mris_convert $SUBJECTS_DIR/subcortical $SUBJECTS_DIR/subcortical.stl
```

Next, open ``subcortical.stl`` with ``meshlab`` and apply ``ScaleDependent Laplacian Smooth`` as under step 3.

```bash
meshlab $SUBJECTS_DIR/subcortical.stl
```

The output you get should be as follows:

<img src="static/subcortical.png">

On the left you see the surface reconstruction before smoothing, just after the tesselation and on the right you see the smoothed subcortical surface model after scale dependent laplacian smoothing.

Now, as before: Click on ``File`` and ``Export Mesh`` and save the whole thing without ``Binary encoding``.


## Step 7 - Combine Cortical and Subcortial 3D Models

Now it's a short thing to concatenate the two files, ``cortical.stl`` and ``subcortical.stl`` into one ``final.stl`` file:

```bash
echo 'solid '$SUBJECTS_DIR'/final.stl' > $SUBJECTS_DIR/final.stl
sed '/solid vcg/d' $SUBJECTS_DIR/cortical.stl >> $SUBJECTS_DIR/final.stl
sed '/solid vcg/d' $SUBJECTS_DIR/subcortical.stl >> $SUBJECTS_DIR/final.stl
echo 'endsolid '$SUBJECTS_DIR'/final.stl' >> $SUBJECTS_DIR/final.stl
```


## Step 8 - Clean-up Temporary Output

```bash
rm $SUBJECTS_DIR/bin.nii \
   $SUBJECTS_DIR/subcortical_bin.nii.gz \
   $SUBJECTS_DIR/subcortical_tmp.nii \
   $SUBJECTS_DIR/subcortical.nii \
   $SUBJECTS_DIR/subcortical.nii.gz \
   $SUBJECTS_DIR/subcortical
```

## Step 9 - Reduce File Size

Use again ``meshlab`` to load ``final.stl``.

```bash
meshlab $SUBJECTS_DIR/final.stl
```

<img src="static/final.png">

Now, as a final step: Export the mesh again, but this time use ``Binary encoding``. This will reduce the data volume dramatically and will make it easier to send or upload the 3D model.


## Step 10 - Print 3D Model via Internet

So, now to the final steps. If you're lucky enough and you have you have your own access to a 3D printer, than you probably know what to do next. Lucky you!

If you don't have access to a 3D printer, than there are many options on the internet. I personally used [www.shapeways.com](https://www.shapeways.com). It's very easy to use, you can choose from many different materials and it gives you also the option to resize your model, as well as correct for flawed surface areas.


## Step 11 - The Final product

And this is how the final product might look like:

<img src="static/3dbrain.png" width="400">


# 3D print alternative

I'm happy to point you to a [nice alternative to this guide](https://medium.com/@cMadan/we-can-3d-print-brains-novelty-paperweight-or-a-tool-for-scientific-communication-bd7af9b7609a), written by [Christopher Madan](https://github.com/cmadan). Make sure to also check out [his article](http://riojournal.com/articles.php?journal_name=rio&id=10266)!
