import cv2
import numpy as np
import pytesseract
import base64
import logging
import re
from typing import Dict, Optional, Tuple
from PIL import Image
import io

logger = logging.getLogger(__name__)

# Common color names and codes to detect
COMMON_COLORS = [
    'black', 'white', 'navy', 'navy blue', 'grey', 'gray', 'red', 'blue', 
    'green', 'yellow', 'brown', 'tan', 'pink', 'purple', 'orange', 'beige',
    'charcoal', 'olive', 'burgundy', 'maroon', 'teal', 'turquoise', 'silver',
    'gold', 'bronze', 'cream', 'ivory', 'khaki', 'lime', 'mint', 'coral',
    'lavender', 'peach', 'rose', 'taupe', 'slate', 'natural', 'nat'
]

# Skechers color code mappings (from shoe tags)
COLOR_CODE_MAP = {
    'BLK': 'Black',
    'BBK': 'Black',
    'WHT': 'White',
    'NAT': 'Natural',
    'OLV': 'Olive',
    'NVY': 'Navy',
    'GRY': 'Grey',
    'RED': 'Red',
    'BLU': 'Blue',
    'GRN': 'Green',
    'PNK': 'Pink',
    'BRN': 'Brown',
    'TAN': 'Tan',
    'GLD': 'Gold',
    'SLV': 'Silver'
}

def process_shoe_tag_image(image_data: str) -> Dict:
    """
    Process shoe tag image to detect style number and color.
    
    Args:
        image_data: Base64 encoded image data
        
    Returns:
        Dictionary containing detected information and confidence score
    """
    result = {
        'detected_style_number': None,
        'detected_color': None,
        'confidence_score': 0.0,
        'success': False,
        'message': ''
    }
    
    try:
        # Decode base64 image
        image = decode_base64_image(image_data)
        if image is None:
            result['message'] = 'Failed to decode image data'
            return result
        
        # Preprocess image
        processed_image = preprocess_image(image)
        
        # Extract text using OCR
        ocr_result = extract_text_with_confidence(processed_image)
        
        if not ocr_result['text']:
            result['message'] = 'No text detected in image'
            return result
        
        # Detect style number
        style_number, style_confidence = detect_style_number(
            ocr_result['text'], 
            ocr_result['confidences']
        )
        
        # Detect color
        color_name, color_confidence = detect_color_name(
            ocr_result['text'],
            ocr_result['confidences']
        )
        
        # Calculate overall confidence
        confidences = []
        if style_confidence > 0:
            confidences.append(style_confidence)
        if color_confidence > 0:
            confidences.append(color_confidence)
        
        overall_confidence = sum(confidences) / len(confidences) if confidences else 0
        
        result['detected_style_number'] = style_number
        result['detected_color'] = color_name
        result['confidence_score'] = round(overall_confidence, 2)
        
        if style_number and color_name:
            result['success'] = True
            result['message'] = 'Successfully detected style and color'
        elif style_number:
            result['success'] = True
            result['message'] = 'Detected style number only'
        elif color_name:
            result['success'] = True
            result['message'] = 'Detected color only'
        else:
            result['message'] = 'Could not detect style number or color'
        
        logger.info(f"CV Processing: Style={style_number}, Color={color_name}, "
                   f"Confidence={overall_confidence:.2f}")
        
    except Exception as e:
        error_msg = f"Error processing image: {str(e)}"
        logger.exception(error_msg)
        result['message'] = error_msg
    
    return result


def decode_base64_image(image_data: str) -> Optional[np.ndarray]:
    """Decode base64 image data to OpenCV format."""
    try:
        # Remove data URL prefix if present
        if ',' in image_data:
            image_data = image_data.split(',')[1]
        
        # Decode base64
        image_bytes = base64.b64decode(image_data)
        
        # Convert to PIL Image
        pil_image = Image.open(io.BytesIO(image_bytes))
        
        # Convert to OpenCV format
        opencv_image = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
        
        return opencv_image
    except Exception as e:
        logger.error(f"Error decoding base64 image: {str(e)}")
        return None


def preprocess_image(image: np.ndarray) -> np.ndarray:
    """
    Preprocess image for better OCR accuracy.
    
    Args:
        image: OpenCV image array
        
    Returns:
        Preprocessed image
    """
    # Resize if too large
    max_dimension = 2000
    height, width = image.shape[:2]
    if max(height, width) > max_dimension:
        scale = max_dimension / max(height, width)
        new_width = int(width * scale)
        new_height = int(height * scale)
        image = cv2.resize(image, (new_width, new_height))
    
    # Convert to grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    
    # Apply adaptive thresholding
    binary = cv2.adaptiveThreshold(
        gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
        cv2.THRESH_BINARY, 11, 2
    )
    
    # Denoise
    denoised = cv2.fastNlMeansDenoising(binary, None, 10, 7, 21)
    
    return denoised


def extract_text_with_confidence(image: np.ndarray) -> Dict:
    """
    Extract text from image with confidence scores.
    
    Args:
        image: Preprocessed image
        
    Returns:
        Dictionary with text and confidence information
    """
    try:
        # Get detailed OCR data
        ocr_data = pytesseract.image_to_data(
            image, 
            output_type=pytesseract.Output.DICT
        )
        
        # Extract text and confidences
        texts = []
        confidences = []
        
        for i, text in enumerate(ocr_data['text']):
            conf = int(ocr_data['conf'][i])
            if conf > 0 and text.strip():
                texts.append(text.strip())
                confidences.append(conf)
        
        full_text = ' '.join(texts)
        
        return {
            'text': full_text,
            'texts': texts,
            'confidences': confidences
        }
    except Exception as e:
        logger.error(f"OCR extraction error: {str(e)}")
        return {'text': '', 'texts': [], 'confidences': []}


def detect_style_number(text: str, confidences: list) -> Tuple[Optional[str], float]:
    """
    Detect style number from OCR text.
    Optimized for Skechers shoe tags with SN/RN field.
    
    Handles variations:
    - Base style: 144083
    - Kids shoes: 144083L, 144083N (keep suffix)
    - Width variants: 144083W, 144083WW (tags show base number only)
    
    Args:
        text: Extracted text
        confidences: Confidence scores for each word
        
    Returns:
        Tuple of (style_number, confidence)
    """
    # Pattern 1: SN/RN prefix with optional kids suffix (e.g., SN144844, SN144083L, SN144083N)
    pattern_sn = r'SN/?RN[:\s]*(\d{5,7}[LN]?)'
    matches_sn = re.findall(pattern_sn, text.upper())
    
    # Pattern 2: Standalone 6-7 digit numbers with optional kids suffix
    pattern_digits = r'\b(\d{6,7}[LN]?)\b'
    matches_digits = re.findall(pattern_digits, text)
    
    # Pattern 3: Style numbers with SN prefix and optional kids suffix
    pattern_sn_only = r'\bSN\s*(\d{6,7}[LN]?)\b'
    matches_sn_only = re.findall(pattern_sn_only, text.upper())
    
    # Pattern 4: Last field format (e.g., YIHPD3453W, KPL18897W)
    pattern_last = r'\b([A-Z]{3,6}\d{4,5}[A-Z]{0,2})\b'
    matches_last = re.findall(pattern_last, text.upper())
    
    # Prioritize matches
    all_matches = matches_sn_only or matches_sn or matches_digits or matches_last
    
    if all_matches:
        # Return first match with average confidence
        avg_confidence = sum(confidences) / len(confidences) if confidences else 50
        return all_matches[0], avg_confidence
    
    return None, 0.0


def detect_color_name(text: str, confidences: list) -> Tuple[Optional[str], float]:
    """
    Detect color name from OCR text.
    Optimized for Skechers shoe tags with Color/CLR Code field.
    
    Args:
        text: Extracted text
        confidences: Confidence scores for each word
        
    Returns:
        Tuple of (color_name, confidence)
    """
    text_upper = text.upper()
    text_lower = text.lower()
    
    # Pattern 1: Color code field (e.g., "Color: BLK", "CLR Code BLK")
    pattern_color_code = r'(?:COLOR|CLR)[:\s]+([A-Z]{3})\b'
    matches_code = re.findall(pattern_color_code, text_upper)
    
    if matches_code:
        color_code = matches_code[0]
        if color_code in COLOR_CODE_MAP:
            avg_confidence = sum(confidences) / len(confidences) if confidences else 70
            return COLOR_CODE_MAP[color_code], avg_confidence
    
    # Pattern 2: Standalone 3-letter color codes
    pattern_standalone = r'\b([A-Z]{3})\b'
    matches_standalone = re.findall(pattern_standalone, text_upper)
    
    for code in matches_standalone:
        if code in COLOR_CODE_MAP:
            avg_confidence = sum(confidences) / len(confidences) if confidences else 60
            return COLOR_CODE_MAP[code], avg_confidence
    
    # Pattern 3: Full color names
    for color in COMMON_COLORS:
        if color in text_lower:
            color_words = color.split()
            word_confidences = []
            
            for word in color_words:
                if word in text_lower:
                    avg_conf = sum(confidences) / len(confidences) if confidences else 50
                    word_confidences.append(avg_conf)
            
            avg_confidence = sum(word_confidences) / len(word_confidences) if word_confidences else 50
            return color.title(), avg_confidence
    
    return None, 0.0


def process_image_from_file(file_path: str) -> Dict:
    """
    Process shoe tag image from file path.
    
    Args:
        file_path: Path to image file
        
    Returns:
        Dictionary containing detected information
    """
    try:
        # Read image
        image = cv2.imread(file_path)
        if image is None:
            return {
                'success': False,
                'message': 'Failed to read image file'
            }
        
        # Preprocess and extract
        processed = preprocess_image(image)
        ocr_result = extract_text_with_confidence(processed)
        
        style_number, style_conf = detect_style_number(
            ocr_result['text'],
            ocr_result['confidences']
        )
        
        color_name, color_conf = detect_color_name(
            ocr_result['text'],
            ocr_result['confidences']
        )
        
        confidences = [c for c in [style_conf, color_conf] if c > 0]
        overall_confidence = sum(confidences) / len(confidences) if confidences else 0
        
        return {
            'detected_style_number': style_number,
            'detected_color': color_name,
            'confidence_score': round(overall_confidence, 2),
            'success': bool(style_number or color_name),
            'message': 'Processing complete'
        }
    except Exception as e:
        logger.exception(f"Error processing image file: {str(e)}")
        return {
            'success': False,
            'message': str(e)
        }
