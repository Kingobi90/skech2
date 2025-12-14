import pandas as pd
import logging
import re
from typing import Dict, List, Optional, Tuple
from openpyxl.utils.exceptions import InvalidFileException

logger = logging.getLogger(__name__)

def identify_column_type(column_name: str, sample_values: List) -> Optional[str]:
    """
    Identify what type of data a column contains based on its name and sample values.
    Returns: 'style', 'color', 'gender', 'division', 'outsole', or None
    """
    col_lower = str(column_name).lower().strip()
    
    # Filter out NaN values
    valid_samples = [str(v).strip() for v in sample_values if pd.notna(v) and str(v).strip()]
    if not valid_samples:
        return None
    
    # Check for style number column
    # Style: 6-7 digits, optionally ending with L, N, W, or WW
    if any(keyword in col_lower for keyword in ['style', 'style number', 'style_number']):
        # Validate with sample data
        style_pattern = r'^\d{6,7}(?:[LN]|WW?)?$'
        matches = sum(1 for v in valid_samples[:10] if re.match(style_pattern, v))
        if matches >= len(valid_samples[:10]) * 0.7:  # 70% match rate
            return 'style'
    
    # Check for color column
    # Color: 3-4 uppercase letters
    if any(keyword in col_lower for keyword in ['color', 'colour', 'clr']):
        color_pattern = r'^[A-Z]{3,4}$'
        matches = sum(1 for v in valid_samples[:10] if re.match(color_pattern, v.upper()))
        if matches >= len(valid_samples[:10]) * 0.7:
            return 'color'
    
    # Check for gender column
    # Gender: contains "women", "men", "womens", "mens", "unisex", "kids"
    if any(keyword in col_lower for keyword in ['gender', 'sex']):
        gender_keywords = ['women', 'men', 'womens', 'mens', 'unisex', 'kids', 'male', 'female']
        matches = sum(1 for v in valid_samples[:10] 
                     if any(kw in v.lower() for kw in gender_keywords))
        if matches >= len(valid_samples[:10]) * 0.7:
            return 'gender'
    
    # Check for division column
    if any(keyword in col_lower for keyword in ['division', 'div', 'category']):
        return 'division'
    
    # Check for outsole column
    if any(keyword in col_lower for keyword in ['outsole', 'sole', 'bottom']):
        return 'outsole'
    
    # Fallback: analyze content patterns without relying on column name
    # Style number pattern
    style_pattern = r'^\d{6,7}(?:[LN]|WW?)?$'
    style_matches = sum(1 for v in valid_samples[:10] if re.match(style_pattern, v))
    if style_matches >= len(valid_samples[:10]) * 0.8:
        return 'style'
    
    # Color code pattern
    color_pattern = r'^[A-Z]{3,4}$'
    color_matches = sum(1 for v in valid_samples[:10] if re.match(color_pattern, v.upper()))
    if color_matches >= len(valid_samples[:10]) * 0.8:
        return 'color'
    
    # Gender pattern
    gender_keywords = ['women', 'men', 'womens', 'mens', 'unisex', 'kids']
    gender_matches = sum(1 for v in valid_samples[:10] 
                        if any(kw in v.lower() for kw in gender_keywords))
    if gender_matches >= len(valid_samples[:10]) * 0.8:
        return 'gender'
    
    return None

def validate_style_number(value: str) -> bool:
    """Validate that a value matches style number pattern: 6-7 digits + optional L/N/W/WW"""
    if not value or pd.isna(value):
        return False
    value_str = str(value).strip()
    return bool(re.match(r'^\d{6,7}(?:[LN]|WW?)?$', value_str))

def validate_color_code(value: str) -> bool:
    """Validate that a value matches color code pattern: 3-4 uppercase letters"""
    if not value or pd.isna(value):
        return False
    value_str = str(value).strip().upper()
    return bool(re.match(r'^[A-Z]{3,4}$', value_str))

def validate_gender(value: str) -> bool:
    """Validate that a value contains gender keywords"""
    if not value or pd.isna(value):
        return False
    value_lower = str(value).lower()
    gender_keywords = ['women', 'men', 'womens', 'mens', 'unisex', 'kids', 'male', 'female']
    return any(kw in value_lower for kw in gender_keywords)

def parse_excel_file(file_path: str) -> Dict:
    """
    Parse Excel file and extract style and color information.
    Uses intelligent column detection based on data patterns, not hardcoded positions.
    
    Args:
        file_path: Path to the Excel file
        
    Returns:
        Dictionary containing parsing results with success status, data, and errors
    """
    result = {
        'success': False,
        'total_rows_processed': 0,
        'total_styles_found': 0,
        'total_colors_found': 0,
        'errors': [],
        'warnings': [],
        'extracted_data': []
    }
    
    try:
        # Load all sheets from Excel file
        logger.info(f"Loading Excel file: {file_path}")
        excel_data = pd.read_excel(file_path, sheet_name=None, engine='openpyxl')
        
        all_styles = {}
        
        # Process each sheet
        for sheet_name, df in excel_data.items():
            logger.info(f"Processing sheet: {sheet_name}")
            
            # Skip empty sheets
            if df.empty:
                logger.warning(f"Sheet '{sheet_name}' is empty, skipping")
                continue
            
            # Identify column types by analyzing column names and sample data
            column_mapping = {}
            for col in df.columns:
                sample_values = df[col].head(20).tolist()  # Use first 20 rows as sample
                col_type = identify_column_type(col, sample_values)
                if col_type:
                    column_mapping[col_type] = col
                    logger.info(f"Identified column '{col}' as '{col_type}'")
            
            # Check if we have a SKU column (style_color format)
            sku_column = None
            for col in df.columns:
                if 'sku' in str(col).lower():
                    # Check if values match SKU pattern (style_color)
                    sample_values = df[col].head(10).tolist()
                    valid_samples = [v for v in sample_values if pd.notna(v)]
                    if valid_samples:
                        sku_matches = sum(1 for v in valid_samples if '_' in str(v))
                        # At least 50% of samples should be SKU format, minimum 1
                        if sku_matches >= max(1, len(valid_samples) * 0.5):
                            sku_column = col
                            logger.info(f"Found SKU column: {col}")
                            break
            
            # Verify we found required columns or SKU column
            if 'style' not in column_mapping and not sku_column:
                result['warnings'].append(
                    f"Sheet '{sheet_name}': Could not identify style number column or SKU column. "
                    f"Looking for 6-7 digit numbers with optional L/N/W/WW suffix or SKU format (style_color)."
                )
                continue
            
            if 'color' not in column_mapping and not sku_column:
                result['warnings'].append(
                    f"Sheet '{sheet_name}': Could not identify color column or SKU column. "
                    f"Looking for 3-4 letter codes or SKU format (style_color)."
                )
                continue
            
            logger.info(f"Column mapping for '{sheet_name}': {column_mapping}")
            
            # Convert DataFrame to list of dictionaries
            rows = df.to_dict('records')
            
            for idx, row in enumerate(rows):
                result['total_rows_processed'] += 1
                
                # Extract style number and color
                style_number = None
                color_name = None
                sku_extracted_color = None
                
                # Try SKU column first for style number (and optionally color)
                if sku_column and sku_column in row and pd.notna(row[sku_column]):
                    sku_value = str(row[sku_column]).strip()
                    if '_' in sku_value:
                        parts = sku_value.split('_')
                        if len(parts) == 2:
                            potential_style = parts[0].strip()
                            potential_color = parts[1].strip().upper()
                            
                            # Validate and extract style
                            if validate_style_number(potential_style):
                                style_number = potential_style
                                # Store SKU color as backup, but don't use it yet
                                if len(potential_color) >= 2:
                                    sku_extracted_color = potential_color
                
                # Fallback to separate style column
                if not style_number:
                    style_col = column_mapping.get('style')
                    if style_col and style_col in row and pd.notna(row[style_col]):
                        value = str(row[style_col]).strip()
                        # Validate it matches style pattern
                        if validate_style_number(value):
                            style_number = value
                        else:
                            result['warnings'].append(
                                f"Row {idx + 1}: Invalid style number format '{value}'. "
                                f"Expected 6-7 digits with optional L/N/W/WW suffix."
                            )
                            continue
                
                # Skip rows without valid style number
                if not style_number:
                    continue
                
                # Normalize style number: remove width suffixes (W, WW) for base style
                # Keep kids suffixes (L, N) as they're different products
                base_style_number = style_number
                width_suffix = None
                
                # Check for width suffixes (W or WW at the end)
                if style_number.endswith('WW'):
                    base_style_number = style_number[:-2]
                    width_suffix = 'WW'
                elif style_number.endswith('W') and not style_number.endswith('WW'):
                    # Only remove W if it's not part of WW
                    if len(style_number) > 1 and style_number[-2].isdigit():
                        base_style_number = style_number[:-1]
                        width_suffix = 'W'
                
                # PRIORITY 1: Try to get color from separate COLOR column (most reliable)
                color_col = column_mapping.get('color')
                if color_col and color_col in row and pd.notna(row[color_col]):
                    value = str(row[color_col]).strip().upper()
                    # Validate it matches color pattern
                    if validate_color_code(value):
                        color_name = value
                    elif len(value) >= 2:
                        # Accept longer color codes from dedicated column
                        color_name = value
                
                # PRIORITY 2: Fallback to SKU-extracted color if no separate column
                if not color_name and sku_extracted_color:
                    color_name = sku_extracted_color
                
                # Skip row if no color found (optional - could warn instead)
                if not color_name:
                    result['warnings'].append(
                        f"Row {idx + 1} in sheet '{sheet_name}': Style {style_number} has no color"
                    )
                
                # Extract other fields
                # Extract optional fields using identified columns
                division = None
                division_col = column_mapping.get('division')
                if division_col and division_col in row and pd.notna(row[division_col]):
                    division = str(row[division_col]).strip()
                
                gender = None
                gender_col = column_mapping.get('gender')
                if gender_col and gender_col in row and pd.notna(row[gender_col]):
                    value = str(row[gender_col]).strip()
                    # Validate it contains gender keywords
                    if validate_gender(value):
                        gender = value
                    else:
                        result['warnings'].append(
                            f"Row {idx + 1}: Unexpected gender value '{value}'. "
                            f"Expected 'Women', 'Men', 'Unisex', or 'Kids'."
                        )
                
                outsole = None
                outsole_col = column_mapping.get('outsole')
                if outsole_col and outsole_col in row and pd.notna(row[outsole_col]):
                    outsole = str(row[outsole_col]).strip()
                
                # Group by base style number (without width suffixes)
                # This allows W and WW variants to match the base style
                if base_style_number not in all_styles:
                    all_styles[base_style_number] = {
                        'style_number': base_style_number,
                        'division': division,
                        'gender': gender,
                        'outsole': outsole,
                        'colors': [],
                        'width_variants': set()
                    }
                    result['total_styles_found'] += 1
                else:
                    # Update style info if not already set
                    if division and not all_styles[base_style_number]['division']:
                        all_styles[base_style_number]['division'] = division
                    if gender and not all_styles[base_style_number]['gender']:
                        all_styles[base_style_number]['gender'] = gender
                    if outsole and not all_styles[base_style_number]['outsole']:
                        all_styles[base_style_number]['outsole'] = outsole
                
                # Track width variants
                if width_suffix:
                    all_styles[base_style_number]['width_variants'].add(width_suffix)
                
                # Add color if present and not duplicate
                if color_name and color_name not in all_styles[base_style_number]['colors']:
                    all_styles[base_style_number]['colors'].append(color_name)
                    result['total_colors_found'] += 1
                elif not color_name:
                    result['warnings'].append(
                        f"Row {idx + 1} in sheet '{sheet_name}': Style {base_style_number} has no color"
                    )
        
        # Convert to list and clean up width_variants (convert set to list)
        for style in all_styles.values():
            style['width_variants'] = list(style['width_variants']) if style['width_variants'] else []
        
        result['extracted_data'] = list(all_styles.values())
        result['success'] = True
        
        logger.info(f"Successfully parsed Excel file: {result['total_styles_found']} styles, "
                   f"{result['total_colors_found']} colors")
        
    except InvalidFileException as e:
        error_msg = f"Invalid Excel file format: {str(e)}"
        logger.error(error_msg)
        result['errors'].append(error_msg)
        
    except pd.errors.EmptyDataError as e:
        error_msg = f"Excel file is empty: {str(e)}"
        logger.error(error_msg)
        result['errors'].append(error_msg)
        
    except Exception as e:
        error_msg = f"Unexpected error parsing Excel file: {str(e)}"
        logger.exception(error_msg)
        result['errors'].append(error_msg)
    
    return result


def validate_excel_data(extracted_data: List[Dict]) -> List[str]:
    """
    Validate extracted Excel data for common issues.
    
    Args:
        extracted_data: List of style dictionaries
        
    Returns:
        List of validation warnings
    """
    warnings = []
    
    for style in extracted_data:
        style_num = style.get('style_number')
        
        if not style.get('colors'):
            warnings.append(f"Style {style_num} has no colors")
        
        if not style.get('division'):
            warnings.append(f"Style {style_num} missing division")
        
        if not style.get('gender'):
            warnings.append(f"Style {style_num} missing gender")
    
    return warnings
