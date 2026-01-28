import pandas as pd
from flask import Flask, request, jsonify

app = Flask(__name__)

df = pd.read_csv("dataset/SafeScan_Final_Accurate_Dataset.csv")

@app.route("/predict", methods=["POST"])
def predict():
    data = request.get_json()
    text = data.get("text", "").lower()

    # Simple match
    match = df[df["chemical_name"].str.lower().str.contains(text)]

    if match.empty:
        return jsonify({
            "status": "Unknown",
            "message": "Chemical not found in database"
        })

    row = match.iloc[0]

    return jsonify({
        "chemical_name": row["chemical_name"],
        "regulatory_status": row["regulatory_status"],
        "toxicity_intensity": row["toxicity_intensity"],
        "human_health_effects": row["human_health_effects"],
        "environmental_effects": row["environmental_effects"],
        "recommended_alternative": row["recommended_alternative"]
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
