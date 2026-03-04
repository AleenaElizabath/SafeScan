import requests
import os

BASE_URL = "http://127.0.0.1:8000"
FARMER_ID = "92c73913b4ed" # From previous test run
IMAGE_PATH = "datasets/test_pesticide.jpg" # I hope this exists or I'll use any image

# Create a small dummy image for testing if doesn't exist
if not os.path.exists(IMAGE_PATH):
    os.makedirs("datasets", exist_ok=True)
    with open(IMAGE_PATH, "wb") as f:
        f.write(b"dummy image data")

url = f"{BASE_URL}/api/pesticide/analyze"
files = {'file': ('test.jpg', open(IMAGE_PATH, 'rb'), 'image/jpeg')}
data = {'farmer_id': FARMER_ID}

try:
    response = requests.post(url, files=files, data=data)
    print(f"Status: {response.status_code}")
    print("Response JSON:")
    import json
    print(json.dumps(response.json(), indent=2))
except Exception as e:
    print(f"Error: {e}")
