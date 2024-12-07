#!/bin/bash

# Pick the last from the Archive folder and copy it to the webfolder to share with the nginx container
lastfile=$(ls -tp $archivefolder/*jpg | grep -v '/$' | grep -v masked | head -n 1 | xargs -n 1 basename)
lastmasked=$(ls -tp $archivefolder/*-masked.jpg | grep -v '/$' | head -n 1 | xargs -n 1 basename)
# Touch creates a placholder if the archivefolder would be empty. CP will overwrite it if any file exists.
if [ -f "${archivefolder}/${lastfile}" ]; then
  cp -f "${archivefolder}/${lastfile}" "${webfolder}/original.jpg"
else
  touch "${webfolder}/original.jpg"
fi

if [ -f "${archivefolder}/${lastmasked}" ]; then
  cp -f "${archivefolder}/${lastmasked}" "${webfolder}/masked.jpg"
else
  touch "${webfolder}/masked.jpg"
fi

# Check if ESPCam is configured
if [ ! -z "$espcamip" ]; then
  # Start ESP picture grabber script which gets pictures from ESP into the archive folder in the background
  ./esp-grabber.sh &
else
  # Start the picture mover script which moves the new pictures from the NFS mount into the archive folder in the background
  inotifywait -m -e close_write --format '%f' ${sourcefolder} \
  | while read file; do
      cp --no-preserve=mode "${sourcefolder}/${file}" "${archivefolder}/${file}"
      # Delete uneccessary (all but the last 5) files in the source folder.
      if [ $cleanup ]; then
        ls -tp ${sourcefolder}/* | grep -v '/$' | tail -n +6 | xargs -d '\n' -r rm --
      fi
    done &
fi


# Start folder watcher for new files in archive folder
if [ -f "${archivefolder}/lastfile" ]; then
  rm ${archivefolder}/lastfile
fi
touch ${archivefolder}/lastfile
inotifywait -m -e close_write --format '%f' --exclude .*-masked.jpg ${sourcefolder} \
  | while read file; do
      echo $file > ${archivefolder}/lastfile
    done &

while true; do
  # Test for new file successful capture
  newfile=$(cat ${archivefolder}/lastfile)
  if [ -z "$newfile" ] || [ ! -s "${archivefolder}/$newfile" ]; then
    # No new file found
    # Optionally add some sleep to prevent super exhausting running.
    sleep 0.01
    continue
  fi
  echo "Processing new file: $newfile"
  # Start scoring
  python3 /home/masking.py "${archivefolder}/${newfile}"
  # Copy to original and the masked files to the webfolder"
  lastmasked=$(ls -tp ${archivefolder}/*-masked.jpg | grep -v '/$' | head -n 1 | xargs -n 1 basename)
  cp "${archivefolder}/${newfile}" "${webfolder}/original.jpg"
  cp "${archivefolder}/${lastmasked}" "${webfolder}/masked.jpg"
  # Cleanup old files in the archive folder if the cleanup environment variable is set
  if [ "$cleanup" ]; then
    ls -tp ${archivefolder}/* | grep -v '/$' | grep masked | tail -n +6 | xargs -d '\n' -r rm --
    ls -tp ${archivefolder}/* | grep -v '/$' | grep -v masked | tail -n +6 | xargs -d '\n' -r rm --
  fi
  # Upload to Azure Blob if parameters are specified
  if [ ! -z "$bloburl" ]; then
    curl -sS --max-time 1 -X PUT -T ${webfolder}/masked.jpg -H "x-ms-date: $(TZ=GMT date '+%a, %d %h %Y %H:%M:%S %Z')" -H "x-ms-blob-type: BlockBlob" "${bloburl}masked.jpg?${sastoken}" &
    curl -sS --max-time 1 -X PUT -T ${webfolder}/original.jpg -H "x-ms-date: $(TZ=GMT date '+%a, %d %h %Y %H:%M:%S %Z')" -H "x-ms-blob-type: BlockBlob" "${bloburl}original.jpg?${sastoken}" &
  fi
done