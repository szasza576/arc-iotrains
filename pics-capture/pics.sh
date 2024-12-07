#!/bin/bash

while true
do
    # Save the date with up to mircoseconds
    timestamp=$(date -u "+%Y%m%d-%H%M%S-%3N")
    # Create a picture
    # MJPG format saves directly from the Camera hence there is no encoding by the RPi
    # stream-skip will skip 1 frame and saves the 2nd one. This helps the camera to stabilize the picture and gives smoother series.
    # The filename starts with "train_" then the timestamp and then a number inside the same second.
    v4l2-ctl --set-fmt-video=width=1280,height=720,pixelformat=MJPG \
      --stream-mmap \
      --stream-count=1 \
      --stream-skip=1 \
      -d /dev/video0 \
      --stream-to=/mnt/pics/train_${timestamp}.jpg
done