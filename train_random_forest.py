import pandas as pd
import joblib
from sklearn.metrics import balanced_accuracy_score
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report

# --------------------------------------------------
# 1️⃣ LOAD DATASET
# --------------------------------------------------
df = pd.read_csv("dataset/SafeScan_Final_Accurate_Dataset.csv")
print("Dataset loaded:", df.shape)

# --------------------------------------------------
# 2️⃣ BALANCE THE DATASET (VERY IMPORTANT)
# --------------------------------------------------
df = (
    df.groupby("toxicity_intensity", group_keys=False)
      .apply(lambda x: x.sample(min(len(x), 120), random_state=42))
      .reset_index(drop=True)
)

print("Balanced dataset:", df.shape)

# --------------------------------------------------
# 3️⃣ CREATE TEXT FEATURE (NLP INPUT)
# --------------------------------------------------
df["text_feature"] = (
    df["chemical_name"] + " " +
    df["chemical_type"] + " " +
    df["human_health_effects"]
)


X_text = df["text_feature"]
y = df["regulatory_status"]

# --------------------------------------------------
# 4️⃣ TF-IDF VECTORIZATION
# --------------------------------------------------
vectorizer = TfidfVectorizer(
    max_features=800,        # small increase
    ngram_range=(1, 2),      # reintroduce bigrams
    stop_words="english",
    min_df=3
)

X = vectorizer.fit_transform(X_text)

# --------------------------------------------------
# 5️⃣ TRAIN-TEST SPLIT (STRATIFIED)
# --------------------------------------------------
X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.6,           # more unseen data
    stratify=y,
    random_state=42
)


# --------------------------------------------------
# 6️⃣ RANDOM FOREST MODEL (CONTROLLED)
# --------------------------------------------------
model = RandomForestClassifier(
    n_estimators=50,
    max_depth=5,
    min_samples_leaf=8,
    random_state=42
)

model.fit(X_train, y_train)

# --------------------------------------------------
# 7️⃣ EVALUATION
# --------------------------------------------------
y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)

print("\nModel Accuracy:", accuracy)
print("\nClassification Report:\n")
print(classification_report(y_test, y_pred))

# --------------------------------------------------
# 8️⃣ SAVE MODEL & VECTORIZER
# --------------------------------------------------
joblib.dump(model, "toxicity_model.pkl")
joblib.dump(vectorizer, "vectorizer.pkl")

print("Balanced Accuracy:", balanced_accuracy_score(y_test, y_pred))
print(classification_report(y_test, y_pred))
print("\n✅ Model and vectorizer saved successfully")
