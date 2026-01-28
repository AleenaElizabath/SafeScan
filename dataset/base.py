import pandas as pd

df = pd.read_csv("SafeScan_Toxicity_Dataset_1200.csv")

# Keep only reliable columns
clean_df = df[[
    "toxicity_score",
    "toxicity_intensity",
    "who_hazard_class"
]].copy()

# Map toxicity intensity
toxicity_map = {
    "Very Low": 1,
    "Low": 2,
    "Moderate": 3,
    "High": 4,
    "Extreme": 5
}

clean_df["toxicity_intensity"] = clean_df["toxicity_intensity"].map(toxicity_map)

# Map WHO class
who_map = {"U": 1, "III": 2, "II": 3, "Ib": 4, "Ia": 5}
clean_df["who_hazard_class"] = clean_df["who_hazard_class"].map(who_map)

# Convert toxicity score
clean_df["toxicity_score"] = pd.to_numeric(clean_df["toxicity_score"], errors="coerce")

# Drop only invalid rows
clean_df = clean_df.dropna()

print("Final usable rows:", clean_df.shape)

clean_df.to_csv("clean_training_data.csv", index=False)
