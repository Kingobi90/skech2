from flask import Flask, jsonify
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import logging
from datetime import datetime
import os

from app.core.config import settings
from app.core.database import init_db, close_db
from app.routes.files_routes import files_bp
from app.routes.lookup_routes import lookup_bp
from app.routes.warehouse_routes import warehouse_bp
from app.routes.sync_routes import sync_bp
from app.routes.cv_routes import cv_bp
from app.routes.admin_routes import admin_bp

# Configure logging
logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create Flask app
app = Flask(__name__)
app.config['SECRET_KEY'] = settings.SECRET_KEY
app.config['MAX_CONTENT_LENGTH'] = settings.MAX_CONTENT_LENGTH
app.config['JSON_SORT_KEYS'] = False

# Configure CORS
CORS(app, resources={
    r"/api/*": {
        "origins": "*",
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"]
    }
})

# Configure rate limiting
limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per hour"],
    storage_uri="memory://"
)

# Apply rate limiting to file upload endpoint
limiter.limit("10 per hour")(files_bp)

# Register blueprints
app.register_blueprint(files_bp)
app.register_blueprint(lookup_bp)
app.register_blueprint(warehouse_bp)
app.register_blueprint(sync_bp)
app.register_blueprint(cv_bp)
app.register_blueprint(admin_bp)

# Health check endpoint
@app.route('/health', methods=['GET'])
@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint for monitoring."""
    try:
        from app.core.database import SessionLocal
        db = SessionLocal()
        db.execute('SELECT 1')
        db.close()
        database_status = 'healthy'
    except Exception as e:
        logger.error(f"Database health check failed: {str(e)}")
        database_status = 'unhealthy'
    
    return jsonify({
        'status': 'healthy' if database_status == 'healthy' else 'degraded',
        'timestamp': datetime.utcnow().isoformat(),
        'database_status': database_status
    }), 200 if database_status == 'healthy' else 503


# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({
        'error': 'Not found',
        'message': 'The requested resource was not found'
    }), 404


@app.errorhandler(500)
def internal_error(error):
    logger.exception("Internal server error")
    return jsonify({
        'error': 'Internal server error',
        'message': 'An unexpected error occurred'
    }), 500


@app.errorhandler(413)
def request_entity_too_large(error):
    return jsonify({
        'error': 'File too large',
        'message': 'The uploaded file exceeds the maximum allowed size'
    }), 413


# Request logging middleware
@app.before_request
def log_request():
    from flask import request
    logger.info(f"{request.method} {request.path} from {request.remote_addr}")


@app.after_request
def log_response(response):
    from flask import request
    logger.info(f"{request.method} {request.path} - {response.status_code}")
    return response


# Initialize database on startup
def initialize():
    """Initialize application on startup."""
    logger.info("Initializing application...")
    
    # Create upload directory
    os.makedirs(settings.UPLOAD_FOLDER, exist_ok=True)
    logger.info(f"Upload folder: {settings.UPLOAD_FOLDER}")
    
    # Initialize database
    try:
        init_db()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize database: {str(e)}")


# Cleanup on shutdown
@app.teardown_appcontext
def shutdown_session(exception=None):
    close_db()


if __name__ == '__main__':
    # Initialize on startup
    initialize()
    
    port = int(os.getenv('PORT', 5001))
    app.run(host='0.0.0.0', port=port, debug=settings.DEBUG)
