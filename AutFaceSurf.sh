#!/usr/bin/env bash

new=0
# check for new subjects in Aut Faces
ssh arnold 'ls -d /Volumes/Terabyte1/Autism_Faces/[1-9][0-9][0-9]/anatomical/mprage.nii.gz'| 
 while read r; do  # read the "rage" files matching
  s=${r:32:3};     # the subject number is the 3 characters after the 31st in path
  [ -r anat/${s}_mprage.nii.gz ]  && continue
  echo "fetching ${s}"
  scp arnold:$r /data/Luna1/Autism_Faces/anat/${s}_mprage.nii.gz
  new=1
done

# run qsub FS submission script
[ "$new" -eq "1" ] && /data/Luna1/Autism_Faces/surf.sh

# warn about subjects without anatomical
# by compairing file count of subject dirs to subj dirs with mprages
ssh arnold '
a=$(ls -1  /Volumes/Terabyte1/Autism_Faces/[1-9][0-9][0-9]/anatomical/mprage.nii.gz|wc -l);
b=$(ls -d1 /Volumes/Terabyte1/Autism_Faces/[1-9][0-9][0-9]                         |wc -l);
[ "$a" -eq "$b" ] || echo "$b subjects but $a mprage.nii.gz"
'
