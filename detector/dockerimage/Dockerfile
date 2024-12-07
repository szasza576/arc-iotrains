FROM python:3-slim-bullseye

ENV sourcefolder=/mnt/source
ENV archivefolder=/mnt/archive
ENV webfolder=/mnt/web

WORKDIR /home

COPY requirements.txt .
COPY arial.ttf .

RUN apt update && \
    apt upgrade -y && \
    apt install -y curl inotify-tools && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/

RUN pip install --no-cache-dir -r requirements.txt

COPY masking.py .
COPY watcher.sh .
COPY esp-grabber.sh .
RUN chmod +x watcher.sh && \
    chmod +x esp-grabber.sh
RUN \
    mkdir $sourcefolder && \
    mkdir $archivefolder && \
    mkdir $webfolder

CMD [ "./watcher.sh" ]