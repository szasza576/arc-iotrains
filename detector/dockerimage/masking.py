# Testrun command: python.exe .\masking.py "c:\\Onedrive\\Barkács\\AzureML-Train\\Python-script\\train_20221102_172715-0.jpg"

import requests
from PIL import Image, ImageFont, ImageDraw as D
import json
import sys
import os

scoring_uri = os.environ['scoreendpoint']
key = os.environ['scorekey']
image_file = sys.argv[1]

target_image = image_file.split('.')[0] + "-masked.jpg"
data = open(image_file, "rb").read()
headers = {"Content-Type": "application/octet-stream"}
headers["Authorization"] = f"Bearer {key}"
resp = requests.post(scoring_uri, data, headers=headers)
#print(resp.text)

i=Image.open(image_file)
draw=D.Draw(i)
x, y = i.size

detections = json.loads(resp.text)
font = ImageFont.truetype("arial.ttf", size=30)
for detect in detections['boxes']:
    label = detect['label']
    box = detect['box']
    conf_score = detect['score']
    if conf_score > 0.3:
        ymin, xmin, ymax, xmax =  box['topY'],box['topX'], box['bottomY'],box['bottomX']
        topleft_x, topleft_y = x * xmin, y * ymin
        bottomright_x, bottomright_y = x * xmax, y * ymax
        if label == "DarthVader":
            color='red'
        else:
            color='blue'
        draw.rectangle([(topleft_x,topleft_y),(bottomright_x,bottomright_y)],outline=color,width=5)
        draw.text((topleft_x, topleft_y - 35), str(round(conf_score*100, 1)) + "%",font=font,fill='white')
i.save(bitmap_format="jpg",fp=target_image)
