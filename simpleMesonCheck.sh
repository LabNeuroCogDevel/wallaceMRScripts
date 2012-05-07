#!/home/foranw/bin/bash-42

############
#
# list top level directory mismatches for data imported from meson
#   for WM, MM, and Reward
#
###########


# everything set in bash export, aval. in perl
set -a

# where are the experiment directories? (host dependent)
case $HOSTNAME in
*gromit*)
   RawDir="/raid/r3/p2/Luna/Raw/"
   ;;
*wallace*)
   RawDir="/data/Luna1/Raw/"
   ;;
*Schwarzenagger*)
   RawDir="/Volumes/T800/Raw/"
   ;;
*)
  echo dont know what to do on $HOSTNAME
  exit
  ;;
esac

# use local expect
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/foranw/usr/lib/expect5.45/
PATH="$PATH:/home/foranw/usr/bin"
# add meson.expect to path, run if can't find ssh meson already running
PATH="$PATH:/home/foranw/src/getDataCrons/"
ls $HOME/.ssh/master/*kaihwang* 2>/dev/null 1>/dev/null || meson.expect

#  meson vs local named array converter for experiments
declare -A projects
projects=([WorkingMemory]=WPC-5744 [MultiModal]=WPC-5640 [MRCTR]=WPC-4951)
#  MRCTR => Rewards


# clear files log
echo -n > mesonFiles.txt

[ -r filediffs.txt ] && rm filediffs.txt

#########
# go through each experiment
# 
# list all scans (top level directories) on meson
# and compare to the same on local 
#
#########


echo "col 1 uniq to          col 2 uniq to"
for p in ${!projects[*]}; do 
  echo -e "\n"
  echo "meson:${projects[$p]}	$HOSTNAME:$p"
  comm -3 <(ssh meson "ls -d /disk/mace2/scan_data/${projects[$p]}/*/*/"  |
               tee -a mesonFiles.txt               |
               xargs -I {} basename {} "/"         | 
               sort) \
           <(/bin/ls -d /data/Luna1/Raw/$p/*/      | 
               xargs -I{} basename {} "/"          |
               sort)
done | tee -a filediffs.txt

echo -e "\n\n\n" | tee -a filediffs.txt

######
# use file list captured from ssh (via tee above) to make a table of counts
#
# for project name (local, remote)     
#        missing local files count       
#        bad remote names count     
#        total remote count      
#        total local count
#
#   as 
#     locNam RemNam misLocCnt badRemCnt totRemCnt totLocCnt 
#
####
perl -ne '
         BEGIN{
          $raw=$ENV{RawDir};

          %p=(5744=>"WorkingMemory",
              5640=>"MultiModal"   , 
              4951=>"MRCTR"        );

          ($miscount, $badcount)=(0)x2;

         }
         next unless /WPC-(\d{4})/;
         $n=$1; $c{$n}++;
         if(/(\d{5}_\d{8})/) {
             $m{$n}++ if system("ls -d $raw/$p{$n}/$1 1>/dev/null 2>&1");
             #print system("ls -d $raw/$p{$n}/$1 1>/dev/null 2>&1")
             #      ?"MISSING $n\t$1". ++$m{$n} . "\n"
             #      :"" 
          }
          else {
             #print STDERR "BAD NAME $_";
             ++$b{$n};
          }
          END { 
            print join("\t", qw(localname  wpc remote mis bad local)),"\n"; 
            print join("\t",sprintf("%8s",$p{$_}),
                   $_,$c{$_},$m{$_},$b{$_}),"\t",
                   `ls -d $raw/$p{$_}/*|wc -l`
             for keys %c;

          } '  mesonFiles.txt | tee -a filediffs.txt

git add filediffs.txt && git commit -m "meson/local filediff $(date +%F)" && git diff
