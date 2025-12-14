import os
from pydantic_settings import BaseSettings
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

class Settings(BaseSettings):
    DATABASE_URL: str = os.getenv('DATABASE_URL', 'postgresql://localhost/skechers_inventory')
    SECRET_KEY: str = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')
    DEBUG: bool = os.getenv('DEBUG', 'False').lower() == 'true'
    FLASK_ENV: str = os.getenv('FLASK_ENV', 'production')
    MAX_CONTENT_LENGTH: int = int(os.getenv('MAX_CONTENT_LENGTH', 52428800))
    UPLOAD_FOLDER: str = os.getenv('UPLOAD_FOLDER', './uploads')
    TESSERACT_PATH: Optional[str] = os.getenv('TESSERACT_PATH', None)
    AUTO_DROP_ENABLED: bool = os.getenv('AUTO_DROP_ENABLED', 'True').lower() == 'true'
    DEFAULT_SYNC_INTERVAL_SECONDS: int = int(os.getenv('DEFAULT_SYNC_INTERVAL_SECONDS', 60))
    
    class Config:
        case_sensitive = True

settings = Settings()
