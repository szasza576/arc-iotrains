FROM python:3-slim-bullseye

ENV scoreendpoint=http://192.168.0.143/api/v1/endpoint/minifigures/score
ENV scorekey=ETPVefMh7pMLIPo4u6j4eyZkBIjXp8gp
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