# Width and Kids Shoe Variations - Technical Guide

## Overview

Skechers uses suffix codes to indicate shoe width and kids sizing. The system handles these variations intelligently to ensure proper matching between Excel data and scanned tags.

## Width Variations (W, WW)

### Excel Format
```
Style Number | Color | Description
144083       | Black | Regular width
144083W      | Black | Wide width
144083WW     | Black | Extra wide width
```

### Physical Tag Format
**All width variants show the SAME base number on tags:**
```
Tag for regular: SN144083
Tag for wide:    SN144083  (same!)
Tag for XL wide: SN144083  (same!)
```

### System Behavior

**Excel Upload:**
- `144083W` → Stored as base `144083` with width_variant: "W"
- `144083WW` → Stored as base `144083` with width_variant: "WW"
- System tracks which width variants exist

**Tag Scanning:**
- Scan shows: `144083`
- System queries: `style_number = "144083"`
- Returns: All colors for base style
- Note: "Available in W and WW widths" (if applicable)

**Result:**
- ✅ Regular width shoe scans → Matches base style
- ✅ Wide width shoe scans → Matches base style (same tag)
- ✅ Extra wide shoe scans → Matches base style (same tag)

## Kids Variations (L, N)

### Excel Format
```
Style Number | Color | Description
144083       | Black | Adult shoe
144083L      | Navy  | Kids shoe (Little)
144083N      | Red   | Kids shoe (Narrow/Kids variant)
```

### Physical Tag Format
**Kids shoes show the suffix on tags:**
```
Tag for adult: SN144083
Tag for kids:  SN144083L  (includes L)
Tag for kids:  SN144083N  (includes N)
```

### System Behavior

**Excel Upload:**
- `144083` → Stored as `144083` (adult)
- `144083L` → Stored as `144083L` (kids, separate record)
- `144083N` → Stored as `144083N` (kids, separate record)

**Tag Scanning:**
- Scan shows: `144083` → Matches adult style only
- Scan shows: `144083L` → Matches kids L style only
- Scan shows: `144083N` → Matches kids N style only

**Result:**
- ✅ Adult shoe scans → Matches adult style
- ✅ Kids L shoe scans → Matches kids L style (separate)
- ✅ Kids N shoe scans → Matches kids N style (separate)
- ❌ Adult shoe scan does NOT match kids styles
- ❌ Kids shoe scan does NOT match adult style

## Technical Implementation

### Excel Parser Logic

```python
# Width variants - normalize to base
if style_number.endswith('WW'):
    base_style = style_number[:-2]  # 144083WW → 144083
    width_variant = 'WW'
elif style_number.endswith('W'):
    base_style = style_number[:-1]  # 144083W → 144083
    width_variant = 'W'

# Kids variants - keep suffix
elif style_number.endswith('L') or style_number.endswith('N'):
    base_style = style_number  # 144083L → 144083L (keep as-is)
    is_kids = True
```

### CV Detection Patterns

```python
# Detect style with optional kids suffix
pattern = r'SN\s*(\d{6,7}[LN]?)'

# Examples:
# "SN144083"  → Captures: "144083"
# "SN144083L" → Captures: "144083L"
# "SN144083N" → Captures: "144083N"
```

### Database Lookup Logic

```python
def lookup_style_color(style_number):
    # Check for kids suffix
    if style_number.endswith('L') or style_number.endswith('N'):
        # Kids shoe - exact match required
        query = f"style_number = '{style_number}'"
        is_kids = True
    else:
        # Regular shoe - base match (includes W/WW variants)
        query = f"style_number = '{style_number}'"
        is_kids = False
    
    # Query database
    result = database.query(query)
    
    if result:
        return {
            'status': 'keep',
            'style': result,
            'is_kids': is_kids,
            'message': 'Kids shoe' if is_kids else 'Regular shoe'
        }
```

## Real-World Examples

### Example 1: Regular Shoe with Width Variants

**Excel Data:**
```
144083   | Black | Running | Men
144083W  | Black | Running | Men
144083WW | Black | Running | Men
```

**Database Storage:**
```
Style: 144083
Colors: [Black]
Width Variants: [W, WW]
```

**Scanning:**
- Coordinator scans tag showing "SN144083"
- System finds style 144083
- Returns: "Keep - Black available in regular, W, and WW widths"

### Example 2: Kids Shoe Separate from Adult

**Excel Data:**
```
144083  | Black | Running | Men
144083L | Navy  | Running | Kids
```

**Database Storage:**
```
Style 1: 144083  (adult)
  Colors: [Black]
  
Style 2: 144083L (kids)
  Colors: [Navy]
```

**Scanning:**
- Scan adult tag "SN144083" → Matches adult style, Black color
- Scan kids tag "SN144083L" → Matches kids style, Navy color
- No cross-matching between adult and kids

### Example 3: Multiple Kids Variants

**Excel Data:**
```
144083  | Black | Running | Men
144083L | Navy  | Running | Kids
144083N | Red   | Running | Kids
```

**Database Storage:**
```
Style 1: 144083  (adult) - Black
Style 2: 144083L (kids)  - Navy
Style 3: 144083N (kids)  - Red
```

**Scanning:**
- "SN144083" → Adult Black
- "SN144083L" → Kids Navy
- "SN144083N" → Kids Red
- Each is independent

## Edge Cases

### Case 1: Style Ending in W (Not Width)
```
Style: 12345W (actual style, not width variant)
Tag shows: SN12345W
```
**Handling:** System checks if W is preceded by digit. If yes, treats as width. If no, keeps as-is.

### Case 2: OCR Confusion
```
Scanned: 144083I (I instead of L)
Actual: 144083L
```
**Handling:** No match found → Manual entry required

### Case 3: Missing Kids Variant in Excel
```
Excel has: 144083 (adult only)
Tag scans: 144083L (kids)
```
**Result:** Status = "Wait" (style exists but this variant not in database)

## User Interface Indicators

### iOS App Display

**Regular Shoe:**
```
Style #144083
Color: Black
Status: KEEP
Available widths: Regular, W, WW
```

**Kids Shoe:**
```
Style #144083L
Color: Navy
Status: KEEP
Type: Kids Shoe (L)
```

### Manager Approval Screen

**Card Display:**
```
┌─────────────────────────────┐
│ Style #144083L              │
│ Color: Navy                 │
│ Coordinator: KEEP           │
│ Type: Kids Shoe             │
│                             │
│ ← Swipe to approve/reject → │
└─────────────────────────────┘
```

## Testing Checklist

- [ ] Upload Excel with W/WW variants
- [ ] Verify base style created with width_variants tracked
- [ ] Scan regular shoe tag (no suffix)
- [ ] Verify matches base style
- [ ] Upload Excel with L/N variants
- [ ] Verify separate style records created
- [ ] Scan kids tag with L suffix
- [ ] Verify matches only kids L style
- [ ] Scan kids tag with N suffix
- [ ] Verify matches only kids N style
- [ ] Verify adult scan doesn't match kids
- [ ] Verify kids scan doesn't match adult

## Summary

| Variation | Excel Format | Tag Shows | Database Storage | Matching Logic |
|-----------|-------------|-----------|------------------|----------------|
| Regular   | 144083      | SN144083  | 144083          | Exact match    |
| Wide      | 144083W     | SN144083  | 144083 (W)      | Base match     |
| XL Wide   | 144083WW    | SN144083  | 144083 (WW)     | Base match     |
| Kids L    | 144083L     | SN144083L | 144083L         | Exact match    |
| Kids N    | 144083N     | SN144083N | 144083N         | Exact match    |

**Key Principle:** Width = Same product, different fit → Match base style  
**Key Principle:** Kids = Different product → Separate style record
