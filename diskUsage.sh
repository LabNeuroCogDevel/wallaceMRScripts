#!/usr/bin/env bash
echo -e "Aval GB\tUsed\tDisk"
(
 for s in {skynet,arnold};  
 do 
   ssh $s 'df -g /Volumes/*/'; 
 done; 
 ssh wallace 'df -B G /data/Luna1/'
)| perl -anle 'print join("\t",$1,@F[4,5]) if $F[3] =~ /^(\d+)/ && $F[5] !~ /(^\/$)|(oacl)/'|
   sort -n
