"""Quick end-to-end test for the enhanced pesticide analysis flow."""
import sys
sys.stdout.reconfigure(encoding='utf-8')
import json

from services.farmer_service import save_farmer_profile
from services.pesticide_lookup_service import lookup_pesticide
from services.personalization_service import personalize_pesticide

print("=" * 60)
print("SAFESCAN PESTICIDE MODE - END-TO-END TEST")
print("=" * 60)

# Step 1: Create farmer profile
print("\n--- Step 1: Create Farmer Profile ---")
profile = save_farmer_profile(None, {
    "name": "Raju",
    "location": "Tamil Nadu",
    "crop_type": "Rice",
    "soil_type": "Clay",
    "season": "Kharif",
    "pesticides_used": ["Aldrin"]
})
print(f"  Farmer ID: {profile['farmer_id']}")
print(f"  Season: {profile.get('season', 'MISSING')}")

# Step 2: Lookup pesticide
print("\n--- Step 2: Lookup Pesticide (Endosulfan) ---")
pest = lookup_pesticide("Endosulfan")
if pest:
    print(f"  Found: {pest['chemical_name']}")
    print(f"  Status: {pest.get('regulatory_status_india', 'Unknown')}")
    print(f"  Toxicity: {pest['toxicity_intensity']}")
    print(f"  Match Confidence: {pest['match_confidence']}%")
else:
    print("  ERROR: Pesticide not found!")
    sys.exit(1)

# Step 3: Personalized analysis
print("\n--- Step 3: Personalized Analysis ---")
result = personalize_pesticide(profile, pest)
print(f"  Risk Category: {result['risk_category']}")
print(f"  Urgency: {result['urgency_level']}")
print(f"  AI Powered: {result['ai_powered']}")
print(f"  ML Model Used: {result['ml_model_used']}")
print(f"\n  Warning: {result['personalized_warning'][:250]}...")
print(f"\n  Usage Instructions: {len(result['usage_instructions'])} steps")
for i, step in enumerate(result['usage_instructions'][:3], 1):
    print(f"    {i}. {step}")
if len(result['usage_instructions']) > 3:
    print(f"    ... and {len(result['usage_instructions'])-3} more")

print(f"\n  Side Effects (Humans):")
for key, val in result['side_effects_humans'].items():
    print(f"    {key}: {str(val)[:100]}...")

print(f"\n  Side Effects (Environment):")
for key, val in result['side_effects_environment'].items():
    print(f"    {key}: {str(val)[:100]}...")

print(f"\n  Eco-Friendly Alternatives: {len(result['eco_friendly_alternatives'])} options")
for alt in result['eco_friendly_alternatives']:
    print(f"    - {alt['name']}: {alt['why_suitable'][:80]}")

print(f"\n  Crop Warnings: {len(result['crop_specific_warnings'])} items")
for w in result['crop_specific_warnings']:
    print(f"    - {w}")

print(f"\n  Season Warnings: {len(result['season_specific_warnings'])} items")
for w in result['season_specific_warnings']:
    print(f"    - {w}")

# Step 4: Summary
print("\n--- Step 4: Summary (for Android app) ---")
print(json.dumps(result['summary'], indent=2, ensure_ascii=False))

# Step 5: Test with a DIFFERENT farmer profile (should give DIFFERENT results)
print("\n" + "=" * 60)
print("DIFFERENTIATION TEST: Wheat farmer in Punjab, Rabi season")
print("=" * 60)
profile2 = save_farmer_profile(None, {
    "name": "Harpreet",
    "location": "Punjab",
    "crop_type": "Wheat",
    "soil_type": "Sandy Loam",
    "season": "Rabi",
    "pesticides_used": [Aldrin]
})
result2 = personalize_pesticide(profile2, pest)
print(f"  Risk Category: {result2['risk_category']}")
print(f"  Warning: {result2['personalized_warning'][:250]}...")
print(f"  Season Note: {result2.get('crop_season_note', 'N/A')[:200]}")
print(f"  Crop Warnings: {len(result2['crop_specific_warnings'])} items")
for w in result2['crop_specific_warnings']:
    print(f"    - {w}")
print(f"  Season Warnings: {len(result2['season_specific_warnings'])} items")
for w in result2['season_specific_warnings']:
    print(f"    - {w}")

# Verify different results
if result['crop_specific_warnings'] != result2['crop_specific_warnings']:
    print("\n  [PASS] Crop warnings are DIFFERENT for different profiles!")
else:
    print("\n  [WARN] Crop warnings are the same for different profiles")

if result['season_specific_warnings'] != result2['season_specific_warnings']:
    print("  [PASS] Season warnings are DIFFERENT for different seasons!")
else:
    print("  [WARN] Season warnings are the same for different seasons")

print("\n" + "=" * 60)
print("ALL TESTS COMPLETE")
print("=" * 60)
