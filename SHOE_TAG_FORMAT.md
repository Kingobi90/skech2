# Skechers Shoe Tag Format Documentation

## Tag Structure Analysis

Based on actual Skechers shoe tags, the system is optimized to recognize the following format:

### Tag Layout

All tags contain these key fields in a structured format:

```
┌─────────────────────────────────────┐
│  SKECHERS PERFORMANCE DIVISION      │ (Yellow header)
│  or SKECHERS                        │ (White/Pink header)
├─────────────────────────────────────┤
│ Date:        2025/10/27             │
│ Code:        NSS / CHGIF224 / CHC   │
│ SN/RN:       SN144844 / 141495      │ ← STYLE NUMBER
│ Size:        WS 6#                  │
│ Color:       OLV / BBK / NAT / BLK  │ ← COLOR CODE
│ Last:        YIHPD3453W-27-NS       │
│ O/S:         OSW-00200-2 IEM 42     │
│ MTL:         195g JI.X.[1087-A      │
│ Supplier:    Jin lin/OU JIN/Yuan    │
│ Duty:                               │
│ PO#:         8101479                │
│ Misc:        Kevin/Liz G/Eunike     │
│ T:           SWM-22-012-1P HC WS 11#│
└─────────────────────────────────────┘
```

## Key Fields for CV Detection

### 1. Style Number (SN/RN)
**Format Variations:**
- `SN144844` - 6 digits with SN prefix (regular shoe)
- `SN190099` - 7 digits with SN prefix (regular shoe)
- `141495` - Standalone 6 digits (regular shoe)
- `SN144083L` - 6 digits + L suffix (kids shoe - Little)
- `SN144083N` - 6 digits + N suffix (kids shoe - Narrow/Kids)
- `SN/RN` - Field label

**Width Variations (Excel Only):**
- `144083W` - Wide width (tag shows `144083` only)
- `144083WW` - Extra wide (tag shows `144083` only)
- Width suffixes appear in Excel but NOT on physical tags
- System matches base number to all width variants

**Detection Patterns:**
- Primary: `SN\s*(\d{6,7}[LN]?)` - Captures kids suffix
- Secondary: `\b(\d{6,7}[LN]?)\b` - Standalone with optional suffix
- Alternative: Last field (e.g., `YIHPD3453W`, `KPL18897W`)

**Important Notes:**
- Kids shoes (L/N suffix) are separate products - must match exactly
- Width variants (W/WW) share same base style - tags don't show suffix
- When scanning `144083`, system returns matches for `144083`, `144083W`, `144083WW`
- When scanning `144083L`, system only returns `144083L` (kids-specific)

### 2. Color Code
**Format:** 3-letter uppercase codes

**Common Codes:**
- `BLK` - Black
- `BBK` - Black (variant)
- `WHT` - White
- `NAT` - Natural
- `OLV` - Olive
- `NVY` - Navy
- `GRY` - Grey
- `RED` - Red
- `BLU` - Blue
- `GRN` - Green
- `PNK` - Pink
- `BRN` - Brown
- `TAN` - Tan
- `GLD` - Gold
- `SLV` - Silver

**Detection Patterns:**
- Primary: `(?:COLOR|CLR)[:\s]+([A-Z]{3})`
- Secondary: Standalone 3-letter codes matched against known color map

## Tag Variations

### Type 1: Performance Division (Yellow Header)
- Images 1-3 show this format
- Yellow banner at top with Skechers logo
- Brown/tan background for field labels
- Clear field structure with labels on left

### Type 2: Standard (White/Pink Header)
- Image 4 shows this format
- White/pink header with "SKECHERS" text
- Purple/maroon text for labels
- Slightly different field names (e.g., "CLR Code" vs "Color")

## CV Processing Strategy

### Image Preprocessing
1. **Resize**: Max dimension 2000px to balance quality and speed
2. **Grayscale**: Convert to single channel for OCR
3. **Adaptive Threshold**: Binary conversion for text clarity
4. **Denoise**: Remove camera noise and artifacts

### Text Extraction
1. **OCR Engine**: Tesseract with confidence scoring
2. **Text Regions**: Detect all text blocks in tag
3. **Confidence Filter**: Only use detections >50% confidence

### Field Detection Priority

**Style Number (Priority Order):**
1. Look for "SN" prefix with 6-7 digits
2. Look for standalone 6-7 digit numbers
3. Look for "Last" field alphanumeric codes
4. Validate against known patterns

**Color (Priority Order):**
1. Look for "Color:" or "CLR Code:" field
2. Extract 3-letter code after label
3. Map code to full color name
4. Fall back to full color name search

## Style Number Matching Logic

### Excel Processing
When uploading Excel files:
1. **Width Variants**: `144083W` and `144083WW` → Stored as base `144083`
2. **Kids Shoes**: `144083L` and `144083N` → Stored with suffix
3. **Width Tracking**: System tracks which width variants exist (W, WW)

### Tag Scanning
When scanning physical tags:
1. **Regular Shoe Tag** showing `144083`:
   - Matches base style `144083`
   - Returns all colors for base style
   - Includes info about W/WW variants if they exist in Excel

2. **Kids Shoe Tag** showing `144083L`:
   - Only matches `144083L` (exact match required)
   - Returns colors specific to kids version
   - Separate from adult shoe `144083`

3. **Kids Shoe Tag** showing `144083N`:
   - Only matches `144083N` (exact match required)
   - Returns colors specific to this kids variant

### Database Lookup Flow
```
Scanned: 144083
  ↓
Query: style_number = "144083"
  ↓
Found: Yes
  ↓
Return: All colors + note about W/WW variants

Scanned: 144083L
  ↓
Query: style_number = "144083L"
  ↓
Found: Yes (separate record)
  ↓
Return: Kids-specific colors + "(Kids shoe)" label
```

## Expected Detection Accuracy

Based on tag quality and lighting:

- **Good Conditions** (clear, well-lit, flat): 85-95% accuracy
- **Fair Conditions** (slight angle, moderate light): 70-85% accuracy
- **Poor Conditions** (wrinkled, dark, extreme angle): 50-70% accuracy

**Kids Shoe Detection:**
- L/N suffix detection: 90%+ accuracy (clear single letter)
- Potential confusion: L vs I, N vs M (rare with good lighting)

## Confidence Scoring

The system returns confidence scores:
- **>80%**: High confidence, auto-approve in coordinator mode
- **60-80%**: Medium confidence, show warning but allow
- **<60%**: Low confidence, require manual verification

## Common OCR Challenges

### Challenge 1: Similar Characters
- `0` vs `O`
- `1` vs `I` vs `l`
- `5` vs `S`
- `8` vs `B`

**Solution**: Context-aware validation (numbers in SN field, letters in color field)

### Challenge 2: Wrinkled Tags
Tags attached to shoe soles may be wrinkled or curved

**Solution**: 
- Multiple capture attempts
- Image enhancement preprocessing
- Manual entry fallback

### Challenge 3: Lighting Variations
Warehouse lighting may create glare or shadows

**Solution**:
- Adaptive thresholding handles varying brightness
- Recommend consistent lighting setup
- Flash/no-flash options in camera

### Challenge 4: Partial Visibility
Tag may be partially obscured by shoe or packaging

**Solution**:
- Guide users to position tag fully in frame
- Visual alignment guides in camera UI
- Retry mechanism with feedback

## Testing Recommendations

### Test Cases
1. **Perfect Tag**: Flat, well-lit, clear text
2. **Angled Tag**: 15-30 degree angle
3. **Wrinkled Tag**: Curved on shoe sole
4. **Low Light**: Dim warehouse conditions
5. **Glare**: Reflective plastic tag holder
6. **Partial Occlusion**: Edge of tag cut off

### Validation Process
1. Scan test set of 50+ tags
2. Record detection accuracy per field
3. Note failure patterns
4. Adjust preprocessing parameters
5. Re-test until >85% accuracy achieved

## Manual Entry Fallback

When CV fails, users can manually enter:
- **Style Number**: Text input with numeric keyboard
- **Color**: Dropdown with common colors + "Other" option
- **Validation**: Check against database before submission

## Future Enhancements

1. **Machine Learning**: Train custom model on Skechers tags
2. **Barcode Support**: Detect barcodes if present on tags
3. **Multi-Language**: Support international tag formats
4. **Batch Scanning**: Process multiple tags in one image
5. **Quality Feedback**: Guide users to improve capture angle/lighting

## Integration Notes

### Backend API
- Endpoint: `POST /api/cv/detect`
- Input: Base64 encoded image
- Output: Style number, color, confidence scores

### iOS App
- Camera: AVFoundation with custom preview
- Alignment: Visual frame guides for tag positioning
- Feedback: Real-time quality indicators
- Retry: Easy re-scan if detection fails

### Database Lookup
After CV detection:
1. Query styles table for style number
2. Query colors table for color match
3. Return status: Keep/Wait/Drop
4. Display complete product information

## Support & Troubleshooting

**Low Detection Rate:**
- Check Tesseract installation
- Verify image preprocessing parameters
- Review lighting conditions
- Test with sample images

**Wrong Style Numbers:**
- Validate regex patterns against actual tags
- Check for OCR character confusion
- Add more training data if using ML

**Color Mismatches:**
- Expand COLOR_CODE_MAP with new codes
- Check for regional color code variations
- Add fuzzy matching for similar colors
