#!/usr/bin/env bash


PATH="$PATH:$HOME/src/freesurfersearcher-general" # add surfOne.sh to path
######
#  this script is DEPRICATED by ~/src/AutFace/menu.bash
#    which auto starts FS after renaming and transfering raw dirs
#
#####

####
# looks for renamed raw in arnold:TX
#   create mprage if needed
# brings mprage to wallace:Autism_Faces
# runs FS on new mprages
#
# **** AFTER FS FINISHES ****
# manually rsync FS results back to arnold if needed there (arnold:T800 .. where there is space)
#

# where on here do we store the anat files
wallaceLoc="/data/Luna1/Autism_Faces/anat"
SUBJECTS_DIR="/data/Luna1/Autism_Faces/FS_Subjects"

# start with no new scans, so we don't have to do anything
#new=0 

# make anatomical/mprage where missing (remotely)
ssh arnold '
for subpath in /Volumes/TX/Autism_Faces/subject_data/byID/[1-9][0-9][0-9]; do 
 id=$(basename $subpath); 
 [ -r $subpath/anatomical/mprage.nii.gz ] && continue; 
 echo "trying to create arnold:$subpath/anatomical/mprage.nii.gz"
 cd $subpath/anatomical/; 
 /usr/local/bin/dcm2nii ./; 
 rage=$(ls -tc 20*.nii.gz |sed 1q); 
 [ -z "$rage" -o ! -r "$rage" ] && echo "ERROR: $id dcm2nii results not as expected" && exit 1
 ln -s $rage mprage.nii.gz; 
done
'
# check for new subjects in Aut Faces
ssh arnold 'ls /Volumes/TX/Autism_Faces/subject_data/byID/[1-9][0-9][0-9]/anatomical/mprage.nii.gz' |
 while read r; do  # read the "rage" files matching
  s=$(echo $r |cut -d/ -f 7)
  #s=${r:32:3};     # the subject number is the 3 characters after the 31st in path
  #                 this changes with drive and path, above is easier

  # skip if already exists
  [ -r $wallaceLoc/${s}_mprage.nii.gz ] &&  continue

  # subject mprage is not on wallace
  echo "fetching ${s}"
  scp arnold:$r $wallaceLoc/${s}_mprage.nii.gz

  # submit to qsub
  surfOne.sh -t AF -s $SUBJECTS_DIR -i $s -n $wallaceLoc/${s}_mprage.nii.gz

  # we should mark that surf now needs to be run
  # new=1
done

# run qsub FS submission script
#[ "$new" -eq "1" ] && /data/Luna1/Autism_Faces/surf.sh

# warn about subjects without anatomical
# by compairing file count of subject dirs to subj dirs with mprages
# this should not happen (because we made mprages earlier)
ssh arnold '
a=$(ls -1  /Volumes/TX/Autism_Faces/subject_data/byID/[1-9][0-9][0-9]/anatomical/mprage.nii.gz|wc -l);
b=$(ls -d1 /Volumes/TX/Autism_Faces/subject_data/byID/[1-9][0-9][0-9]                         |wc -l);
[ "$a" -eq "$b" ] || echo "$b subjects but $a mprage.nii.gz"
'

# check that all mprage's have FS_Subjs
#  left: subjects with \d\d\d_mprage.nii.gz
#  right: subjects with FS dirs
comm -3 \
   <(ls --color=no $wallaceLoc| perl -ne 'print $1,"\n" if m/^(\d+)_/') \
   <(ls -d --color=no $SUBJECTS_DIR/[0-9]*/|cut -d/ -f 6)

