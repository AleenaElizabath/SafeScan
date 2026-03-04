import pandas as pd
import joblib
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier, StackingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from xgboost import XGBClassifier
import lightgbm as lgb

# -------------------------
# LOAD DATASET
# ------------------------- 
df = pd.read_csv("datasets/SafeScan_Final_Accurate_Dataset.csv")

# -------------------------
# CLEAN COLUMN NAMES
# -------------------------
df.columns = df.columns.str.strip().str.lower()

# -------------------------
# TARGET VARIABLE
# -------------------------
y = df["toxicity_intensity"]

# -------------------------
# FEATURES FROM DATASET
# -------------------------
features = [
    "chemical_type",
    "who_hazard_class",
    "toxicity_score",
    "regulatory_status"
]

X = df[features]

# -------------------------
# PREPROCESSING
# -------------------------
categorical_cols = [
    "chemical_type",
    "who_hazard_class",
    "regulatory_status"
]

numeric_cols = ["toxicity_score"]

preprocessor = ColumnTransformer(
    transformers=[
        ("cat", OneHotEncoder(handle_unknown="ignore"), categorical_cols),
        ("num", "passthrough", numeric_cols)
    ]
)

# -------------------------
# STACKED ENSEMBLE
# -------------------------
rf = RandomForestClassifier(n_estimators=200, random_state=42)
xgb = XGBClassifier(eval_metric="mlogloss", random_state=42)
lgbm = lgb.LGBMClassifier(random_state=42)

stack = StackingClassifier(
    estimators=[
        ("rf", rf),
        ("xgb", xgb),
        ("lgbm", lgbm)
    ],
    final_estimator=LogisticRegression()
)

pipeline = Pipeline([
    ("preprocess", preprocessor),
    ("model", stack)
])

# -------------------------
# TRAIN TEST SPLIT
# -------------------------
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

pipeline.fit(X_train, y_train)

# -------------------------
# SAVE MODEL
# -------------------------
joblib.dump(pipeline, "toxicity_stack_model.pkl")

print("✅ Model trained successfully.")