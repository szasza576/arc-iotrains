#!/bin/bash

# Pick the last from the Archive folder and copy it to the webfolder to share with the nginx container
lastfile=$(ls -tp $archivefolder/*jpg | grep -v '/$' | grep -v masked | head -n 1 | xargs -n 1 basename)
lastmasked=$(ls -tp $archivefolder/*-masked.jpg | grep -v '/$' | head -n 1 | xargs -n 1 basename)
# Touch creates a placholder if the archivefolder would be empty. CP will overwrite it if any file exists.
touch "${webfolder}/original.jpg"
touch "${webfolder}/masked.jpg"
cp -f "${archivefolder}/${lastfile}" "${webfolder}/original.jpg"
cp -f "${archivefolder}/${lastmasked}" "${webfolder}/masked.jpg"

while true; do
  # Capture a picture and place it into the Archive folder
  # Note, this part could be moved out to another thread and parallelized with the scoring to speed up the refresh rate.
  if [ ! -z "$espcamip" ]; then
    # Capture picture from ESPCAM

    # Grab a picture
    timestamp=$(date -u "+%Y%m%d-%H%M%S-%3N")
    if curl -sS --max-time 2 http://${espcamip}/capture -o "${archivefolder}/train_${timestamp}.jpg"; then
      # Check if the picture size is bigger than 30K --> check if the camera settings are correct or needs a reconfiguration.
      # With default settings the file size is around 12K. With our configuration the size is around 60K. 30K is a good threashold.
      filesize=$(ls -l "${archivefolder}/train_${timestamp}.jpg" | cut -f 5 -d " ")
      if [ "$filesize" -lt 30000 ]; then
        echo "Reconfigure ESP32-CAM"
        # Set resolution to 720p and high quality
        curl -sS --max-time 1 "http://${espcamip}/control?var=framesize&val=11"
        curl -sS --max-time 1 "http://${espcamip}/control?var=quality&val=4"
        curl -sS --max-time 1 "http://${espcamip}/control?var=dcw&val=1"
        # Delete wrong file
        rm "${archivefolder}/train_${timestamp}.jpg"
      fi
    else
      echo "ESP is unreachable. Capture failed."
    fi
  else
    # Copy picture from the local mount --> expect an upload from the Raspberry
    
    newfile=$(ls -tp $sourcefolder/*jpg | head -n 1 | xargs -n 1 basename)
    if [ "${sourcefolder}/${newfile}" -nt "${archivefolder}/${lastfile}" ]; then
      # Check if the file size is not zero (e.g: it is still under upload)
      # Check 3 times and then step over to the next one.
      recheck=0
      while [[ ! -s "${sourcefolder}/${newfile}" && $recheck -lt 3 ]]; do
        sleep 0.1
        ((recheck++))
      done
      if [ -s "${sourcefolder}/${newfile}" ]; then
        # Copy and delete the latest file.
        # mv didn't work as it cannot preserve permissions and drops error.
        cp --no-preserve=mode "${sourcefolder}/${newfile}" "${archivefolder}/${newfile}"
        # Delete uneccessary (all but the last 5) files in the source folder.
        cd ${sourcefolder}
        ls -tp | grep -v '/$' | tail -n +6 | xargs -d '\n' -r rm --
        cd /home
      fi
    fi
  fi

  # Test for successful capture
  lastfile=$(ls -tp ${archivefolder}/*jpg | grep -v '/$' | grep -v masked | head -n 1 | xargs -n 1 basename)
  lastfiledate=$(ls -l --time-style="+%s" ${archivefolder}/${lastfile} | cut -f 6 -d " ")
  lastwebdate=$(ls -l --time-style="+%s" ${webfolder}/original.jpg | cut -f 6 -d " ")
  if [ "$lastfiledate" -gt "$lastwebdate" ]; then
    echo "Processing new file: "$lastfile
    # Start scoring
    python3 /home/masking.py "${archivefolder}/${lastfile}"
    # Copy to original and the masked files to the webfolder"
    lastmasked=$(ls -tp ${archivefolder}/*-masked.jpg | grep -v '/$' | head -n 1 | xargs -n 1 basename)
    cp "${archivefolder}/${lastfile}" "${webfolder}/original.jpg"
    cp "${archivefolder}/${lastmasked}" "${webfolder}/masked.jpg"
    # Cleanup old files in the archive folder if the cleanup environment variable is set
    if [ $cleanup ]; then
      cd ${archivefolder}
      ls -tp | grep -v '/$' | grep masked | tail -n +6 | xargs -d '\n' -r rm --
      ls -tp | grep -v '/$' | grep -v masked | tail -n +6 | xargs -d '\n' -r rm --
      cd /home
    fi
    # Upload to Azure Blob if parameters are specified
    if [ ! -z "$bloburl" ]; then
      curl -sS --max-time 1 -X PUT -T ${webfolder}/masked.jpg -H "x-ms-date: $(TZ=GMT date '+%a, %d %h %Y %H:%M:%S %Z')" -H "x-ms-blob-type: BlockBlob" "${bloburl}masked.jpg?${sastoken}" &
      curl -sS --max-time 1 -X PUT -T ${webfolder}/original.jpg -H "x-ms-date: $(TZ=GMT date '+%a, %d %h %Y %H:%M:%S %Z')" -H "x-ms-blob-type: BlockBlob" "${bloburl}original.jpg?${sastoken}" &
    fi
  fi
  # Optionally add some sleep to prevent super exhausting running.
  #sleep 0.2
done