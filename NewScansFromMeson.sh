#!/home/foranw/bin/bash-42
####
#
# find folders to pull from meson
# based on the most recent date named in a directory of each of the three tracked experiments 
#
# SCRIPT CAN BE CONFUSED
# o  use MesonSanityCheck.pl to check
#
# o  if run between scans on the same day for same experiment
#      (newest date on second run will be current day: second scan will be overlooked)
# o  incorrectly formated scans
#      if someone errors on input in form of yyyyddmm the script could be broken for a year!
#       (if dd > mm, worst if dd>12)
#       see varaible "lastdate"
#
# o  will send error email to "$email" when notices error
#
# NOTES:
#
# o  STDERR printed warning when not retrieving folder because it is not in the expected format in meson
#      should result in mail if used as cron job
#      (perl returns error on die condition, scp not executed)
#      e.g. missing date
#      THIS MUST BE RESOLVED MANUALLY 
#      -- could automate appending date to folder name,
#      but might generate unexpected folder names
#
# o 'expect' wrapping around ssh -fMN to make non interactive 
#     see meson.expect
#     (meson accepts pubkey auth but maybe not rsa?, need to see /var/log/security on meson)
#     add  "ControlPath ~/.ssh/master/%r@%h:%p" in .ssh/config 
#     or could provided as -o options
#
#####

# use local expect
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/foranw/usr/lib/expect5.45/
PATH="$PATH:/home/foranw/usr/bin"

# add meson.expect to path
PATH="$PATH:/home/foranw/src/getDataCrons/"

# data paths (export so perl can see)
export MesonDataDir="/disk/mace2/scan_data"
export LocalDataDir="/data/Luna1/Raw"
export      LogFile="/home/foranw/log/FromMeson.log"
#export LocalDataDir="/Volumes/T800/Raw"
#export       LogFile="/Users/overseer/log/FromMeson.log"

email='foranw@upmc.edu'

# start logging
echo -e "\n\n\n$(date)" >> $LogFile

# start master meson session if one doesn't exist
# use expect to enter password if no master connection to meson
ls $HOME/.ssh/master/*kaihwang* 2>/dev/null 1>/dev/null || meson.expect

# associative array for project dir names as [arnold]=meson
declare -A projects
# MRCTR is rewards
projects=([WorkingMemory]=WPC-5744 [MultiModal]=WPC-5640 [MRCTR]=WPC-4951)
 
# for each key (ie project name) 
for p in ${!projects[*]}; do 

   export p
   #find most recent date assuming dir name convention lunaID_yyyymmdd
   #lastdate=$(ssh arnold "ls -tc1 $LocalDataDir/$p| sed -n 's/.*_//p'|sort -nr|head -n1;")
   lastdate=$(ls -tc1 $LocalDataDir/$p| sed -n 's/.*_//p'|sort -nr|head -n1)


   # expect that files are named lunaid_yyyymmdd --> NAMEING PROBLEM if yyyymmdd > current yyyymmdd
   if [ "$lastdate" -gt "$(date +'%Y%m%d')" ];then
      #print error to stdout (which gets logged) and to stderr
      echo "LOCAL NAME ERROR: $lasdate (ls -tc1 $LocalDataDir/$p) is greater than the current day, script broken!"| tee >(cat 1>&2)
      echo -e "${p}: $lastdate" | mail -s '!!Meson Update Script Broke!!'  "$email"
   fi

   echo -e "=== $p (${projects[$p]}) -- $lastdate ==="


   # create array of scan date paths
   directories=$(ssh meson "setenv lastdate $lastdate; \
              ls -1 $MesonDataDir/${projects[$p]} | \
              perl -slane 'next unless m/(\d{2})\.(\d{2})\.(\d{4})-/; print if(\"\$3\$1\$2\" > \$ENV{lastdate})'" )

   #for each date directory
   # check that scans should be copied
   for d in $directories; do
     echo "in $d"

     #command to retrieve all scans for the date
     #not tested
     #recursively grab with compression
     #cmd="scp -vrC meson:$MesonDataDir/${projects[$p]}/$d/\\* $LocalDataDir/$p/"
     #   and add to eval: egrep ^Sink|cut -d':' -f2 >> $(dirname $LogFile)/scp-$(date +%F) 
     cmd="rsync -avz --chmod u=rwx,g=rx,o=rx meson:$MesonDataDir/${projects[$p]}/$d/\\* $LocalDataDir/$p/"

     #for each scan inside the date folder on mason
     #  check that the format is what is expected
     #  check folder doesn't already exist (how would this happen?)
     ssh meson "ls $MesonDataDir/${projects[$p]}/$d/" | 
      perl -slane 'chomp; push @d, $_; 

                   die "\n**ERROR: already exists: $_\n" if(-d "$ENV{LocalDataDir}/$ENV{p}/$_/");
                   die "\n**ERROR: badname: $_\n" unless m/^\d{5}_\d{8}$/;

                   #print what we are going to grab with the wildcard glob
                   END{$,=" ";print "\t",@d}'

    #if ssh worked and perl didn't die
    if [ "$?" == 0 ]; then
      synclogfile="$(dirname $LogFile)/rsync-$(date +%F)"
      echo -e "\t$cmd to $synclogfile"
      #get files, log all that is captured to a date specific log file
      eval $cmd >> $synclogfile
    else
      #print error to stdout and stderr
      echo -e "**DID NOT RUN; name without date\n\t  " $cmd  | tee >(cat 1>&2)

      # email the error with some help
      (echo -e "for experiment $p\nlikely a name without a date in $d";
      ssh meson "ls $MesonDataDir/${projects[$p]}/$d/"                  # repeated code :(
      echo "\ndid not run: $cmd";
      echo "rsync subdirectories individually yourself") |
        mail -s 'Meson Update Incomplete' "$email"
    fi
   done

   # with meson still open, try to grab physio
   # grab by wpic id -- very unlikely to match a date :)
   wpicid=${projects[$p]}
   wpicid=${wpicid##*-}
   rsync -azvih meson:/disk/mace2/scan_data/Physio/Trio*/ \
                /data/Luna1/Raw/Physio/unorganized/$p     \
         --include "*$wpicid*" --exclude '*'

#end loop, put output on stdout as well as to logfile
done | tee -a $LogFile


