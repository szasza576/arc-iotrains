#!/bin/bash

# Get the timestamp
while true; do
  timestamp=$(date -u "+%Y%m%d-%H%M%S-%3N")
  if curl -sS --max-time 2 http://${espcamip}/capture -o "${archivefolder}/train_${timestamp}.jpg"; then
    # Check if the picture size is bigger than 30K --> check if the camera settings are correct or needs a reconfiguration.
    # This method is faster than reconfiguring the camera at each capture.
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
    echo "ESP is unreachable. Capture failed. Wait 5 seconds."
    sleep 5
  fi
done