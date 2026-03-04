"""
Enhanced Pesticide Risk Model Training Script

Features used:
  - From dataset: chemical_type, who_hazard_class, toxicity_score, regulatory_status
  - Derived at training time: synthetic crop/soil/season rows for richer training

Target: risk_category
  - BANNED: regulatory_status is "Banned"
  - RESTRICTED_EXTREME: Restricted + toxicity Extreme
  - RESTRICTED_HIGH: Restricted + toxicity High
  - RESTRICTED_MODERATE: Restricted + toxicity Moderate

Model: Stacking Ensemble (RF + XGBoost + LightGBM -> LogisticRegression)

Usage:
    py train_pesticide_risk_model.py
"""

import pandas as pd
import numpy as np
import joblib
import json
import os
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.ensemble import RandomForestClassifier, StackingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import OneHotEncoder, LabelEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.metrics import classification_report, accuracy_score
from xgboost import XGBClassifier
import lightgbm as lgb
import warnings
warnings.filterwarnings('ignore')

# ──────────────────────────────────────────────
# LOAD DATASET
# ──────────────────────────────────────────────
print(" Loading dataset...")
df = pd.read_csv("datasets/SafeScan_Final_Accurate_Dataset.csv")
df.columns = df.columns.str.strip().str.lower()

print(f"   Shape: {df.shape}")
print(f"   Columns: {df.columns.tolist()}")

# ──────────────────────────────────────────────
# CREATE RISK CATEGORY TARGET
# ──────────────────────────────────────────────
def assign_risk_category(row):
    status = str(row.get("regulatory_status", "")).lower()
    toxicity = str(row.get("toxicity_intensity", "")).lower()

    if status == "banned":
        return "BANNED"
    elif status == "restricted" and toxicity == "extreme":
        return "RESTRICTED_EXTREME"
    elif status == "restricted" and toxicity == "high":
        return "RESTRICTED_HIGH"
    elif status == "restricted" and toxicity == "moderate":
        return "RESTRICTED_MODERATE"
    else:
        return "RESTRICTED_MODERATE"  # default for unknowns

df["risk_category"] = df.apply(assign_risk_category, axis=1)

print(f"\n Risk category distribution:")
print(df["risk_category"].value_counts())

# ──────────────────────────────────────────────
# AUGMENT WITH CROP / SOIL / SEASON SENSITIVITY
# Encode domain knowledge into numeric features
# ──────────────────────────────────────────────

# Crop sensitivity to pesticide damage (scale 1-5)
CROP_SENSITIVITY = {
    "rice": 4, "paddy": 4, "wheat": 3, "cotton": 4, "maize": 3,
    "corn": 3, "sugarcane": 2, "soybean": 3, "tomato": 4, "potato": 3,
    "onion": 3, "groundnut": 3, "sunflower": 3, "mustard": 2,
    "banana": 4, "mango": 3, "grape": 4, "vegetable": 4,
    "default": 3
}

# Soil retention index (higher = chemical stays longer)
SOIL_RETENTION = {
    "clay": 5, "loam": 3, "sandy loam": 2, "sandy": 1,
    "black": 4, "red": 2, "alluvial": 3, "laterite": 2,
    "default": 3
}

# Season environmental risk factor
SEASON_RISK = {
    "kharif": 5,    # Monsoon - high leaching risk
    "rabi": 2,      # Winter - low volatilization
    "zaid": 4,      # Summer - high volatilization
    "summer": 4,
    "winter": 2,
    "default": 3
}

# WHO hazard class numeric
WHO_NUMERIC = {"ia": 5, "ib": 4, "ii": 3, "iii": 2, "u": 1}

# Expand dataset with synthetic crop/soil/season combinations for each row
print("\n Augmenting dataset with crop/soil/season features...")

expanded_rows = []
crops = list(CROP_SENSITIVITY.keys())[:-1]  # Exclude "default"
soils = list(SOIL_RETENTION.keys())[:-1]
seasons = ["kharif", "rabi", "zaid"]

import random
random.seed(42)

for _, row in df.iterrows():
    # Add 3 synthetic rows per base row with random crop/soil/season combos
    for _ in range(3):
        c = random.choice(crops)
        s = random.choice(soils)
        sn = random.choice(seasons)
        expanded_rows.append({
            "chemical_type": row["chemical_type"],
            "who_hazard_class": row["who_hazard_class"],
            "toxicity_score": row["toxicity_score"],
            "regulatory_status": row["regulatory_status"],
            "crop_sensitivity": CROP_SENSITIVITY.get(c, 3),
            "soil_retention": SOIL_RETENTION.get(s, 3),
            "season_risk": SEASON_RISK.get(sn, 3),
            "who_numeric": WHO_NUMERIC.get(row["who_hazard_class"].lower(), 3),
            "risk_category": row["risk_category"]
        })

expanded_df = pd.DataFrame(expanded_rows)
print(f"   Augmented shape: {expanded_df.shape}")

# ──────────────────────────────────────────────
# FEATURES AND TARGET
# ──────────────────────────────────────────────
CATEGORICAL_FEATURES = ["chemical_type", "who_hazard_class", "regulatory_status"]
NUMERIC_FEATURES = [
    "toxicity_score", "crop_sensitivity", "soil_retention",
    "season_risk", "who_numeric"
]

X = expanded_df[CATEGORICAL_FEATURES + NUMERIC_FEATURES]
y = expanded_df["risk_category"]

# Encode target
le = LabelEncoder()
y_encoded = le.fit_transform(y)

print(f"\n Feature columns: {CATEGORICAL_FEATURES + NUMERIC_FEATURES}")
print(f" Classes: {le.classes_.tolist()}")

# ──────────────────────────────────────────────
# PREPROCESSING PIPELINE
# ──────────────────────────────────────────────
preprocessor = ColumnTransformer(
    transformers=[
        ("cat", OneHotEncoder(handle_unknown="ignore", sparse_output=False), CATEGORICAL_FEATURES),
        ("num", "passthrough", NUMERIC_FEATURES)
    ]
)

# ──────────────────────────────────────────────
# STACKING ENSEMBLE
# ──────────────────────────────────────────────
rf = RandomForestClassifier(n_estimators=200, max_depth=10, random_state=42, n_jobs=-1)
xgb = XGBClassifier(
    n_estimators=100,
    learning_rate=0.1,
    max_depth=5,
    eval_metric="mlogloss",
    random_state=42,
    verbosity=0
)
lgbm = lgb.LGBMClassifier(
    n_estimators=100,
    learning_rate=0.1,
    max_depth=5,
    random_state=42,
    verbose=-1
)

stack = StackingClassifier(
    estimators=[
        ("rf", rf),
        ("xgb", xgb),
        ("lgbm", lgbm)
    ],
    final_estimator=LogisticRegression(max_iter=1000),
    cv=3,
    n_jobs=-1
)

pipeline = Pipeline([
    ("preprocess", preprocessor),
    ("model", stack)
])

# ──────────────────────────────────────────────
# TRAIN / TEST SPLIT
# ──────────────────────────────────────────────
X_train, X_test, y_train, y_test = train_test_split(
    X, y_encoded, test_size=0.2, random_state=42, stratify=y_encoded
)

print(f"\n Training stacking ensemble on {len(X_train)} samples...")
pipeline.fit(X_train, y_train)

# ──────────────────────────────────────────────
# EVALUATE
# ──────────────────────────────────────────────
y_pred = pipeline.predict(X_test)
acc = accuracy_score(y_test, y_pred)
print(f"\n Test Accuracy: {acc:.4f}")
print("\n Classification Report:")
print(classification_report(y_test, y_pred, target_names=le.classes_))

# ──────────────────────────────────────────────
# SAVE MODEL
# ──────────────────────────────────────────────
os.makedirs("models", exist_ok=True)

model_payload = {
    "pipeline": pipeline,
    "label_encoder": le,
    "categorical_features": CATEGORICAL_FEATURES,
    "numeric_features": NUMERIC_FEATURES,
    "crop_sensitivity": CROP_SENSITIVITY,
    "soil_retention": SOIL_RETENTION,
    "season_risk": SEASON_RISK,
    "who_numeric": WHO_NUMERIC
}

joblib.dump(model_payload, "models/pesticide_risk_model.pkl")
print("\n Model saved to models/pesticide_risk_model.pkl")

# Save training metrics
metrics = {
    "accuracy": round(acc, 4),
    "classes": le.classes_.tolist(),
    "training_samples": len(X_train),
    "test_samples": len(X_test),
    "features": CATEGORICAL_FEATURES + NUMERIC_FEATURES,
    "model": "StackingClassifier (RF + XGBoost + LightGBM -> LogisticRegression)"
}
with open("models/pesticide_risk_metrics.json", "w") as f:
    json.dump(metrics, f, indent=2)

print(" Metrics saved to models/pesticide_risk_metrics.json")
print("\n Training complete!")
