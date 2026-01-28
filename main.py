from fastapi import FastAPI

app = FastAPI(title="SafeScan Backend")

@app.get("/")
def root():
    return {"message": "SafeScan backend running"}
