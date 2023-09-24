import requests
from PIL import Image, ImageFont, ImageDraw as D
import json
import sys
import os
import base64

scoring_uri = os.environ['scoreendpoint']
key = os.environ['scorekey']
threshold = float(os.getenv('confidencethreshold', '0.8'))
image_file = sys.argv[1]

target_image = image_file.split('.')[0] + "-masked.jpg"
img = open(image_file, 'rb').read()
data = {
    "input_data": {
        "columns": ["image"],
        "data": [base64.encodebytes(img).decode('utf-8')],
    }
}
body = str.encode(json.dumps(data))
headers = {"Content-Type": "application/json"}
headers["Authorization"] = f"Bearer {key}"
resp = requests.post(scoring_uri, body, headers=headers)
#print(resp.text)

i=Image.open(image_file)
draw=D.Draw(i)
x, y = i.size

detections = json.loads(resp.text)
font = ImageFont.truetype("arial.ttf", size=30)
for detect in detections[0]['boxes']:
    label = detect['label']
    box = detect['box']
    conf_score = detect['score']
    if conf_score > threshold:
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
