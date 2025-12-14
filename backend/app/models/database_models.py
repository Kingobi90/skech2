from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, Float, Index
from sqlalchemy.orm import relationship, declarative_base
from datetime import datetime

Base = declarative_base()

class File(Base):
    __tablename__ = 'files'
    
    id = Column(Integer, primary_key=True)
    filename = Column(String(255), nullable=False)
    original_filename = Column(String(255), nullable=False)
    file_type = Column(String(10), nullable=False)
    category = Column(String(50), nullable=False)
    upload_date = Column(DateTime, default=datetime.utcnow)
    parsed_at = Column(DateTime, nullable=True)
    row_count = Column(Integer, nullable=True)
    status = Column(String(20), default='pending')
    is_active = Column(Boolean, default=True)
    
    __table_args__ = (
        Index('idx_files_active', 'is_active'),
        Index('idx_files_type', 'file_type'),
    )

class Style(Base):
    __tablename__ = 'styles'
    
    id = Column(Integer, primary_key=True)
    style_number = Column(String(50), unique=True, nullable=False)
    division = Column(String(100), nullable=True)
    outsole = Column(String(100), nullable=True)
    gender = Column(String(20), nullable=True)
    source_file_ids = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    colors = relationship('Color', back_populates='style', cascade='all, delete-orphan')
    
    __table_args__ = (
        Index('idx_styles_number', 'style_number'),
    )

class Color(Base):
    __tablename__ = 'colors'
    
    id = Column(Integer, primary_key=True)
    style_id = Column(Integer, ForeignKey('styles.id', ondelete='CASCADE'), nullable=False)
    color_name = Column(String(100), nullable=False)
    image_url = Column(String(500), nullable=True)
    source_file_id = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    style = relationship('Style', back_populates='colors')
    
    __table_args__ = (
        Index('idx_colors_style_id', 'style_id'),
        Index('idx_colors_style_color', 'style_id', 'color_name'),
    )

class WarehouseClassification(Base):
    __tablename__ = 'warehouse_classifications'
    
    id = Column(Integer, primary_key=True)
    style_number = Column(String(50), nullable=False)
    color = Column(String(100), nullable=False)
    status = Column(String(20), nullable=False)
    coordinator_user_id = Column(Integer, nullable=True)
    coordinator_name = Column(String(100), nullable=True)
    manager_approved = Column(Boolean, default=False)
    final_status = Column(String(20), nullable=True)
    submission_timestamp = Column(DateTime, default=datetime.utcnow)
    approval_timestamp = Column(DateTime, nullable=True)
    manager_user_id = Column(Integer, nullable=True)
    notes = Column(Text, nullable=True)
    confidence_score = Column(Float, nullable=True)
    
    __table_args__ = (
        Index('idx_warehouse_approved', 'manager_approved'),
        Index('idx_warehouse_status', 'status'),
        Index('idx_warehouse_submission', 'submission_timestamp'),
    )

class ShowroomPlacement(Base):
    __tablename__ = 'showroom_placements'
    
    id = Column(Integer, primary_key=True)
    style_number = Column(String(50), nullable=False)
    color = Column(String(100), nullable=False)
    shelf_location = Column(String(20), nullable=True)
    coordinator_user_id = Column(Integer, nullable=True)
    placement_timestamp = Column(DateTime, default=datetime.utcnow)
    classification_id = Column(Integer, ForeignKey('warehouse_classifications.id'), nullable=True)
    is_active = Column(Boolean, default=True)
    
    __table_args__ = (
        Index('idx_placements_style', 'style_number'),
        Index('idx_placements_location', 'shelf_location'),
        Index('idx_placements_active', 'is_active'),
    )

class RemovalTask(Base):
    __tablename__ = 'removal_tasks'
    
    id = Column(Integer, primary_key=True)
    style_number = Column(String(50), nullable=False)
    color = Column(String(100), nullable=False)
    shelf_location = Column(String(20), nullable=True)
    reason = Column(Text, nullable=False)
    created_timestamp = Column(DateTime, default=datetime.utcnow)
    completed = Column(Boolean, default=False)
    completed_timestamp = Column(DateTime, nullable=True)
    
    __table_args__ = (
        Index('idx_removal_completed', 'completed'),
    )

class SyncLog(Base):
    __tablename__ = 'sync_log'
    
    id = Column(Integer, primary_key=True)
    device_id = Column(String(100), nullable=False)
    last_sync_timestamp = Column(DateTime, default=datetime.utcnow)
    sync_status = Column(String(20), nullable=False)
    sync_type = Column(String(20), nullable=True)
    records_synced = Column(Integer, nullable=True)
    
    __table_args__ = (
        Index('idx_sync_device', 'device_id'),
        Index('idx_sync_timestamp', 'last_sync_timestamp'),
    )

class AuditLog(Base):
    __tablename__ = 'audit_log'
    
    id = Column(Integer, primary_key=True)
    admin_user_id = Column(Integer, nullable=True)
    action_type = Column(String(50), nullable=False)
    affected_resources = Column(Text, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)
    ip_address = Column(String(50), nullable=True)
    details = Column(Text, nullable=True)
    
    __table_args__ = (
        Index('idx_audit_timestamp', 'timestamp'),
        Index('idx_audit_action', 'action_type'),
    )
