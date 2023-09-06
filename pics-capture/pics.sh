#!/bin/bash

while true
do
    # Save the date with up to seconds
    timestamp=$(date -u "+%Y%m%d-%H%M%S")
    # Check if a file already exist with the same date and add increasing number to the end
    num=0
    while [[ -f "/mnt/pics/train_${timestamp}-${num}.jpg" ]]
    do
      ((num++))
    done
    # Create a picture
    # MJPG format saves directly from the Camera hence there is no encoding by the RPi
    # stream-skip will skip 1 frame and saves the 2nd one. This helps the camera to stabilize the picture and gives smoother series.
    # The filename starts with "train_" then the timestamp and then a number inside the same second.
    v4l2-ctl --set-fmt-video=width=1920,height=1080,pixelformat=MJPG \
      --stream-mmap \
      --stream-count=1 \
      --stream-skip=1 \
      -d /dev/video0 \
      --stream-to=/mnt/pics/train_${timestamp}-${num}.jpg
done