#!/bin/bash

lastfile=$(ls -tp $archivefolder/*jpg | grep -v '/$' | grep -v masked | head -n 1 | xargs -n 1 basename)
lastmasked=$(ls -tp $archivefolder/*-masked.jpg | grep -v '/$' | head -n 1 | xargs -n 1 basename)
cp "${archivefolder}/${lastfile}" "${webfolder}/original.jpg"
cp "${archivefolder}/${lastmasked}" "${webfolder}/masked.jpg"

while true; do
  newfile=$(ls -tp $sourcefolder/*jpg | head -n 1 | xargs -n 1 basename)
  if [ "${sourcefolder}/${newfile}" -nt "${archivefolder}/${lastfile}" ]; then
    echo "Processing new file: "$newfile
    recheck=0
    while [[ ! -s "${sourcefolder}/${newfile}" && $recheck -lt 3 ]]; do
      sleep 0.1
      ((recheck++))
    done
    if [ -s "${sourcefolder}/${newfile}" ]; then
      # Copy and delete the latest file.
      # mv didn't work as it cannot preserve permissions and drops error.
      cp --no-preserve=mode "${sourcefolder}/${newfile}" "${archivefolder}/${newfile}"
      rm "${sourcefolder}/${newfile}"
      # Start scoring
      python3 /home/masking.py "${archivefolder}/${newfile}"
      # Copy to original and the masked files to the webfolder"
      lastfile=$(ls -tp $archivefolder/*jpg | grep -v '/$' | grep -v masked | head -n 1 | xargs -n 1 basename)
      lastmasked=$(ls -tp $archivefolder/*-masked.jpg | grep -v '/$' | head -n 1 | xargs -n 1 basename)
      cp "${archivefolder}/${lastfile}" "${webfolder}/original.jpg"
      cp "${archivefolder}/${lastmasked}" "${webfolder}/masked.jpg"
      # Upload to Azure Blob if parameters are specified
      if [ ! -z "$bloburl" ]; then
        curl -sS --max-time 1 -X PUT -T ${webfolder}/masked.jpg -H "x-ms-date: $(TZ=GMT date '+%a, %d %h %Y %H:%M:%S %Z')" -H "x-ms-blob-type: BlockBlob" "${bloburl}masked.jpg?${sastoken}" &
        curl -sS --max-time 1 -X PUT -T ${webfolder}/original.jpg -H "x-ms-date: $(TZ=GMT date '+%a, %d %h %Y %H:%M:%S %Z')" -H "x-ms-blob-type: BlockBlob" "${bloburl}original.jpg?${sastoken}" &
      fi
      # Delete uneccessary (all but the last 5) files in the source folder.
      cd ${sourcefolder}
      ls -tp | grep -v '/$' | tail -n +6 | xargs -d '\n' -r rm --
      cd /home
    fi
  fi
  sleep 0.2
done