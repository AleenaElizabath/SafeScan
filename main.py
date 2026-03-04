"""
SafeScan Backend - AI-powered Agricultural Assistant
FastAPI server for pesticide analysis and plant disease detection
"""

import os
import shutil
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional, List

# Import services
from services.farmer_service import (
    save_farmer_profile, 
    get_farmer_profile, 
    update_farmer_profile,
    delete_farmer_profile,
    get_all_farmers
)
from services.ocr_service import extract_text, extract_structured_text
from services.pesticide_lookup_service import (
    lookup_pesticide,
    analyze_pesticide_risk,
    get_pesticide_by_name,
    get_banned_pesticides,
    get_restricted_pesticides,
    get_eco_friendly_alternatives
)
from services.plant_disease_service import predict_disease
from services.personalization_service import (
    personalize_pesticide, 
    personalize_disease,
    generate_comprehensive_report
)

# Create FastAPI app
app = FastAPI(
    title="SafeScan API",
    description="AI-powered Agricultural Assistant for Pesticide Analysis and Plant Disease Detection",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create temp directory for uploaded files
TEMP_DIR = "temp_uploads"
os.makedirs(TEMP_DIR, exist_ok=True)

def cleanup_temp_file(filepath):
    """Clean up temporary file after processing"""
    try:
        if os.path.exists(filepath):
            os.remove(filepath)
    except Exception:
        pass

# ============================================================================
# FARMER PROFILE ENDPOINTS
# ============================================================================

@app.post("/api/farmer/save_profile")
async def save_profile(
    farmer_id: Optional[str] = Form(None),
    name: str = Form(...),
    location: str = Form(...),
    crop_type: str = Form(...),
    soil_type: str = Form(""),
    season: Optional[str] = Form(""),
    pesticides_used: str = Form("")
):
    """
    Save or update farmer profile
    
    Parameters:
    - farmer_id: Optional existing farmer ID (auto-generated if not provided)
    - name: Farmer's name
    - location: Farm location
    - crop_type: Type of crops grown
    - soil_type: Soil type
    - pesticides_used: Comma-separated list of pesticides used
    """
    # Parse pesticides list
    pesticides_list = [p.strip() for p in pesticides_used.split(",") if p.strip()]
    
    profile_data = {
        "name": name,
        "location": location,
        "crop_type": crop_type,
        "soil_type": soil_type,
        "season": season or "",
        "pesticides_used": pesticides_list
    }
    
    farmer = save_farmer_profile(farmer_id, profile_data)
    
    return {
        "success": True,
        "message": "Profile saved successfully",
        "farmer_id": farmer["farmer_id"],
        "profile": farmer
    }


@app.get("/api/farmer/profile/{farmer_id}")
async def get_profile(farmer_id: str):
    """Get farmer profile by ID"""
    profile = get_farmer_profile(farmer_id)
    
    if profile is None:
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    
    return {
        "success": True,
        "profile": profile
    }


@app.put("/api/farmer/profile/{farmer_id}")
async def update_profile(
    farmer_id: str,
    name: Optional[str] = Form(None),
    location: Optional[str] = Form(None),
    crop_type: Optional[str] = Form(None),
    soil_type: Optional[str] = Form(None),
    season: Optional[str] = Form(None),
    pesticides_used: Optional[str] = Form(None)
):
    """Update farmer profile"""
    profile_data = {}
    
    if name is not None:
        profile_data["name"] = name
    if location is not None:
        profile_data["location"] = location
    if crop_type is not None:
        profile_data["crop_type"] = crop_type
    if soil_type is not None:
        profile_data["soil_type"] = soil_type
    if season is not None:
        profile_data["season"] = season
    if pesticides_used is not None:
        profile_data["pesticides_used"] = [p.strip() for p in pesticides_used.split(",") if p.strip()]
    
    farmer = update_farmer_profile(farmer_id, profile_data)
    
    return {
        "success": True,
        "message": "Profile updated successfully",
        "profile": farmer
    }


@app.delete("/api/farmer/profile/{farmer_id}")
async def delete_profile(farmer_id: str):
    """Delete farmer profile"""
    success = delete_farmer_profile(farmer_id)
    
    if not success:
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    
    return {
        "success": True,
        "message": "Profile deleted successfully"
    }


@app.get("/api/farmers")
async def list_farmers():
    """Get all farmer profiles"""
    farmers = get_all_farmers()
    return {
        "success": True,
        "count": len(farmers),
        "farmers": farmers
    }

# ============================================================================
# PESTICIDE ANALYSIS ENDPOINTS
# ============================================================================

@app.post("/api/pesticide/analyze")
async def pesticide_analysis(
    farmer_id: str = Form(...),
    file: UploadFile = File(...)
):
    """
    Analyze pesticide from image
    
    Workflow:
    1. Get farmer profile
    2. Extract text from pesticide label image using OCR
    3. Look up pesticide in database
    4. Generate personalized recommendations
    """
    # Get farmer profile
    profile = get_farmer_profile(farmer_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Farmer profile not found. Please create a profile first.")
    
    # Save uploaded file
    temp_path = os.path.join(TEMP_DIR, f"pesticide_{file.filename}")
    with open(temp_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    try:
        # Extract structured info from image (better matching)
        ocr_result = extract_structured_text(temp_path)
        extracted_text = ocr_result.get("raw_text", "")

        if not extracted_text:
            return {
                "success": False,
                "message": "Could not extract text from image. Please try with a clearer image.",
                "extracted_text": ""
            }

        # Look up pesticide using structured OCR output (tries candidate names too)
        pesticide_data = lookup_pesticide(ocr_result)
        
        if pesticide_data is None:
            # Try to get risk analysis anyway
            risk_analysis = analyze_pesticide_risk(extracted_text)
            return {
                "success": False,
                "message": "Pesticide not found in database",
                "extracted_text": extracted_text,
                "risk_analysis": risk_analysis
            }
        
        # Generate personalized analysis
        result = personalize_pesticide(profile, pesticide_data)
        
        return {
            "success": True,
            "message": "Analysis complete",
            "extracted_text": extracted_text,
            "result": result
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing image: {str(e)}")
    finally:
        cleanup_temp_file(temp_path)


@app.post("/api/pesticide/analyze/text")
async def pesticide_analysis_text(
    farmer_id: str,
    pesticide_name: str
):
    """
    Analyze pesticide by name (without image)
    
    Parameters:
    - farmer_id: Farmer ID
    - pesticide_name: Name of the pesticide
    """
    profile = get_farmer_profile(farmer_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Farmer profile not found")
    
    pesticide_data = lookup_pesticide(pesticide_name)
    
    if pesticide_data is None:
        return {
            "success": False,
            "message": "Pesticide not found in database",
            "pesticide_name": pesticide_name
        }
    
    result = personalize_pesticide(profile, pesticide_data)
    
    return {
        "success": True,
        "result": result
    }


@app.get("/api/pesticide/banned")
async def get_banned():
    """Get list of banned pesticides"""
    pesticides = get_banned_pesticides()
    return {
        "success": True,
        "count": len(pesticides),
        "pesticides": pesticides
    }


@app.get("/api/pesticide/restricted")
async def get_restricted():
    """Get list of restricted pesticides"""
    pesticides = get_restricted_pesticides()
    return {
        "success": True,
        "count": len(pesticides),
        "pesticides": pesticides
    }


@app.get("/api/pesticide/alternatives")
async def get_alternatives(chemical_type: Optional[str] = None):
    """Get eco-friendly alternatives"""
    alternatives = get_eco_friendly_alternatives(chemical_type)
    return {
        "success": True,
        "alternatives": alternatives
    }

# ============================================================================
# PLANT DISEASE DETECTION ENDPOINTS
# ============================================================================

@app.post("/api/plant_disease/detect")
async def plant_disease_detection(
    farmer_id: str = Form(...),
    file: UploadFile = File(...)
):
    """
    Detect plant disease from image
    
    Workflow:
    1. Get farmer profile
    2. Process plant/leaf image through ML model
    3. Get disease prediction
    4. Generate personalized recommendations
    """
    # Get farmer profile
    profile = get_farmer_profile(farmer_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Farmer profile not found. Please create a profile first.")
    
    # Save uploaded file
    temp_path = os.path.join(TEMP_DIR, f"plant_{file.filename}")
    with open(temp_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    try:
        # Get disease prediction from model
        disease_prediction = predict_disease(temp_path)
        
        if not disease_prediction:
            return {
                "success": False,
                "message": "Could not analyze the image. Please try with a clearer image of the plant/leaf."
            }
        
        # Generate personalized analysis
        result = personalize_disease(profile, disease_prediction)
        
        return {
            "success": True,
            "message": "Disease detection complete",
            "prediction": disease_prediction,
            "result": result
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing image: {str(e)}")
    finally:
        cleanup_temp_file(temp_path)


# ============================================================================
# HEALTH CHECK ENDPOINTS
# ============================================================================

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "name": "SafeScan API",
        "version": "1.0.0",
        "description": "AI-powered Agricultural Assistant",
        "endpoints": {
            "farmer_profile": "/api/farmer/*",
            "pesticide_analysis": "/api/pesticide/*",
            "plant_disease": "/api/plant_disease/*"
        }
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "services": {
            "farmer_service": "ok",
            "ocr_service": "ok",
            "pesticide_service": "ok",
            "plant_disease_service": "ok"
        }
    }

# Run with: uvicorn main:app --reload
