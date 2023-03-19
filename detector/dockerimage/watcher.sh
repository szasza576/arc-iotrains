#!/bin/bash

lastfile=$(ls -Art $archivefolder/*jpg | xargs -n 1 basename | grep -v masked | tail -n 1)
lastmasked=$(ls -Art $archivefolder/*jpg | xargs -n 1 basename | grep masked | tail -n 1)
cp "${archivefolder}/${lastfile}" "${webfolder}/original.jpg"
cp "${archivefolder}/${lastmasked}" "${webfolder}/masked.jpg"

while true; do
  newfile=$(ls -Art $sourcefolder/*jpg | xargs -n 1 basename | tail -n 1)
  if [ "${sourcefolder}/${newfile}" -nt "${archivefolder}/${lastfile}" ]; then
    echo "Processing new file: "$newfile
    recheck=0
    while [[ ! -s "${sourcefolder}/${newfile}" && $recheck -lt 3 ]]; do
      sleep 0.1
      ((recheck++))
    done
    if [ -s "${sourcefolder}/${newfile}" ]; then
      mv "${sourcefolder}/${newfile}" "${archivefolder}/${newfile}"
      python3 masking.py "${archivefolder}/${newfile}"
      lastfile=$(ls -Art $archivefolder/*jpg | xargs -n 1 basename | grep -v masked | tail -n 1)
      lastmasked=$(ls -Art $archivefolder/*jpg | xargs -n 1 basename | grep masked | tail -n 1)
      cp "${archivefolder}/${lastfile}" "${webfolder}/original.jpg"
      cp "${archivefolder}/${lastmasked}" "${webfolder}/masked.jpg"
    fi
  fi
  sleep 0.2
done