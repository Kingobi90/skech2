# Smart Excel Parsing - Pattern-Based Column Detection

## Overview

The Excel parser uses **intelligent pattern recognition** instead of hardcoded column positions. This means the system will work regardless of:
- Column order changes
- Different Excel layouts
- Renamed columns (as long as content matches patterns)
- Multiple sheets with different structures

## How It Works

### Step 1: Column Identification

For each column in the Excel file, the system:
1. Reads the column name
2. Samples the first 20 data values
3. Analyzes both name and content patterns
4. Assigns a type if confidence is ≥70%

### Step 2: Pattern Validation

Each data type has strict validation rules:

#### **Style Number Pattern**
```
Valid: 6-7 digits + optional suffix (L, N, W, or WW)
Examples:
  ✅ 104433
  ✅ 144083
  ✅ 104437W
  ✅ 104437WW
  ✅ 144083L
  ✅ 144083N
  ❌ 12345 (too short)
  ❌ 12345678 (too long)
  ❌ 104433X (invalid suffix)
  ❌ ABC123 (letters in wrong place)
```

**Regex Pattern:** `^\d{6,7}(?:[LN]|WW?)?$`

#### **Color Code Pattern**
```
Valid: 3-4 uppercase letters only
Examples:
  ✅ BLK
  ✅ WSL
  ✅ CHOC
  ✅ NVY
  ✅ DKBS
  ❌ BL (too short)
  ❌ BLACK (too long)
  ❌ BL1 (contains number)
  ❌ blk (lowercase)
```

**Regex Pattern:** `^[A-Z]{3,4}$`

#### **Gender Pattern**
```
Valid: Contains gender keywords
Examples:
  ✅ WOMENS
  ✅ MENS
  ✅ Women
  ✅ Men
  ✅ Unisex
  ✅ Kids
  ❌ Adult (no gender keyword)
  ❌ Size 6 (not gender)
```

**Keywords:** women, men, womens, mens, unisex, kids, male, female

### Step 3: Column Mapping

The system creates a mapping like:
```python
{
    'style': 'STYLE',        # Column H in your example
    'color': 'COLOR',        # Column J in your example
    'gender': 'GENDER',      # Column D in your example
    'division': 'DIVISION',  # Column E in your example
    'outsole': 'OUTSOLE'     # Column G in your example
}
```

### Step 4: Data Extraction

For each row:
1. Extract value from mapped column
2. Validate against pattern
3. Log warning if validation fails
4. Skip row if required fields invalid
5. Process valid data

## Supported Excel Layouts

### Layout 1: Your Current Format
```
| IMAGE | SKU        | SHOE TYPE | GENDER | DIVISION | ... | OUTSOLE | STYLE  | ... | COLOR |
|-------|------------|-----------|--------|----------|-----|---------|--------|-----|-------|
| ...   | 104433_WSL | SHOES     | WOMENS | SPORT    | ... | VIRTUE  | 104433 | ... | WSL   |
```

### Layout 2: Reordered Columns
```
| STYLE  | COLOR | GENDER | DIVISION | OUTSOLE | SKU        |
|--------|-------|--------|----------|---------|------------|
| 104433 | WSL   | WOMENS | SPORT    | VIRTUE  | 104433_WSL |
```

### Layout 3: Different Names (Still Works!)
```
| Style Number | Clr Code | Sex    | Div         | Sole   |
|--------------|----------|--------|-------------|--------|
| 104433       | WSL      | WOMENS | SPORT ACTIVE| VIRTUE |
```

**All three layouts work because the system validates content, not position!**

## Column Name Recognition

The system looks for these keywords in column names:

### Style Number
- "style"
- "style number"
- "style_number"
- "stylenumber"

### Color
- "color"
- "colour"
- "clr"
- "color code"

### Gender
- "gender"
- "sex"

### Division
- "division"
- "div"
- "category"

### Outsole
- "outsole"
- "sole"
- "bottom"

**Case insensitive** - works with any capitalization

## Fallback Detection

If column name doesn't match keywords, the system analyzes content:

```python
# Example: Column named "X" with values [104433, 104437, 144083]
# System detects: 80% match style pattern → Identifies as 'style'

# Example: Column named "Y" with values [BLK, WSL, NVY]
# System detects: 100% match color pattern → Identifies as 'color'
```

## Error Handling

### Missing Required Columns
```
Warning: "Sheet 'Products': Could not identify style number column. 
Looking for 6-7 digit numbers with optional L/N/W/WW suffix."
→ Sheet skipped, processing continues with other sheets
```

### Invalid Data Format
```
Warning: "Row 15: Invalid style number format '12345'. 
Expected 6-7 digits with optional L/N/W/WW suffix."
→ Row skipped, processing continues with next row
```

### Invalid Color Code
```
Warning: "Row 23: Invalid color code format 'BLACK'. 
Expected 3-4 uppercase letters."
→ Row skipped, processing continues with next row
```

### Unexpected Gender Value
```
Warning: "Row 42: Unexpected gender value 'Adult'. 
Expected 'Women', 'Men', 'Unisex', or 'Kids'."
→ Value not stored, but row still processed
```

## Validation Examples

### Valid Excel Data
```
STYLE   | COLOR | GENDER | DIVISION     | OUTSOLE
104433  | WSL   | WOMENS | SPORT ACTIVE | VIRTUE
104437W | NVY   | WOMENS | SPORT ACTIVE | VIRTUE
144083L | CHOC  | KIDS   | CASUAL       | GRATIS
```
✅ All rows processed successfully

### Mixed Valid/Invalid Data
```
STYLE   | COLOR  | GENDER | DIVISION
104433  | WSL    | WOMENS | SPORT      ✅ Valid
12345   | BLK    | WOMENS | SPORT      ❌ Style too short - skipped
104437  | BLACK  | WOMENS | SPORT      ❌ Color too long - skipped
144083L | CHOC   | KIDS   | CASUAL     ✅ Valid
104450  | BBK    | Adult  | SPORT      ⚠️  Gender invalid - stored without gender
```

Result: 3 styles processed (2 fully valid, 1 without gender)

## Width and Kids Handling

The system automatically handles variations:

### Width Variants (W, WW)
```
Input Excel:
  104437   | BLK
  104437W  | BLK
  104437WW | BLK

Database Storage:
  Style: 104437
  Colors: [BLK]
  Width Variants: [W, WW]
```

### Kids Variants (L, N)
```
Input Excel:
  144083  | BLK
  144083L | NVY
  144083N | RED

Database Storage:
  Style 1: 144083  (adult) - BLK
  Style 2: 144083L (kids)  - NVY
  Style 3: 144083N (kids)  - RED
```

## Testing Your Excel Files

### Test Checklist

1. **Column Order Test**
   - Rearrange columns in Excel
   - Upload file
   - Verify all data extracted correctly

2. **Column Rename Test**
   - Rename "STYLE" to "Style Number"
   - Rename "COLOR" to "Clr Code"
   - Upload file
   - Verify columns still detected

3. **Invalid Data Test**
   - Add row with 5-digit style number
   - Add row with 2-letter color code
   - Upload file
   - Verify warnings logged, valid rows processed

4. **Multiple Sheets Test**
   - Create Excel with 3 sheets
   - Each sheet has different column order
   - Upload file
   - Verify all sheets processed

5. **Width Variants Test**
   - Add styles with W and WW suffixes
   - Upload file
   - Verify normalized to base style

6. **Kids Variants Test**
   - Add styles with L and N suffixes
   - Upload file
   - Verify stored as separate styles

## API Response Format

### Successful Upload
```json
{
  "file_id": 123,
  "filename": "products.xlsx",
  "file_type": "xlsx",
  "category": "all_bought",
  "parsing_summary": {
    "total_rows_processed": 150,
    "total_styles_found": 45,
    "total_colors_found": 120,
    "styles_created": 40,
    "styles_updated": 5,
    "colors_created": 115
  },
  "warnings": [
    "Row 23: Invalid color code format 'BLACK'. Expected 3-4 uppercase letters.",
    "Row 67: Invalid style number format '12345'. Expected 6-7 digits with optional L/N/W/WW suffix."
  ]
}
```

### Failed Upload (No Valid Columns)
```json
{
  "error": "Failed to parse Excel file",
  "details": [
    "Sheet 'Products': Could not identify style number column.",
    "Sheet 'Products': Could not identify color column."
  ]
}
```

## Best Practices

### ✅ Do This
- Keep column names descriptive (STYLE, COLOR, GENDER)
- Use consistent data formats within columns
- Include column headers in first row
- Use uppercase for color codes
- Use 6-7 digits for style numbers

### ❌ Avoid This
- Mixing data types in same column
- Inconsistent formatting (BLK vs Black vs blk)
- Missing column headers
- Merged cells in data rows
- Empty rows between data

## Troubleshooting

### Problem: "Could not identify style number column"
**Solution:** Ensure style column contains 6-7 digit numbers. Check first 20 rows for valid data.

### Problem: "Could not identify color column"
**Solution:** Ensure color column contains 3-4 letter codes (BLK, WSL, CHOC). Avoid full names like "Black".

### Problem: Many rows skipped
**Solution:** Review warnings in API response. Fix data format issues in Excel before re-uploading.

### Problem: Styles not matching when scanning
**Solution:** Verify style numbers in Excel match format on physical tags (6-7 digits + optional L/N).

## Summary

The smart Excel parser:
- ✅ Works with any column order
- ✅ Validates data patterns, not positions
- ✅ Handles renamed columns automatically
- ✅ Provides detailed error messages
- ✅ Processes multiple sheets independently
- ✅ Skips invalid rows, continues processing
- ✅ Handles width and kids variations
- ✅ Never crashes from reordered columns

**Key Principle:** Content validation > Column position
