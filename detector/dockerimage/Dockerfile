FROM python:3-slim-bullseye

ENV sourcefolder=/mnt/source
ENV archivefolder=/mnt/archive
ENV webfolder=/mnt/web

WORKDIR /home

COPY masking.py .
COPY requirements.txt .
COPY watcher.sh .
COPY arial.ttf .

RUN pip install --no-cache-dir -r requirements.txt
RUN chmod +x watcher.sh
RUN \
    mkdir $sourcefolder && \
    mkdir $archivefolder && \
    mkdir $webfolder

CMD [ "./watcher.sh" ]