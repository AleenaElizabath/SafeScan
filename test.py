import joblib

model = joblib.load("models/toxicity_model.pkl")
type_enc = joblib.load("models/chemical_type_encoder.pkl")
who_enc = joblib.load("models/who_class_encoder.pkl")
label_enc = joblib.load("models/toxicity_label_encoder.pkl")

# Example input
sample = [[
    type_enc.transform(["Insecticide"])[0],
    who_enc.transform(["Ib"])[0],
    9
]]

prediction = model.predict(sample)
result = label_enc.inverse_transform(prediction)

print("Predicted Toxicity Intensity:", result[0])
