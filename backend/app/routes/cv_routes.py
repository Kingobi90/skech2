from flask import Blueprint, request, jsonify
import logging
from app.services.cv_processor import process_shoe_tag_image

logger = logging.getLogger(__name__)

cv_bp = Blueprint('cv', __name__, url_prefix='/api/cv')

@cv_bp.route('/detect', methods=['POST'])
def detect_tag():
    """Process shoe tag image and detect style number and color."""
    try:
        data = request.get_json()
        
        if not data or 'image_data' not in data:
            return jsonify({'error': 'image_data is required'}), 400
        
        # Process image
        result = process_shoe_tag_image(data['image_data'])
        
        return jsonify(result), 200
    
    except Exception as e:
        logger.exception(f"Error in CV detection: {str(e)}")
        return jsonify({
            'success': False,
            'message': 'Internal server error',
            'detected_style_number': None,
            'detected_color': None,
            'confidence_score': 0.0
        }), 500
