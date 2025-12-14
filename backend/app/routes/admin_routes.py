from flask import Blueprint, request, jsonify
import logging
from app.core.database import SessionLocal
from app.services.database_service import get_statistics, log_audit_action
from app.models.database_models import RemovalTask
from datetime import datetime

logger = logging.getLogger(__name__)

admin_bp = Blueprint('admin', __name__, url_prefix='/api/admin')

@admin_bp.route('/stats', methods=['GET'])
def get_stats():
    """Get system statistics for dashboard."""
    try:
        db = SessionLocal()
        try:
            stats = get_statistics(db)
            return jsonify(stats), 200
        finally:
            db.close()
    
    except Exception as e:
        logger.exception(f"Error getting statistics: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@admin_bp.route('/removal-tasks', methods=['GET'])
def get_removal_tasks():
    """Get pending removal tasks."""
    try:
        db = SessionLocal()
        try:
            tasks = db.query(RemovalTask).filter(
                RemovalTask.completed == False
            ).order_by(RemovalTask.created_timestamp.desc()).all()
            
            return jsonify({
                'removal_tasks': [{
                    'task_id': t.id,
                    'style_number': t.style_number,
                    'color': t.color,
                    'shelf_location': t.shelf_location,
                    'reason': t.reason,
                    'created_timestamp': t.created_timestamp.isoformat()
                } for t in tasks]
            }), 200
        
        finally:
            db.close()
    
    except Exception as e:
        logger.exception(f"Error getting removal tasks: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@admin_bp.route('/removal-tasks/<int:task_id>/complete', methods=['PUT'])
def complete_removal_task(task_id):
    """Mark a removal task as completed."""
    try:
        db = SessionLocal()
        try:
            task = db.query(RemovalTask).filter(RemovalTask.id == task_id).first()
            
            if not task:
                return jsonify({'error': 'Task not found'}), 404
            
            task.completed = True
            task.completed_timestamp = datetime.utcnow()
            db.commit()
            
            log_audit_action(
                db,
                'removal_task_completed',
                affected_resources=f"Task ID: {task_id}",
                ip_address=request.remote_addr,
                details=f"Removal task completed: {task.style_number} - {task.color}"
            )
            
            return jsonify({
                'message': 'Removal task marked as completed',
                'task_id': task_id
            }), 200
        
        finally:
            db.close()
    
    except Exception as e:
        logger.exception(f"Error completing removal task: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@admin_bp.route('/config', methods=['GET', 'PUT'])
def system_config():
    """Get or update system configuration."""
    try:
        from app.core.config import settings
        
        if request.method == 'GET':
            return jsonify({
                'auto_drop_enabled': settings.AUTO_DROP_ENABLED,
                'default_sync_interval_seconds': settings.DEFAULT_SYNC_INTERVAL_SECONDS,
                'max_content_length': settings.MAX_CONTENT_LENGTH
            }), 200
        
        elif request.method == 'PUT':
            data = request.get_json()
            
            # Note: In production, you'd want to persist these changes
            # For now, this just returns the requested config
            return jsonify({
                'message': 'Configuration updated',
                'config': data
            }), 200
    
    except Exception as e:
        logger.exception(f"Error handling config: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500
