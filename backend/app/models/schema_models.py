from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime

class FileUploadResponse(BaseModel):
    file_id: int
    filename: str
    file_type: str
    category: str
    parsing_summary: dict
    warnings: List[str] = []

class StyleInfo(BaseModel):
    style_number: str
    division: Optional[str] = None
    outsole: Optional[str] = None
    gender: Optional[str] = None
    colors: List[str] = []
    source_files: List[int] = []

class LookupResponse(BaseModel):
    status: str
    style_number: str
    color: Optional[str] = None
    division: Optional[str] = None
    gender: Optional[str] = None
    outsole: Optional[str] = None
    colors: List[str] = []
    message: str
    source_files: List[int] = []

class ClassificationRequest(BaseModel):
    style_number: str
    color: str
    status: str
    coordinator_user_id: Optional[int] = None
    coordinator_name: Optional[str] = None
    confidence_score: Optional[float] = None
    notes: Optional[str] = None
    
    @validator('status')
    def validate_status(cls, v):
        if v not in ['keep', 'wait', 'drop']:
            raise ValueError('Status must be keep, wait, or drop')
        return v

class ClassificationResponse(BaseModel):
    classification_id: int
    style_number: str
    color: str
    status: str
    message: str

class PendingClassification(BaseModel):
    classification_id: int
    style_number: str
    color: str
    coordinator_assigned_status: str
    coordinator_name: Optional[str] = None
    submission_timestamp: datetime
    complete_style_info: Optional[StyleInfo] = None
    confidence_score: Optional[float] = None

class ApprovalRequest(BaseModel):
    classification_id: int
    approved: bool
    manager_user_id: Optional[int] = None
    notes: Optional[str] = None

class PlacementRequest(BaseModel):
    classification_id: int
    shelf_location: str
    coordinator_user_id: Optional[int] = None

class PlacementResponse(BaseModel):
    placement_id: int
    style_number: str
    color: str
    shelf_location: str
    message: str

class SyncResponse(BaseModel):
    files: List[dict]
    styles: List[dict]
    placements: List[dict]
    sync_metadata: dict

class StatsResponse(BaseModel):
    total_styles: int
    showroom_count: int
    pending_approvals_count: int
    total_colors: int
    items_processed_today: int

class CVDetectionRequest(BaseModel):
    image_data: str
    
class CVDetectionResponse(BaseModel):
    detected_style_number: Optional[str] = None
    detected_color: Optional[str] = None
    confidence_score: float
    success: bool
    message: str

class HealthResponse(BaseModel):
    status: str
    timestamp: datetime
    database_status: Optional[str] = None
