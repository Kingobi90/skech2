import json
import logging
from typing import List, Dict, Optional
from sqlalchemy import func, and_, or_
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from app.models.database_models import (
    Style, Color, File, WarehouseClassification, 
    ShowroomPlacement, RemovalTask, SyncLog, AuditLog
)

logger = logging.getLogger(__name__)

def save_excel_data(db: Session, file_id: int, extracted_data: List[Dict]) -> Dict:
    """Save extracted Excel data to database."""
    stats = {
        'styles_created': 0,
        'styles_updated': 0,
        'colors_created': 0
    }
    
    try:
        for style_data in extracted_data:
            style_number = style_data['style_number']
            
            # Check if style exists
            existing_style = db.query(Style).filter(
                func.lower(Style.style_number) == style_number.lower()
            ).first()
            
            if existing_style:
                # Update existing style
                existing_style.division = style_data.get('division') or existing_style.division
                existing_style.gender = style_data.get('gender') or existing_style.gender
                existing_style.outsole = style_data.get('outsole') or existing_style.outsole
                existing_style.updated_at = datetime.utcnow()
                
                # Update source files
                source_files = json.loads(existing_style.source_file_ids or '[]')
                if file_id not in source_files:
                    source_files.append(file_id)
                    existing_style.source_file_ids = json.dumps(source_files)
                
                stats['styles_updated'] += 1
                style_id = existing_style.id
            else:
                # Create new style
                new_style = Style(
                    style_number=style_number,
                    division=style_data.get('division'),
                    gender=style_data.get('gender'),
                    outsole=style_data.get('outsole'),
                    source_file_ids=json.dumps([file_id])
                )
                db.add(new_style)
                db.flush()
                stats['styles_created'] += 1
                style_id = new_style.id
            
            # Add colors
            for color_data in style_data.get('colors', []):
                # Handle both dict and string formats for backward compatibility
                if isinstance(color_data, dict):
                    color_name = color_data.get('color_name')
                    image_url = color_data.get('image_url')
                else:
                    color_name = color_data
                    image_url = None
                
                if not color_name:
                    continue
                
                # Check if color already exists
                existing_color = db.query(Color).filter(
                    and_(
                        Color.style_id == style_id,
                        func.lower(Color.color_name) == color_name.lower()
                    )
                ).first()
                
                if not existing_color:
                    new_color = Color(
                        style_id=style_id,
                        color_name=color_name,
                        image_url=image_url,
                        source_file_id=file_id
                    )
                    db.add(new_color)
                    stats['colors_created'] += 1
                else:
                    # Update image URL if provided and not already set
                    if image_url and not existing_color.image_url:
                        existing_color.image_url = image_url
        
        db.commit()
        logger.info(f"Saved Excel data: {stats}")
        return stats
        
    except Exception as e:
        db.rollback()
        logger.error(f"Error saving Excel data: {str(e)}")
        raise


def lookup_style_color(db: Session, style_number: str, color: Optional[str] = None) -> Dict:
    """
    Lookup style and color in database.
    
    Handles width and kids variations:
    - Scanned: 144083 → Matches: 144083, 144083W, 144083WW
    - Scanned: 144083L → Matches: 144083L only (kids shoe)
    - Scanned: 144083N → Matches: 144083N only (kids shoe)
    """
    # Normalize the scanned style number
    base_style = style_number
    is_kids = False
    
    # Check if it's a kids shoe (ends with L or N)
    if style_number and len(style_number) > 1:
        if style_number[-1] in ['L', 'N']:
            is_kids = True
            # For kids shoes, look for exact match
        else:
            # For regular shoes, strip any width suffix for lookup
            # This shouldn't happen from tags, but handle it just in case
            if style_number.endswith('WW'):
                base_style = style_number[:-2]
            elif style_number.endswith('W'):
                base_style = style_number[:-1]
    
    # Find style - exact match for kids, base match for regular
    style = db.query(Style).filter(
        func.lower(Style.style_number) == base_style.lower()
    ).first()
    
    if not style:
        return {
            'status': 'drop',
            'style_number': style_number,
            'message': 'Style number not found in database',
            'colors': [],
            'is_kids': is_kids
        }
    
    # Get all colors for this style with image URLs
    colors = db.query(Color).filter(Color.style_id == style.id).all()
    color_names = [c.color_name for c in colors]
    
    # Build color details with images
    color_details = {}
    for c in colors:
        color_details[c.color_name] = {
            'image_url': c.image_url
        }
    
    # Get source files with names
    source_file_ids = json.loads(style.source_file_ids or '[]')
    source_files = []
    for file_id in source_file_ids:
        file_record = db.query(File).filter(File.id == file_id).first()
        if file_record:
            source_files.append({
                'id': file_id,
                'filename': file_record.original_filename
            })
    
    result = {
        'style_number': style.style_number,
        'division': style.division,
        'gender': style.gender,
        'outsole': style.outsole,
        'colors': color_names,
        'color_details': color_details,
        'source_files': source_files,
        'is_kids': is_kids
    }
    
    if color:
        # Check if specific color exists
        color_match = any(c.lower() == color.lower() for c in color_names)
        if color_match:
            result['status'] = 'keep'
            result['message'] = 'Exact match found'
            result['color'] = color
            # Add image URL for the specific color
            for c in colors:
                if c.color_name.lower() == color.lower():
                    result['image_url'] = c.image_url
                    break
            if is_kids:
                result['message'] += ' (Kids shoe)'
        else:
            result['status'] = 'wait'
            result['message'] = 'Style exists but color not found'
            if is_kids:
                result['message'] += ' (Kids shoe)'
    else:
        result['status'] = 'keep'
        result['message'] = 'Style found'
        if is_kids:
            result['message'] += ' (Kids shoe)'
    
    return result


def get_pending_classifications(db: Session, limit: int = 100) -> List[Dict]:
    """Get pending warehouse classifications for manager approval."""
    classifications = db.query(WarehouseClassification).filter(
        WarehouseClassification.manager_approved == False
    ).order_by(
        WarehouseClassification.submission_timestamp.asc()
    ).limit(limit).all()
    
    results = []
    for classification in classifications:
        # Get style info
        style_info = lookup_style_color(db, classification.style_number, classification.color)
        
        results.append({
            'classification_id': classification.id,
            'style_number': classification.style_number,
            'color': classification.color,
            'coordinator_assigned_status': classification.status,
            'coordinator_name': classification.coordinator_name,
            'submission_timestamp': classification.submission_timestamp.isoformat(),
            'confidence_score': classification.confidence_score,
            'complete_style_info': style_info if style_info['status'] != 'drop' else None
        })
    
    return results


def approve_classification(db: Session, classification_id: int, approved: bool, 
                          manager_user_id: Optional[int] = None, notes: Optional[str] = None) -> Dict:
    """Approve or reject a warehouse classification."""
    classification = db.query(WarehouseClassification).filter(
        WarehouseClassification.id == classification_id
    ).first()
    
    if not classification:
        raise ValueError(f"Classification {classification_id} not found")
    
    classification.manager_approved = True
    classification.final_status = 'keep' if approved else 'drop'
    classification.approval_timestamp = datetime.utcnow()
    classification.manager_user_id = manager_user_id
    
    if notes:
        classification.notes = notes
    
    db.commit()
    
    return {
        'classification_id': classification_id,
        'final_status': classification.final_status,
        'approved': approved
    }


def create_placement(db: Session, classification_id: int, shelf_location: str,
                    coordinator_user_id: Optional[int] = None) -> Dict:
    """Create a showroom placement for an approved item."""
    classification = db.query(WarehouseClassification).filter(
        WarehouseClassification.id == classification_id
    ).first()
    
    if not classification:
        raise ValueError(f"Classification {classification_id} not found")
    
    if not classification.manager_approved:
        raise ValueError("Classification must be approved before placement")
    
    if classification.final_status != 'keep':
        raise ValueError("Only items with 'keep' status can be placed")
    
    # Create placement
    placement = ShowroomPlacement(
        style_number=classification.style_number,
        color=classification.color,
        shelf_location=shelf_location,
        coordinator_user_id=coordinator_user_id,
        classification_id=classification_id,
        is_active=True
    )
    
    db.add(placement)
    db.commit()
    
    return {
        'placement_id': placement.id,
        'style_number': placement.style_number,
        'color': placement.color,
        'shelf_location': placement.shelf_location
    }


def get_statistics(db: Session) -> Dict:
    """Get system statistics."""
    # Total styles
    total_styles = db.query(func.count(Style.id)).scalar()
    
    # Showroom count
    showroom_count = db.query(func.count(ShowroomPlacement.id)).filter(
        ShowroomPlacement.is_active == True
    ).scalar()
    
    # Pending approvals
    pending_approvals = db.query(func.count(WarehouseClassification.id)).filter(
        WarehouseClassification.manager_approved == False
    ).scalar()
    
    # Total colors
    total_colors = db.query(func.count(Color.id)).scalar()
    
    # Items processed today
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    items_today = db.query(func.count(WarehouseClassification.id)).filter(
        WarehouseClassification.submission_timestamp >= today_start
    ).scalar()
    
    return {
        'total_styles': total_styles or 0,
        'showroom_count': showroom_count or 0,
        'pending_approvals_count': pending_approvals or 0,
        'total_colors': total_colors or 0,
        'items_processed_today': items_today or 0
    }


def trigger_auto_drop(db: Session, file_id: int) -> List[Dict]:
    """Trigger auto-drop for styles that only have this file as source."""
    # Find styles where this is the only source file
    orphaned_styles = []
    
    all_styles = db.query(Style).all()
    for style in all_styles:
        source_files = json.loads(style.source_file_ids or '[]')
        if source_files == [file_id]:
            orphaned_styles.append(style)
    
    removal_tasks = []
    
    for style in orphaned_styles:
        # Find active placements for this style
        placements = db.query(ShowroomPlacement).filter(
            and_(
                ShowroomPlacement.style_number == style.style_number,
                ShowroomPlacement.is_active == True
            )
        ).all()
        
        for placement in placements:
            # Create removal task
            task = RemovalTask(
                style_number=placement.style_number,
                color=placement.color,
                shelf_location=placement.shelf_location,
                reason=f"Source file deleted (File ID: {file_id})"
            )
            db.add(task)
            removal_tasks.append({
                'style_number': task.style_number,
                'color': task.color,
                'shelf_location': task.shelf_location
            })
    
    db.commit()
    
    return removal_tasks


def log_audit_action(db: Session, action_type: str, admin_user_id: Optional[int] = None,
                    affected_resources: Optional[str] = None, ip_address: Optional[str] = None,
                    details: Optional[str] = None):
    """Log an audit action."""
    audit = AuditLog(
        admin_user_id=admin_user_id,
        action_type=action_type,
        affected_resources=affected_resources,
        ip_address=ip_address,
        details=details
    )
    db.add(audit)
    db.commit()
