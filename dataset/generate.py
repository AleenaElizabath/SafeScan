import pandas as pd
import numpy as np

np.random.seed(42)

rows = []

for _ in range(1000):
    who_class = np.random.choice([1, 2, 3, 4, 5])  # U → Ia
    toxicity_score = np.random.randint(1, 11)

    if toxicity_score <= 2:
        intensity = 1
    elif toxicity_score <= 4:
        intensity = 2
    elif toxicity_score <= 6:
        intensity = 3
    elif toxicity_score <= 8:
        intensity = 4
    else:
        intensity = 5

    rows.append([toxicity_score, who_class, intensity])

df = pd.DataFrame(
    rows,
    columns=["toxicity_score", "who_hazard_class", "toxicity_intensity"]
)

df.to_csv("ml_training_data.csv", index=False)
print("Training dataset created:", df.shape)
