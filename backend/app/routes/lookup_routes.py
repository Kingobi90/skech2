from flask import Blueprint, request, jsonify
import logging
from app.core.database import SessionLocal
from app.services.database_service import lookup_style_color
from app.models.database_models import Style, Color
from sqlalchemy import func, or_

logger = logging.getLogger(__name__)

lookup_bp = Blueprint('lookup', __name__, url_prefix='/api/lookup')

@lookup_bp.route('/', methods=['GET'])
def lookup():
    """Lookup style and color in database."""
    try:
        style = request.args.get('style')
        color = request.args.get('color')
        
        if not style:
            return jsonify({'error': 'Style number is required'}), 400
        
        db = SessionLocal()
        try:
            result = lookup_style_color(db, style, color)
            return jsonify(result), 200
        finally:
            db.close()
    
    except Exception as e:
        logger.exception(f"Error in lookup: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@lookup_bp.route('/search', methods=['GET'])
def search():
    """Search styles by query string."""
    try:
        query = request.args.get('q', '')
        status_filter = request.args.get('status')
        division_filter = request.args.get('division')
        gender_filter = request.args.get('gender')
        page = int(request.args.get('page', 1))
        limit = int(request.args.get('limit', 50))
        
        if not query and not status_filter and not division_filter and not gender_filter:
            return jsonify({'error': 'At least one search parameter required'}), 400
        
        db = SessionLocal()
        try:
            # Build query
            styles_query = db.query(Style)
            
            if query:
                # Search in style number, division
                search_pattern = f"%{query}%"
                styles_query = styles_query.filter(
                    or_(
                        Style.style_number.ilike(search_pattern),
                        Style.division.ilike(search_pattern)
                    )
                )
            
            if division_filter:
                styles_query = styles_query.filter(Style.division == division_filter)
            
            if gender_filter:
                styles_query = styles_query.filter(Style.gender == gender_filter)
            
            # Get total count
            total_count = styles_query.count()
            
            # Paginate
            offset = (page - 1) * limit
            styles = styles_query.offset(offset).limit(limit).all()
            
            # Format results
            results = []
            for style in styles:
                colors = db.query(Color).filter(Color.style_id == style.id).all()
                results.append({
                    'style_number': style.style_number,
                    'division': style.division,
                    'gender': style.gender,
                    'outsole': style.outsole,
                    'colors': [c.color_name for c in colors]
                })
            
            return jsonify({
                'results': results,
                'total_count': total_count,
                'page': page,
                'limit': limit,
                'total_pages': (total_count + limit - 1) // limit
            }), 200
        
        finally:
            db.close()
    
    except Exception as e:
        logger.exception(f"Error in search: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500
