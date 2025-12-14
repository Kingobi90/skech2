from flask import Blueprint, request, jsonify
from werkzeug.utils import secure_filename
import os
import uuid
import logging
from app.core.database import SessionLocal
from app.models.database_models import File
from app.services.excel_parser import parse_excel_file
from app.services.pdf_parser import parse_pdf_file
from app.services.database_service import save_excel_data, log_audit_action
from app.core.config import settings

logger = logging.getLogger(__name__)

files_bp = Blueprint('files', __name__, url_prefix='/api/files')

ALLOWED_EXTENSIONS = {'xlsx', 'xls', 'pdf'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@files_bp.route('/upload', methods=['POST'])
def upload_file():
    """Upload and parse Excel or PDF file."""
    try:
        # Check if file is present
        if 'file' not in request.files:
            return jsonify({'error': 'No file provided'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        
        # Get file type and category from form data
        file_type = request.form.get('file_type')
        category = request.form.get('category')
        
        if not file_type or file_type not in ['pdf', 'xlsx']:
            return jsonify({'error': 'Invalid file type'}), 400
        
        if not category or category not in ['all_bought', 'key_initiative']:
            return jsonify({'error': 'Invalid category'}), 400
        
        # Validate file
        if not allowed_file(file.filename):
            return jsonify({'error': 'File type not allowed'}), 400
        
        # Generate unique filename
        original_filename = secure_filename(file.filename)
        file_extension = original_filename.rsplit('.', 1)[1].lower()
        unique_filename = f"{uuid.uuid4()}.{file_extension}"
        
        # Ensure upload directory exists
        os.makedirs(settings.UPLOAD_FOLDER, exist_ok=True)
        
        # Save file
        file_path = os.path.join(settings.UPLOAD_FOLDER, unique_filename)
        file.save(file_path)
        
        # Create database record
        db = SessionLocal()
        try:
            file_record = File(
                filename=unique_filename,
                original_filename=original_filename,
                file_type=file_type,
                category=category,
                status='processing'
            )
            db.add(file_record)
            db.commit()
            db.refresh(file_record)
            file_id = file_record.id
            
            # Parse file based on type
            if file_type == 'xlsx':
                parse_result = parse_excel_file(file_path)
                
                if parse_result['success']:
                    # Save to database
                    save_stats = save_excel_data(db, file_id, parse_result['extracted_data'])
                    
                    # Update file record
                    from datetime import datetime
                    file_record.parsed_at = datetime.utcnow()
                    file_record.row_count = parse_result['total_rows_processed']
                    file_record.status = 'success'
                    db.commit()
                    
                    # Log audit action
                    log_audit_action(
                        db, 
                        'file_uploaded',
                        affected_resources=f"File ID: {file_id}",
                        ip_address=request.remote_addr,
                        details=f"Excel file uploaded: {original_filename}"
                    )
                    
                    return jsonify({
                        'file_id': file_id,
                        'filename': original_filename,
                        'file_type': file_type,
                        'category': category,
                        'parsing_summary': {
                            'total_rows_processed': parse_result['total_rows_processed'],
                            'total_styles_found': parse_result['total_styles_found'],
                            'total_colors_found': parse_result['total_colors_found'],
                            'styles_created': save_stats['styles_created'],
                            'styles_updated': save_stats['styles_updated'],
                            'colors_created': save_stats['colors_created']
                        },
                        'warnings': parse_result['warnings']
                    }), 201
                else:
                    file_record.status = 'failed'
                    db.commit()
                    return jsonify({
                        'error': 'Failed to parse Excel file',
                        'details': parse_result['errors']
                    }), 400
            
            elif file_type == 'pdf':
                parse_result = parse_pdf_file(file_path)
                
                if parse_result['success']:
                    from datetime import datetime
                    file_record.parsed_at = datetime.utcnow()
                    file_record.row_count = len(parse_result['detected_style_numbers'])
                    file_record.status = 'success'
                    db.commit()
                    
                    log_audit_action(
                        db,
                        'file_uploaded',
                        affected_resources=f"File ID: {file_id}",
                        ip_address=request.remote_addr,
                        details=f"PDF file uploaded: {original_filename}"
                    )
                    
                    return jsonify({
                        'file_id': file_id,
                        'filename': original_filename,
                        'file_type': file_type,
                        'category': category,
                        'parsing_summary': {
                            'page_count': parse_result['page_count'],
                            'style_numbers_detected': len(parse_result['detected_style_numbers']),
                            'style_numbers': parse_result['detected_style_numbers']
                        },
                        'warnings': []
                    }), 201
                else:
                    file_record.status = 'failed'
                    db.commit()
                    return jsonify({
                        'error': 'Failed to parse PDF file',
                        'details': parse_result['error']
                    }), 400
        
        finally:
            db.close()
    
    except Exception as e:
        logger.exception(f"Error uploading file: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@files_bp.route('/', methods=['GET'])
def list_files():
    """List all uploaded files."""
    try:
        db = SessionLocal()
        try:
            files = db.query(File).filter(File.is_active == True).order_by(File.upload_date.desc()).all()
            
            return jsonify({
                'files': [{
                    'id': f.id,
                    'filename': f.original_filename,
                    'file_type': f.file_type,
                    'category': f.category,
                    'upload_date': f.upload_date.isoformat(),
                    'status': f.status,
                    'row_count': f.row_count
                } for f in files]
            }), 200
        finally:
            db.close()
    except Exception as e:
        logger.exception(f"Error listing files: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@files_bp.route('/<int:file_id>', methods=['DELETE'])
def delete_file(file_id):
    """Delete a file and optionally trigger auto-drop."""
    try:
        db = SessionLocal()
        try:
            file_record = db.query(File).filter(File.id == file_id).first()
            
            if not file_record:
                return jsonify({'error': 'File not found'}), 404
            
            # Mark as inactive
            file_record.is_active = False
            db.commit()
            
            # Trigger auto-drop if enabled
            removal_tasks = []
            if settings.AUTO_DROP_ENABLED:
                from app.services.database_service import trigger_auto_drop
                removal_tasks = trigger_auto_drop(db, file_id)
            
            # Log audit action
            log_audit_action(
                db,
                'file_deleted',
                affected_resources=f"File ID: {file_id}",
                ip_address=request.remote_addr,
                details=f"File deleted: {file_record.original_filename}, Removal tasks: {len(removal_tasks)}"
            )
            
            return jsonify({
                'message': 'File deleted successfully',
                'removal_tasks_created': len(removal_tasks),
                'removal_tasks': removal_tasks
            }), 200
        
        finally:
            db.close()
    
    except Exception as e:
        logger.exception(f"Error deleting file: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500
