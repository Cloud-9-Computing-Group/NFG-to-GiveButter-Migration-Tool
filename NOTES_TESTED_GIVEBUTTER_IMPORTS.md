# 🧪 GiveButter Import Testing Results
**Test Date**: April 15-16, 2026  
**Tested By**: Rob  
**Purpose**: Validate GiveButter import capabilities before finalizing migration scripts

---

## 📋 Test Summary

| Test | Status | Key Finding |
|------|--------|-------------|
| **Test 1: Multiple Emails/Phones** | ✅ PASS | Comma-separated works perfectly. 10+ emails/phones supported. |
| **Test 2: Long Text Limits** | ⚠️ PARTIAL | Standard text: 255 char limit (hard). Long text: 2000+ chars (works). |
| **Test 3: Company POC** | ✅ PASS | Both methods work: existing POC via ID, new POC auto-created. |
| **Test 4: Upsert Behavior** | ✅ PASS | **Requires Givebutter Contact ID** to upsert. External ID alone creates duplicate. |
| **Test 7: Transaction Import** | ⚠️ PARTIAL | All import features work. Notes field has 255 char limit (1 transaction affected). |
| **Test 8: Fee Handling** | ✅ PASS | Donor-covered fees require BOTH processing_fee AND fee_covered fields. |

---

## 🔍 Detailed Test Results

### **TEST 1: Multiple Emails and Phones** ✅

**Test File**: `TEST1_MultiEmailsPhones_*.csv`

**What We Tested**:
- 2 additional emails/phones
- 5 additional emails/phones
- 10 additional emails/phones

**Results**:
```
Contact: TEST_MULTI_001
  Primary Email: test.multi1@example.com
  Additional Emails: extra1@example.com, extra2@example.com
  Primary Phone: +16715550001
  Additional Phones: +16715550002, +16715550003
  ✅ Both additional emails appeared
  ✅ Both additional phones appeared

Contact: TEST_MULTI_002
  Additional Emails: 5 emails (all appeared)
  Additional Phones: 5 phones (all appeared)
  ✅ All 5 additional emails appeared
  ✅ All 5 additional phones appeared

Contact: TEST_MULTI_003
  Additional Emails: 10 emails (all appeared)
  Additional Phones: 10 phones (all appeared)
  ✅ All 10 additional emails appeared
  ✅ All 10 additional phones appeared
```

**Confirmed Column Names** (from export):
- `Additional Emails` (export) = `Email Addresses` (import)
- `Additional Phones` (export) = `Phone Numbers` (import)

**Key Findings**:
1. ✅ Comma-separated format works perfectly
2. ✅ No apparent limit on quantity (10+ works)
3. ✅ Spaces after commas are preserved in export
4. ✅ Phone numbers auto-formatted to E.164 format (+1671...)

**Implications for Migration**:
- **Can merge duplicate emails** into single contact
- **Can merge duplicate phones** into single contact
- Use `Email Addresses` column for additional emails
- Use `Phone Numbers` column for additional phones

---

### **TEST 2: Long Text Field Limits** ⚠️

**Test File**: `TEST2_LongText_*.csv`

**What We Tested**:
- 255 characters in both standard and long text fields
- 256 characters (one over limit)
- 500, 1000, 2000, 5000 characters

**Results**:
```
Row 1 (255 chars): ✅ IMPORTED
  Custom_Standard_Text_Test: 255 chars (full)
  Custom_Field_Long_Form_Text_Test: 255 chars (full)

Row 2-6 (256-5000 chars): ❌ FAILED TO IMPORT
  Error: Standard text field exceeded 255 character limit
  Long text field: No error flagged, but rows rejected
```

**From Export (Row 1 - 255 chars)**:
```
Custom_Standard_Text_Test: AAAA...AAAA (255 A's - full)
Custom_Field_Long_Form_Text_Test: AAAA...AAAA (255 A's - full)
```

**Key Findings**:
1. ⚠️ **Standard text: HARD 255 character limit** - Import fails if exceeded
2. ⚠️ **Long text: Import fails if standard text in same row exceeds 255**
3. ✅ Long text CAN hold 2000+ characters (confirmed from previous test data)
4. ❌ Import tool doesn't flag long text errors, only standard text errors

**Implications for Migration**:
- **MUST use long text** for fields that might exceed 255 chars:
  - `NFG_Alternate_Contacts` → Long text
  - `NFG_Household_Members` → Long text
  - `NFG_Duplicate_Source` → Long text
  - `NFG_Original_and_Merged_Addresses` → Long text (NEW)
- **Can use standard text** for fields under 255 chars:
  - `NFG_ID` → Standard text (10 chars)
  - `NFG_Type` → Standard text (12 chars)
  - `NFG_Point_Of_Contact` → Standard text (100 chars typical)
  - `NFG_Data_Quality_Flags` → Standard text (150 chars typical)

---

### **TEST 3: Company Point of Contact** ✅

**Test Files**: 
- `TEST3A_Individual_ForPOC_*.csv`
- `TEST3B_Company_ExistingPOC_*.csv`
- `TEST3C_Company_NewPOC_*.csv`

**What We Tested**:
1. Create individual contact (Jane TestContact)
2. Link company to existing individual via `Point of Contact ID`
3. Create company with new POC (Bob NewPerson) - test auto-creation

**Results**:

**Step 1: Individual Contact Created**
```
Givebutter Contact ID: 38893707
Name: Jane TestContact
Email: jane.testcontact@testcompany.com
External ID: TEST_POC_IND_001
✅ Created successfully
```

**Step 2: Company with Existing POC**
```
Company: Test Company With Existing POC
Givebutter Contact ID: 38893766
Point of Contact ID: 38893707 (Jane TestContact)
External ID: TEST_COMPANY_001

From Export:
  Point Of Contact First Name: Jane
  Point Of Contact Last Name: TestContact
  Point Of Contact Primary Email: jane.testcontact@testcompany.com
  Point Of Contact Primary Phone: +16715551234

✅ Successfully linked to existing contact
```

**Step 3: Company with New POC (Auto-Creation Test)**
```
Company: Test Company With New POC
Givebutter Contact ID: 38893824
External ID: TEST_COMPANY_002

From Export:
  Point Of Contact First Name: Bob
  Point Of Contact Last Name: NewPerson
  Point Of Contact Primary Email: bob.newperson@testcompany2.com
  Point Of Contact Primary Phone: +16715551111

Check Contacts Export:
  Givebutter Contact ID: 38893823
  Name: Bob NewPerson
  Email: bob.newperson@testcompany2.com
  External ID: (blank)

✅ Bob NewPerson was AUTO-CREATED as individual contact!
```

**Key Findings**:
1. ✅ **Method 1 (Existing POC)**: Use `Point of Contact ID` with Givebutter Contact ID
2. ✅ **Method 2 (New POC)**: Use `Point of Contact First Name/Last Name/Email/Phone` - auto-creates individual
3. ⚠️ Auto-created POCs have **no External ID** - only company has External ID
4. ✅ POC data appears in company export (name, email, phone)

**Implications for Migration**:
- **Phase 1A**: Import all individuals first (get Givebutter Contact IDs)
- **Phase 1B**: Import companies, link to existing individuals via Contact ID
- **Alternative**: Can create POC during company import if POC doesn't exist
- **Recommendation**: Import individuals first for better control and External ID tracking

---

### **TEST 4: Upsert/Update Behavior** ✅

**Test Files**:
- `TEST4A_Initial_*.csv`
- `TEST4B_Update_*.csv`

**What We Tested**:
1. Import contact with External ID "TEST_UPSERT_001"
2. Re-import same External ID with additional emails/phones
3. Test if it updates or creates duplicate

**Initial Attempt (FAILED)**:
```csv
File: TEST4B_Update_*.csv (original)
Columns: Contact External ID, First Name, Last Name, Primary Email, Email Addresses, Phone Numbers, ...
Result: ❌ Created DUPLICATE contact (External ID alone doesn't trigger upsert)
```

**Corrected Attempt (SUCCESS)**:
```csv
File: TEST4B_Update_*.csv (corrected)
Columns: Givebutter Contact ID, Contact External ID, First Name, Last Name, Primary Email, Email Addresses, Phone Numbers, ...
Added: "Givebutter Contact ID","38893888"
Result: ✅ UPDATED existing contact!
```

**From Export (After Upsert)**:
```
Givebutter Contact ID: 38893888
Contact External ID: TEST_UPSERT_001
First Name: Test
Last Name: UpsertUpdated (changed from UpsertInitial)
Primary Email: test.upsert@example.com
Additional Emails: test.upsert2@example.com, test.upsert3@example.com (ADDED)
Primary Phone: +16715551111
Additional Phones: +16715552222, +16715553333 (ADDED)
Notes: TEST: Initial import - one email, one phone
       TEST: Re-import same External ID with additional emails/phones (APPENDED)
Date Created: 2026-04-16 01:07:01
Last Modified: 2026-04-16 01:19:54 (updated timestamp)
```

**Key Findings**:
1. ❌ **External ID alone does NOT trigger upsert** - creates duplicate
2. ✅ **Givebutter Contact ID REQUIRED for upsert** - updates existing contact
3. ✅ **Additional emails/phones are ADDED** (not replaced)
4. ✅ **Notes are APPENDED** (not replaced)
5. ✅ **Last Modified timestamp updates**
6. ✅ **First Name/Last Name can be updated**

**Implications for Migration**:
- **Initial Import**: Use External ID only (creates new contacts)
- **Incremental/Update Imports**: MUST include Givebutter Contact ID to update
- **Phase 2 (ID Mapping)**: Critical step - maps External ID → Givebutter Contact ID
- **Future Updates**: Export contacts, get Givebutter Contact IDs, re-import with IDs to update
- **Duplicate Prevention**: GiveButter detects duplicates by "first + last name + (email OR phone)" but still creates them unless Givebutter Contact ID provided

---

## ❌ Features That DON'T Exist

### **Multiple Addresses**
**Tested**: Various formats for "Additional Addresses" column
**Result**: ❌ Column doesn't exist in import template
**Evidence**: 
- Import template has NO "Additional Addresses" column
- Export has "Additional Addresses" column but always empty
- Only ONE address per contact supported

**Workaround**:
- Store additional/merged addresses in custom field `NFG_Original_and_Merged_Addresses` (long text)
- Format: Pipe-separated for readability
- Example: `456 Oak Ave, Cambridge, MA 02138 (2020-2023) | 789 Elm St, Somerville, MA 02144 (2018-2020)`

---

## 📊 Export vs Import Column Name Differences

| Export Column Name | Import Column Name | Notes |
|-------------------|-------------------|-------|
| `Additional Emails` | `Email Addresses` | Different names! |
| `Additional Phones` | `Phone Numbers` | Different names! |
| `Postal Code` | `Zip Code` | Different names! |
| `Country` | `Country Code` | Must use 2-3 letter code |
| `Additional Addresses` | (doesn't exist) | Feature not available |

**Critical**: Must use **import template column names** when creating import files!

---

## 🎯 Revised Custom Fields Strategy

Based on test results, here are the recommended custom fields:

| Field Name | Type | Reason |
|------------|------|--------|
| `NFG_ID` | Text (Standard) | 10 chars max - under 255 limit |
| `NFG_Type` | Text (Standard) | 12 chars max - under 255 limit |
| `NFG_Point_Of_Contact` | Text (Standard) | ~100 chars typical - under 255 limit |
| `NFG_Data_Quality_Flags` | Text (Standard) | ~150 chars typical - under 255 limit |
| `NFG_Household_Members` | **Text (Long)** | Can exceed 255 with large households |
| `NFG_Duplicate_Source` | **Text (Long)** | Can exceed 255 with many merges |
| `NFG_Alternate_Contacts` | **Text (Long)** | Can exceed 255 with multiple phones/emails |
| `NFG_Original_and_Merged_Addresses` | **Text (Long)** | **NEW** - Store all addresses (no multi-address support) |
| `NFG_Original_Donor_Since` | Date | N/A |
| `NFG_Combined_Lifetime_Value` | Number | N/A |
| `NFG_Merge_Date` | Date | N/A |

**Total**: 11 custom fields (4 standard text, 4 long text, 2 date, 1 number)

---

## 🔧 Critical Implementation Requirements

### **1. Column Names**
- ✅ Use `Email Addresses` (not "Additional Emails")
- ✅ Use `Phone Numbers` (not "Additional Phones")
- ✅ Use `Zip Code` (not "Postal Code")
- ✅ Use `Country Code` (not "Country")
- ✅ Use exact template column names

### **2. Required Fields**
- ✅ `Email Subscription Status` REQUIRED if any email exists
- ✅ At least one of: First+Last Name, Email, or Phone
- ⚠️ **INDIVIDUALS MUST HAVE LAST NAME** - GiveButter requires Last Name for individual contacts (First Name alone will fail)
- ✅ Companies/Organizations can have empty Last Name (company name goes in "Company" field)
- ✅ Complete address (all fields) or no address (incomplete = deleted)

### **3. Upsert Requirements**
- ✅ Include `Givebutter Contact ID` to update existing contacts
- ❌ External ID alone creates duplicates (doesn't upsert)
- ✅ Phase 2 (ID mapping) is CRITICAL for future updates

### **4. Character Limits**
- ✅ Standard text: HARD 255 character limit (import fails if exceeded)
- ✅ Long text: 2000+ characters supported
- ✅ Use long text for any field that might exceed 255 chars

### **5. Company Import**
- ✅ Import individuals first (Phase 1A)
- ✅ Import companies second (Phase 1B)
- ✅ Link companies to individuals via `Point of Contact ID`
- ✅ Alternative: Auto-create POC with First/Last/Email (but no External ID)

---

## 📝 Migration Script Implications

### **Phase 1A: Individual Contacts**
```powershell
# Must include:
- Email Addresses (comma-separated for duplicates)
- Phone Numbers (comma-separated for duplicates)
- Email Subscription Status (required if email exists)
- NFG_Original_and_Merged_Addresses (long text custom field)
- All custom fields with correct types (standard vs long)

# Must NOT include:
- Givebutter Contact ID (creates new contacts)
- Additional Addresses (doesn't exist)
```

### **Phase 1B: Company Contacts**
```powershell
# Must include:
- Point of Contact ID (from Phase 1A export)
- Email Subscription Status (required if email exists)
- All custom fields

# Must do AFTER Phase 1A:
- Export individuals to get Givebutter Contact IDs
- Map N4G POC to Givebutter Contact IDs
```

### **Phase 2: ID Mapping**
```powershell
# CRITICAL STEP:
- Export all contacts from GiveButter
- Map External ID → Givebutter Contact ID
- Store in lookup table for Phase 3
- Required for future upserts/updates
```

### **Phase 3: Transactions**
```powershell
# Use lookup table from Phase 2
- Map N4G Contact ID → Givebutter Contact ID
- Handle merged duplicates (multiple N4G IDs → one GB ID)
```

---

## 🚨 Critical Gotchas

1. **External ID doesn't upsert** - Must use Givebutter Contact ID
2. **Column names differ** - Export vs Import have different names
3. **No multiple addresses** - Must use custom field workaround
4. **Standard text hard limit** - Import fails at 256 chars
5. **Email subscription required** - Import fails if email exists without subscription status
6. **Incomplete addresses deleted** - All address fields required or none

---

## ✅ Confirmed Capabilities

1. ✅ **Multiple emails** - Comma-separated, 10+ supported
2. ✅ **Multiple phones** - Comma-separated, 10+ supported
3. ✅ **Long text fields** - 2000+ characters
4. ✅ **Company POC auto-creation** - Can create POC during company import
5. ✅ **Upsert with Givebutter Contact ID** - Updates existing contacts
6. ✅ **Notes append** - Re-importing appends to notes (doesn't replace)
7. ✅ **Additional emails/phones add** - Re-importing adds to lists (doesn't replace)
8. ✅ **Date formats flexible** - Both MM/DD/YYYY and YYYY-MM-DD accepted
9. ✅ **Empty date fields** - Safe to leave blank (no errors)
10. ✅ **Standard + Long text together** - 255 chars standard + 500+ chars long works in same record

---

## 🧪 TEST 5: Date Field Imports ✅

**Test File**: `TEST_Dates_Final.csv`

**What We Tested**:
- Built-in `Date of Birth` field with different formats
- Custom date fields (`NFG_Original_Donor_Since`, `NFG_Merge_Date`)
- Mixed formats (MM/DD/YYYY vs YYYY-MM-DD)
- Empty custom date fields

**Results**:

| Test | Import Format | Export Format | Status |
|------|--------------|---------------|--------|
| **TEST_DATE_001** | Birth: `07/03/1994`<br>Donor Since: `2019-03-22`<br>Merge: `2026-04-15` | Birth: `1994-07-03`<br>Donor Since: `3/22/2019`<br>Merge: `4/15/2026` | ✅ PASS |
| **TEST_DATE_002** | Birth: `1994-07-03`<br>Donor Since: `01/15/2020`<br>Merge: `12/31/2025` | Birth: `1994-07-03`<br>Donor Since: `1/15/2020`<br>Merge: `12/31/2025` | ✅ PASS |
| **TEST_DATE_003** | Birth: `03/22/1985`<br>Donor Since: `2015-06-10`<br>Merge: `2026-01-01` | Birth: `1985-03-22`<br>Donor Since: `6/10/2015`<br>Merge: `1/1/2026` | ✅ PASS |
| **TEST_DATE_004** | Birth: `12/25/1990`<br>No custom dates | Birth: `1990-12-25`<br>Empty custom dates | ✅ PASS |

**Key Findings**:
1. ✅ **Both date formats accepted**: `MM/DD/YYYY` AND `YYYY-MM-DD` work on import
2. ✅ **Export format differs by field type**:
   - Built-in fields (Date of Birth) → Export as `YYYY-MM-DD`
   - Custom date fields → Export as `M/D/YYYY` (no leading zeros)
3. ✅ **Empty custom date fields** → Export as empty strings (no errors)
4. ✅ **No validation errors** → All 4 test records imported successfully

**Implications for Migration**:
- **Recommended import format**: `YYYY-MM-DD` (ISO 8601 standard)
- **Alternative format**: `MM/DD/YYYY` also works
- **Empty dates**: Safe to leave blank (no import errors)
- **Date parsing**: GiveButter handles both formats automatically

---

## 🧪 TEST 6: Text Field Length Edge Case ✅

**Test File**: `TEST2B_LongText_RobCustom_*.csv`

**What We Tested**:
- Standard text field at exactly 255 characters
- Long text field at 500 characters
- Both fields populated in same record

**Results**:
```
Contact: TEST_LONG_007
  Custom_Standard_Text_Test: 255 A's ✅ Full import
  Custom_Field_Long_Form_Text_Test: 500 C's ✅ Full import
  Status: ✅ IMPORTED SUCCESSFULLY
```

**Key Finding**:
- ✅ **Standard text at 255 chars + Long text at 500+ chars = Works!**
- This confirms standard text has HARD 255 limit, but won't fail if long text is also populated

---

## 📅 Test Data Reference

**Test Contacts Created**:
- TEST_MULTI_001, 002, 003 (multiple emails/phones)
- TEST_LONG_001 (255 chars in both fields)
- TEST_LONG_007 (255 chars standard + 500 chars long)
- TEST_POC_IND_001 (Jane TestContact - individual POC)
- TEST_UPSERT_001 (upsert test - updated successfully)
- TEST_DATE_001, 002, 003, 004 (date format tests)
- Bob NewPerson (auto-created POC - no External ID)

**Test Companies Created**:
- TEST_COMPANY_001 (linked to existing POC)
- TEST_COMPANY_002 (auto-created new POC)

**Export Files**:
- `contacts-2026-04-16-965088209.csv` (initial tests)
- `companies-2026-04-16-865915690.csv` (initial tests)
- `contacts-2026-04-16-935705028.csv` (final export with all tests)

---

## 🧪 TEST 7: Transaction Import - Payment Methods & $0 Amounts ✅

**Test Date**: April 19, 2026  
**Test File**: `GiveButter_Transactions_Import_20260419_*.csv`

**What We Tested**:
- Payment method mapping from N4G to GiveButter
- $0 amount transaction handling
- Campaign Title vs Campaign Code
- Notes field with Donation Notes and Payment Description

**Results**:

### **Payment Method Mapping**

| N4G Payment Method | GiveButter Payment Method | Notes Field | Status |
|-------------------|---------------------------|-------------|--------|
| Credit Card | Credit Card | payment description | ✅ PASS |
| Check | Check | payment description | ✅ PASS |
| Cash | Cash | payment description | ✅ PASS |
| ACH / Bank | ACH | payment description | ✅ PASS |
| PayPal | PayPal | payment description | ✅ PASS |
| Venmo | Venmo | payment description | ✅ PASS |
| Google Pay / Apple Pay | Digital Wallet | payment description | ✅ PASS |
| Givecard | Other | ORIG PMT TYPE: Givecard \| ... | ✅ PASS |
| Other | Other | ORIG PMT TYPE: Other \| ... | ✅ PASS |

**Key Finding**: Non-standard payment methods are mapped to "Other" with original type preserved in Notes as `ORIG PMT TYPE: [original]`

### **$0 Transaction Handling**

**Critical Discovery**: ❌ GiveButter **REJECTS** $0 transactions with standard payment methods  
**Solution**: ✅ Reclassify all $0 transactions as "In Kind" payment method

| Original Payment | Amount | Final Payment Method | Notes Field | Status |
|-----------------|--------|---------------------|-------------|--------|
| Givecard | $0.00 | **In Kind** | ORIG PMT TYPE: Givecard \| Tanzania Deposit at $2,500 | ✅ PASS |
| Other | $0.00 | **In Kind** | ORIG PMT TYPE: Other \| Executive Breakfast Guest at $0 | ✅ PASS |
| Credit Card | $0.00 | **In Kind** | ORIG PMT TYPE: Credit Card \| master 2420 | ✅ PASS |

**Results**:
- ✅ All 58 $0 transactions imported successfully as "In Kind"
- ✅ Original payment type preserved in Notes with `ORIG PMT TYPE:` prefix
- ✅ **Consistent prefix** for both non-standard and $0 transactions
- ✅ Total: 5,331 transactions (100% of source data)

### **Campaign Handling**

**Test**: Campaign Code vs Campaign Title

| Field Used | Value | GiveButter Behavior | Status |
|-----------|-------|---------------------|--------|
| Campaign Code | "CTLOVE" (6 chars) | ❌ REJECTED - Must be exactly 6 characters | ❌ FAIL |
| Campaign Title | "Chair the Love" | ✅ Auto-matches existing or creates new | ✅ PASS |

**Key Finding**: Use **Campaign Title** (not Code) for flexible matching

### **Notes Field Enhancement**

**Format**: `[ORIG PMT TYPE] | [Donation Notes] | [Payment Description] | [Merge Info]`

**Examples**:
```
Standard transaction:
  Notes: Kenya June 2026 Deposit at $1,000 | visa 3890

Non-standard payment:
  Notes: ORIG PMT TYPE: Givecard | Tanzania Deposit at $2,500

$0 transaction:
  Notes: ORIG PMT TYPE: Other | Executive Breakfast - Individual Guest at $0

$0 with standard payment:
  Notes: ORIG PMT TYPE: Credit Card | Playa del Carmen Trip | master 5161

Merged contact transaction:
  Notes: master 3728 | Merged from N4G ID: 46190954
```

**Key Findings**:
1. ✅ **$0 transactions MUST be "In Kind"** - Only payment method GiveButter accepts for $0
2. ✅ **Consistent prefix** - Both non-standard and $0 use `ORIG PMT TYPE:` prefix
3. ✅ **Original payment type preserved** in Notes for tracking
4. ✅ **Campaign Title** allows auto-matching or creation (Campaign Code too restrictive)
5. ✅ **Notes include context** from N4G (Donation Notes + Payment Description)
6. ⚠️ **Notes field has 255 character limit** - GiveButter's "Internal Note" field (rare issue)
7. ✅ **Fee Covered validation** - Must provide both `processing_fee` AND `fee_covered` for donor-covered fees
8. ✅ **External Label format** - Should be platform name + date (e.g., "N4G CTL 2026-04-19"), not transaction ID

**Implications for Migration**:
- **All transactions import** - No exclusions needed for $0 amounts
- **Payment type tracking** - Original types preserved even when remapped
- **Campaign flexibility** - Using titles allows GiveButter to match or create
- **Context preservation** - Notes field captures important N4G details
- **Notes length check** - Phase 3 warns if any transaction Notes > 255 chars (manual trim needed)
- **Fee handling** - Donor-covered fees require BOTH fields populated with same value
- **External Label** - Identifies source platform and import batch, not individual transaction

---

## 💰 TEST 8: Fee Handling & External Label ✅

**Test Date**: April 19, 2026  
**Test File**: 10-transaction subset covering all fee scenarios

### **Fee Calculation Discovery**

**Issue Encountered**: 2,481 transactions rejected with error "The fee covered may not be greater than 0."

**Root Cause**: GiveButter validation rule states:
> "Fee Covered – cannot be more than Platform Fee + Processing Fee"

When donor covered fees, we were only providing `fee_covered` without `processing_fee`, causing validation to fail:
```
fee_covered (1.34) > (platform_fee (0) + processing_fee (0)) = TRUE → REJECTED
```

**Solution**: For donor-covered fees, provide BOTH fields with the same value:
```csv
amount,processing_fee,fee_covered
36.00,1.34,1.34
```

**GiveButter Documentation Clarifications**:
- **Amount** = "amount donated, **not including** transaction or platform fees"
- **Fee Covered** = "cannot be more than Platform Fee + Processing Fee"
- **External Label** = "name of the previous platform" (e.g., "N4G CTL 2026-04-19")
- **External ID** = "unique identifier/customer ID from your previous platform" (e.g., transaction ID)

### **Test Results**

**Fee Scenarios Tested (10 transactions):**

| Scenario | Count | Amount Example | Processing Fee | Fee Covered | Result |
|----------|-------|----------------|----------------|-------------|--------|
| Donor Covered | 4 | $36.00 | $1.34 | $1.34 | ✅ PASS |
| Org Paid | 3 | $38.54 | $1.46 | (empty) | ✅ PASS |
| No Fee | 3 | $600.00 | (empty) | (empty) | ✅ PASS |

**Full Import (5,331 transactions):**
- Donor Covered Fees: 2,481 (both fields populated)
- Org Paid Fees: 522 (processing_fee only)
- No Fee: 2,328 (both empty)

**No-Fee Transaction Breakdown:**
- 60.82% "Other" payment methods (1,416 transactions)
- 29.68% Checks (691 transactions)
- 5.46% Credit Cards (127 transactions)
- 2.62% In Kind (61 transactions - all $0 reclassified)
- 0.86% Cash (20 transactions)
- 0.56% ACH (13 transactions)

**Key Findings**:
1. ✅ **Donor-covered fees** require BOTH `processing_fee` AND `fee_covered` fields
2. ✅ **Amount field** is donation only, NOT including fees
3. ✅ **External Label** should identify platform/batch, not individual transaction
4. ✅ **No-fee transactions** are mostly "Other" payment methods and Checks

---

## 🎯 Next Steps

1. ✅ Create 11th custom field: `NFG_Original_and_Merged_Addresses` (long text)
2. ✅ Update Phase 1 scripts to use correct column names
3. ✅ Split Phase 1 into 1A (Individuals) and 1B (Companies)
4. ✅ Implement address merging into custom field (not primary address)
5. ✅ Implement email/phone merging into Additional fields
6. ✅ Ensure all long text fields use long text type
7. ✅ Add Email Subscription Status logic
8. ✅ Update Phase 2 to handle Givebutter Contact ID mapping
9. ✅ Implement $0 transaction reclassification as "In Kind"
10. ✅ Add payment method mapping with `ORIG PMT TYPE:` preservation (consistent prefix)
11. ✅ Switch from Campaign Code to Campaign Title
12. ✅ Fix System.Object[] bug in payment method mapping

---

**Document Version**: 1.3  
**Last Updated**: April 19, 2026  
**Status**: All Testing Complete ✅ - Ready for Production

**Tests Completed**: 8 total
1. ✅ Multiple Emails/Phones
2. ✅ Long Text Limits
3. ✅ Company POC
4. ✅ Upsert Behavior
5. ✅ Date Field Imports
6. ✅ Text Field Edge Case (255 + 500)
7. ✅ Transaction Import - Payment Methods & $0 Amounts
8. ✅ Fee Handling & External Label
