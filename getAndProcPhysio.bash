#!/usr/bin/env bash
scriptdir=$(cd $(dirname $0); pwd)

cd $scriptdir
for study in Reward MultiModal WorkingMemory; do
  echo
  echo "=== $study ==="
  matlab -nodisplay -nojvm -r "fprintf('endhead\n'); try, allPhysio('$study'),catch,fprintf('fail\n'), end, quit" | sed '1,/^endhead$/d'
done > physio.log

# only report changes
if ! git diff --exit-code phsyio.log; then
  git add physio.log
  git commit -m 'getAndProcPhysio.bash changed phsyio.log'
fi

