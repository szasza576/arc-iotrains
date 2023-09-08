#!/bin/bash

lastfile=$(ls -Art $archivefolder/*jpg | xargs -n 1 basename | grep -v masked | tail -n 1)
lastmasked=$(ls -Art $archivefolder/*jpg | xargs -n 1 basename | grep masked | tail -n 1)
cp "${archivefolder}/${lastfile}" "${webfolder}/original.jpg"
cp "${archivefolder}/${lastmasked}" "${webfolder}/masked.jpg"

while true; do
  newfile=$(ls -Art $sourcefolder/*jpg | xargs -n 1 basename | tail -n 1)
  if [ "${sourcefolder}/${newfile}" -nt "${archivefolder}/${lastfile}" ]; then
    date -u "+%Y%m%d-%H%M%S"
    echo "Processing new file: "$newfile
    recheck=0
    while [[ ! -s "${sourcefolder}/${newfile}" && $recheck -lt 3 ]]; do
      sleep 0.1
      ((recheck++))
    done
    if [ -s "${sourcefolder}/${newfile}" ]; then
      date -u "+%Y%m%d-%H%M%S"
      echo "Start the copy."
      cp --no-preserve=mode "${sourcefolder}/${newfile}" "${archivefolder}/${newfile}" # mv didn't work as it cannot preserve permissions and drops error.
      date -u "+%Y%m%d-%H%M%S"
      echo "Delete file"
      rm "${sourcefolder}/${newfile}"
      date -u "+%Y%m%d-%H%M%S"
      echo "Start scoring"
      python3 masking.py "${archivefolder}/${newfile}"
      date -u "+%Y%m%d-%H%M%S"
      echo "Scoring done. Copy to the webfolder"
      lastfile=$(ls -Art $archivefolder/*jpg | xargs -n 1 basename | grep -v masked | tail -n 1)
      lastmasked=$(ls -Art $archivefolder/*jpg | xargs -n 1 basename | grep masked | tail -n 1)
      cp "${archivefolder}/${lastfile}" "${webfolder}/original.jpg"
      cp "${archivefolder}/${lastmasked}" "${webfolder}/masked.jpg"
      date -u "+%Y%m%d-%H%M%S"
      echo "Copy done."
    fi
  fi
  sleep 0.2
done