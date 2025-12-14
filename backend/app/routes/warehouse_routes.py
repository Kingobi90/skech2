from flask import Blueprint, request, jsonify
import logging
from app.core.database import SessionLocal
from app.models.database_models import WarehouseClassification
from app.services.database_service import (
    get_pending_classifications, approve_classification, create_placement
)
from datetime import datetime

logger = logging.getLogger(__name__)

warehouse_bp = Blueprint('warehouse', __name__, url_prefix='/api/warehouse')

@warehouse_bp.route('/classify', methods=['POST'])
def classify_item():
    """Create a new warehouse classification."""
    try:
        data = request.get_json()
        
        # Validate required fields
        if not data.get('style_number') or not data.get('color') or not data.get('status'):
            return jsonify({'error': 'style_number, color, and status are required'}), 400
        
        if data['status'] not in ['keep', 'wait', 'drop']:
            return jsonify({'error': 'status must be keep, wait, or drop'}), 400
        
        db = SessionLocal()
        try:
            classification = WarehouseClassification(
                style_number=data['style_number'],
                color=data['color'],
                status=data['status'],
                coordinator_user_id=data.get('coordinator_user_id'),
                coordinator_name=data.get('coordinator_name'),
                confidence_score=data.get('confidence_score'),
                notes=data.get('notes')
            )
            
            db.add(classification)
            db.commit()
            db.refresh(classification)
            
            return jsonify({
                'classification_id': classification.id,
                'style_number': classification.style_number,
                'color': classification.color,
                'status': classification.status,
                'message': 'Classification created successfully'
            }), 201
        
        finally:
            db.close()
    
    except Exception as e:
        logger.exception(f"Error creating classification: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@warehouse_bp.route('/pending', methods=['GET'])
def get_pending():
    """Get pending classifications for manager approval."""
    try:
        limit = int(request.args.get('limit', 100))
        
        db = SessionLocal()
        try:
            pending = get_pending_classifications(db, limit)
            return jsonify({'pending_classifications': pending}), 200
        finally:
            db.close()
    
    except Exception as e:
        logger.exception(f"Error getting pending classifications: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@warehouse_bp.route('/approve', methods=['POST'])
def approve():
    """Approve or reject a classification."""
    try:
        data = request.get_json()
        
        if not data.get('classification_id') or 'approved' not in data:
            return jsonify({'error': 'classification_id and approved are required'}), 400
        
        db = SessionLocal()
        try:
            result = approve_classification(
                db,
                data['classification_id'],
                data['approved'],
                data.get('manager_user_id'),
                data.get('notes')
            )
            
            return jsonify({
                'message': 'Classification approved successfully',
                **result
            }), 200
        
        except ValueError as e:
            return jsonify({'error': str(e)}), 404
        finally:
            db.close()
    
    except Exception as e:
        logger.exception(f"Error approving classification: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@warehouse_bp.route('/placement', methods=['POST'])
def create_placement_route():
    """Create a showroom placement for an approved item."""
    try:
        data = request.get_json()
        
        if not data.get('classification_id') or not data.get('shelf_location'):
            return jsonify({'error': 'classification_id and shelf_location are required'}), 400
        
        db = SessionLocal()
        try:
            result = create_placement(
                db,
                data['classification_id'],
                data['shelf_location'],
                data.get('coordinator_user_id')
            )
            
            return jsonify({
                'message': 'Placement created successfully',
                **result
            }), 201
        
        except ValueError as e:
            return jsonify({'error': str(e)}), 400
        finally:
            db.close()
    
    except Exception as e:
        logger.exception(f"Error creating placement: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@warehouse_bp.route('/placements', methods=['GET'])
def get_placements():
    """Get all showroom placements with optional filters."""
    try:
        from app.models.database_models import ShowroomPlacement
        
        style_filter = request.args.get('style_number')
        location_filter = request.args.get('shelf_location')
        page = int(request.args.get('page', 1))
        limit = int(request.args.get('limit', 50))
        
        db = SessionLocal()
        try:
            query = db.query(ShowroomPlacement).filter(ShowroomPlacement.is_active == True)
            
            if style_filter:
                query = query.filter(ShowroomPlacement.style_number.ilike(f"%{style_filter}%"))
            
            if location_filter:
                query = query.filter(ShowroomPlacement.shelf_location == location_filter)
            
            total_count = query.count()
            
            offset = (page - 1) * limit
            placements = query.order_by(ShowroomPlacement.placement_timestamp.desc()).offset(offset).limit(limit).all()
            
            return jsonify({
                'placements': [{
                    'id': p.id,
                    'style_number': p.style_number,
                    'color': p.color,
                    'shelf_location': p.shelf_location,
                    'placement_timestamp': p.placement_timestamp.isoformat()
                } for p in placements],
                'total_count': total_count,
                'page': page,
                'limit': limit
            }), 200
        
        finally:
            db.close()
    
    except Exception as e:
        logger.exception(f"Error getting placements: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500
