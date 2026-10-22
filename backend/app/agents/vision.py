from fastapi import APIRouter
from app.schemas import PoseInput
from pydantic import BaseModel

router = APIRouter(prefix="/vision", tags=["Vision"])

class VisionResult(BaseModel):
    is_moving: bool
    detected_joints_count: int
    tracking_quality_index: float

@router.post("", response_model=VisionResult)
async def process_media_pipe(pose: PoseInput):
    joints_count = len(pose.keypoints)
    
    # Calculate a simple tracking quality based on visibility metrics
    if joints_count == 0:
        return VisionResult(is_moving=False, detected_joints_count=0, tracking_quality_index=0.0)
        
    avg_visibility = sum(j.visibility for j in pose.keypoints) / joints_count
    
    # Calculate standard deviation or variance of coordinates to determine movement activity
    # For simulation, we check if coordinates have non-zero variance values
    x_coords = [j.x for j in pose.keypoints]
    y_coords = [j.y for j in pose.keypoints]
    
    x_var = sum((x - sum(x_coords)/joints_count)**2 for x in x_coords) / joints_count
    y_var = sum((y - sum(y_coords)/joints_count)**2 for y in y_coords) / joints_count
    
    is_moving = (x_var + y_var) > 0.01
    
    return VisionResult(
        is_moving=is_moving,
        detected_joints_count=joints_count,
        tracking_quality_index=round(avg_visibility, 2)
    )
