#!/usr/bin/env bash
#
# give an MR directory
# get physio


set -e #x

MRdir="$1";

# if we haven't set "do bad name" variable, error when we have a bad name

[ -z "$DOBADNAME" ] && ERRORONBADNAME=1

[ -z "$MRdir" -o -n "$2" ] && 
  echo "give me MRdata directory as only argument" && exit 1

[ ! -d $MRdir ] &&
   echo "cannot find $MRID (DNE: $MRdir)" && exit 1

# actually we probably want to use the links! (WF:20150205)
#linkpath=$(readlink $MRdir)
#[ -n "$linkpath" ] &&
#   echo "$MRdir is a link (to $linkpath), probably not what you want to work with" && exit 1

paradigm="$(basename $(dirname $MRdir))"
case $paradigm in
 P5)         paradigm=P5Sz;       dropvol=1;;
 Multimodal) paradigm=MulitModal; dropvol=1;;
 Reward)     paradigm=MRCTR;      dropvol=0;;
esac

physiodir="/data/Luna1/Raw/Physio/unorganized/$paradigm/"
[ ! -d $physiodir ] &&
   echo "cannot find physio for $paradigm (DNE: $physiodir )" && exit 1


FSYSiddate=$(basename $MRdir)
FSYSid=${FSYSiddate%%_*}
FSYSdate=${FSYSiddate##*_}

[[ ! "$FSYSid"  =~ [1-9][0-9][0-9][0-9][0-9] ]] && 
  echo "folder lunaid '$FSYSid' does not match expected pattern (5 digits)" # && [ -n "$ERRORONBADNAME" ] && exit 1
[[ ! "$FSYSdate" =~ [1-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9] ]] && 
  echo "folder date '$FSYSdate' does not match expected pattern (8 digits)" # && [ -n "$ERRORONBADNAME" ] && exit 1

dcm=$(find $MRdir -maxdepth 2 -iname 'MR*' |head -n1)
[ -z "$dcm" ] &&
   echo "$MRdir has no dcms!?" && exit 1

### get id and date from dicom

# get subject id (as in MRDir) from dicom header
# sometimes subjid will be luna_date
# sometimes        only luna
read MRid MRdate < <(dicom_hinfo -tag 0010,0010 -tag 0008,0020 $dcm |cut -d' ' -f2-3 )

MRidonly=${MRid%%_*}
MRiddateonly=${MRid##*_}
if [[ "$MRidonly" == "$MRiddateonly" ]]; then
  echo "WARN: $FSYSiddate: dcm id ($MRid) does not included date"
  MRiddateonly=$MRdate
fi

if [[ "$MRdate" != "$MRiddateonly" ]]; then
  echo "WARN: $FSYSiddate: MR date ($MRdate) and date in MR id name ($MRiddateonly) are inconsistant!"
fi

# yyyy mm dd    dd mm yy
# 2000 12 31 -> 31 01 00 (without spaces :) )
mmddyy="${MRdate:6:2}${MRdate:4:2}${MRdate:2:2}"
yymmdd="${MRdate:2:6}"

# put physio files into a bash array
# -- we want to match any combination of any 
#     of the id's and dates we've collected
# and we only want resp and puls files
physfiles=(  \
   $(find $physiodir/ \
     -maxdepth 1 \
     \(  -name "*${MRidonly}_$MRiddateonly*" -or \
         -name "*${MRidonly}_$FSYSdate*" -or \
         -name "*${FSYSid}_$MRiddateonly*" -or \
         -name "*${MRidonly}$FSYSdate*" -or \
         -name "*${FSYSid}_$yymmdd*" -or\
         -name "*${FSYSid}_$mmddyy*" \) -and \
      \( -name '*resp' -or -name '*puls' \) \
   ) \
 )

# we should have matched only 2 files, otherwise we have a problem
if [ ${#physfiles[@]} -ne 2 ]; then
  echo "ERROR: $FSYSiddate bad number (${#physfiles[@]}) of physfiles (${physfiles[@]});see $physiodir/*{$MRid,$FSYSiddate,$MRdate,$mmddyy}*"
  exit 1;
fi

if [ -n "$VERB" ]; then
   echo "FSYS:   $FSYSiddate; '$FSYSid' '$FSYSdate'"
   echo "MRid: $MRid; '$MRidonly' '$MRiddateonly'"
   echo "MRdt: $MRdate"
   echo "Physfiles: ${physfiles[@]}"
fi

outdir="/data/Luna1/Physio/$paradigm/"
[ ! -d $outdir ] && mkdir -p $outdir


##### ACTUALLY RUN PHYSIO PROC

# TODO: go through each dirctory in MRdir with more than X dcms?
#       instead of just doing rest?

# do we have a rest folder in MR?
restdir=$(find $MRdir  -maxdepth 1 -type d -iname '*rest*' )
nrestdirs=$(echo $restdir |wc -l)
[ "$nrestdirs" -ne 1 ] &&  "$MRdir has $nrestdirs rest dirs (need exactly 1)!?" && exit 1

# do we already have physio procesed?
outname="$outdir/${FSYSiddate}_rest"
if ls $outname*slibase.1D 1>/dev/null 2>&1 && [ "$REDO" != 1 ]; then
  echo "already have for $restdir try:
    REDO=1 $0 $@" 
  exit
fi

siemphysdat -o ${outname}_ -d $dropvol ${physfiles[@]} $restdir 2>&1 | tee $outname.log

