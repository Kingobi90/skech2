import pdfplumber
import logging
import re
from pathlib import Path
from typing import Dict, List

logger = logging.getLogger(__name__)

def parse_pdf_file(file_path: str or Path) -> Dict:
    """
    Parse PDF file to extract style numbers and product information.
    
    Args:
        file_path: Path to PDF file
        
    Returns:
        Dictionary with parsing results
    """
    result = {
        'success': False,
        'page_count': 0,
        'detected_style_numbers': [],
        'error': None
    }
    
    try:
        with pdfplumber.open(file_path) as pdf:
            result['page_count'] = len(pdf.pages)
            style_numbers = set()
            
            for page_num, page in enumerate(pdf.pages, 1):
                text = page.extract_text()
                
                if not text:
                    logger.warning(f"No text found on page {page_num}")
                    continue
                
                # Pattern 1: 6-7 digit style numbers
                matches = re.findall(r'\b(\d{6,7})\b', text)
                for match in matches:
                    style_numbers.add(match)
                
                # Pattern 2: Style numbers with prefix (e.g., "Style: 123456")
                matches = re.findall(r'(?:Style|SKU|Item)[:\s]+(\d{6,7})', text, re.IGNORECASE)
                for match in matches:
                    style_numbers.add(match)
                
                # Extract tables if present
                tables = page.extract_tables()
                for table in tables:
                    for row in table:
                        if not row:
                            continue
                        for cell in row:
                            if cell and isinstance(cell, str):
                                # Look for style numbers in cells
                                cell_matches = re.findall(r'\b(\d{6,7})\b', cell)
                                for match in cell_matches:
                                    style_numbers.add(match)
            
            result['detected_style_numbers'] = sorted(list(style_numbers))
            result['success'] = True
            
            logger.info(f"PDF parsing complete: {len(result['detected_style_numbers'])} unique style numbers found across {result['page_count']} pages")
            
    except Exception as e:
        logger.error(f"Error parsing PDF: {str(e)}")
        result['error'] = str(e)
        result['success'] = False
    
    return result
