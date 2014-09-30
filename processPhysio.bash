#!/usr/bin/env bash
#
# get and process physio files for each study
#  -- script depends on perl5.16 script: /data/Luna1/Raw/Physio/organize_usingdb.pl
#     see /data/Luna1/Raw/Physio/log/


# expect and git are set up to work in script's directory 
scriptdir=$(cd $(dirname $0); pwd)
cd $scriptdir


# THIS IS DONE ON MESON SIDE BY CRON UNDER kaihwang
### Connect to meson 

# use local "expect" binary
#export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/foranw/usr/lib/expect5.45/
#PATH="$PATH:/home/foranw/usr/bin"
#
## try use established meson connection, otherwise reopen and fork
#if ! ssh meson -o BatchMode=yes ls; then
# [ -r ~/.ssh/master/*kaihwang* ] && rm ~/.ssh/master/*kaihwang* 
# ./meson.expect 
#fi

#### transfer
#projects=([WorkingMemory]=WPC-5744 [MultiModal]=WPC-5640 [MRCTR]=WPC-4951)
#rsync -azih meson:/disk/mace2/scan_data/Physio/Trio*/ /data/Luna1/Raw/Physio/unorganized/WorkingMemory --include '*WPC-5744*' --exclude '*'
#rsync -azih meson:/disk/mace2/scan_data/Physio/Trio*/ /data/Luna1/Raw/Physio/unorganized/MultiModal/   --include '*WPC-5640*' --exclude '*'
#rsync -azih meson:/disk/mace2/scan_data/Physio/Trio*/ /data/Luna1/Raw/Physio/unorganized/MRCTR/        --include '*WPC-4951*' --exclude '*'
#

#### Organize
/data/Luna1/ni_tools/perlbrew/perls/perl-5.16.0/bin/perl /data/Luna1/Raw/Physio/organize_usingdb.pl || exit 1
#see /data/Luna1/Raw/Physio/log/

#### AFNI RETRO TS (via matlab)

# where the matlab script is
export MATLABPATH="/data/Luna1/Raw/Physio/processing/physio_matlab:$MATLABPATH"

for study in Reward MultiModal WorkingMemory; do
  echo
  echo "=== $study ==="
  matlab -nodisplay -nojvm -r "fprintf('endhead\n'); try, allPhysio('$study'),catch,fprintf('fail\n'), end, quit" | sed '1,/^endhead$/d'
done 2>&1 > physio.log

# only report changes
if ! git diff --exit-code -- physio.log; then
  git add physio.log
  git commit -m 'getAndProcPhysio.bash changed phsyio.log'
fi
