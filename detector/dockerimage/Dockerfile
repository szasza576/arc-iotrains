FROM python:3-slim-bullseye

ENV sourcefolder=/mnt/source
ENV archivefolder=/mnt/archive
ENV webfolder=/mnt/web

WORKDIR /home

COPY requirements.txt .
COPY arial.ttf .

RUN apt update && \
    apt install -y curl && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/

RUN pip install --no-cache-dir -r requirements.txt

COPY masking.py .
COPY watcher.sh .
RUN chmod +x watcher.sh
RUN \
    mkdir $sourcefolder && \
    mkdir $archivefolder && \
    mkdir $webfolder

CMD [ "./watcher.sh" ]