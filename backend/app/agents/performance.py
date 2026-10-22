from fastapi import APIRouter
from app.schemas import BiomechanicsResult, PerformanceResult

router = APIRouter(prefix="/performance", tags=["Performance"])

@router.post("", response_model=PerformanceResult)
async def evaluate_performance(metrics: BiomechanicsResult):
    mistakes = []
    score = 100
    
    # Pose validation targets: Squat/Lifting or Boxing form
    if metrics.elbow_angle < 130:
        mistakes.append("Dominant elbow is flexed too low. Raise elbow above 140°.")
        score -= 20
        
    if metrics.back_angle < 160:
        mistakes.append("Spine curvature detected. Straighten back to maintain alignment.")
        score -= 25
        
    if metrics.balance_index < 0.80:
        mistakes.append("Core center of gravity shifted. Readjust balance coordinates.")
        score -= 15
        
    if metrics.efficiency < 0.70:
        mistakes.append("Kinetic efficiency is suboptimal. Focus on steady acceleration.")
        score -= 10

    # Blend the verified on-device TFLite estimate with the explainable server
    # rules. The mobile app sends landmarks and this scalar only; no image data
    # leaves the device.
    if metrics.on_device_quality_score is not None:
        device_score = max(0.0, min(100.0, metrics.on_device_quality_score))
        score = round((score * 0.70) + (device_score * 0.30))
        
    score = max(10, score) # minimum threshold
    is_correct = len(mistakes) == 0
    
    # Calculate score scaling (map to XP points)
    xp_score = int(score * 12.5) 
    
    return PerformanceResult(
        score=xp_score,
        is_correct=is_correct,
        detected_mistakes=mistakes
    )
