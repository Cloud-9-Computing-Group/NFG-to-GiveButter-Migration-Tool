# 📋 Final Custom Fields List for GiveButter

**Based on**: Testing completed April 15-16, 2026  
**Total Fields**: 11 custom fields

---

## 🎯 Create These Custom Fields in GiveButter UI

### **Standard Text Fields (4)**

| # | Field Name | Type | Max Length | Purpose |
|---|------------|------|------------|---------|
| 1 | `NFG_ID` | Text | ~10 chars | Original N4G Contact ID (primary key) |
| 2 | `NFG_Type` | Text | ~12 chars | Individual or Organization |
| 3 | `NFG_Point_Of_Contact` | Text | ~100 chars | POC info for organizations |
| 4 | `NFG_Data_Quality_Flags` | Text | ~150 chars | Flags like CONVERTED_TO_ORG, SHARED_EMAIL |

### **Long Text Fields (4)**

| # | Field Name | Type | Max Length | Purpose |
|---|------------|------|------------|---------|
| 5 | `NFG_Household_Members` | Text (Long) | 2000+ chars | Names of other household members for family tracking |
| 6 | `NFG_Duplicate_Source` | Text (Long) | 2000+ chars | Original N4G IDs of merged duplicate records for audit trail |
| 7 | `NFG_Alternate_Contacts` | Text (Long) | 2000+ chars | Additional contact info from merged duplicates (emails/phones) |
| 8 | `NFG_Original_and_Merged_Addresses` | Text (Long) | 2000+ chars | All addresses + invalid phone numbers that couldn't be imported |

### **Date Fields (2)**

| # | Field Name | Type | Purpose |
|---|------------|------|---------|
| 9 | `NFG_Original_Donor_Since` | Date | Earliest donation date from merged records |
| 10 | `NFG_Merge_Date` | Date | When duplicate merge occurred |

### **Number Fields (1)**

| # | Field Name | Type | Purpose |
|---|------------|------|---------|
| 11 | `NFG_Combined_Lifetime_Value` | Number | Sum of lifetime donations from merged records |

---

## 📝 Field Details & Examples

### **1. NFG_ID** (Text - Standard)
```
Example: "46190954"
Purpose: Original N4G Contact ID for mapping transactions
Always Populated: Yes
```

### **2. NFG_Type** (Text - Standard)
```
Example: "Individual" or "Organization"
Purpose: Track original N4G classification
Always Populated: Yes
```

### **3. NFG_Point_Of_Contact** (Text - Standard)
```
Example: "Milton Johnson (milton@email.com, 555-1234)"
Purpose: Organization point of contact info
Populated When: Contact is Organization with POC data
Max Length: ~100 chars (well under 255 limit)
```

### **4. NFG_Data_Quality_Flags** (Text - Standard)
```
Example: "CONVERTED_TO_ORG, SHARED_EMAIL, COUPLE_NAME"
Purpose: Flag data quality issues for review
Populated When: Any data quality concern detected
Possible Values:
  - CONVERTED_TO_ORG (Individual → Organization)
  - SHARED_EMAIL (Multiple contacts, same email)
  - COUPLE_NAME (Joint names like "John & Jane")
  - POSSIBLE_DUPLICATE (Low confidence duplicate)
  - AUTO_MERGED (High confidence duplicate merged)
Max Length: ~150 chars typical
```

### **5. NFG_Household_Members** (Text - Long)
```
Example: "Jane Doe (Spouse), John Doe Jr (Child), Mary Doe (Daughter), Bob Doe (Son)"
Purpose: Names of other household members from N4G
Populated When: Contact is part of multi-member household
Why Long Text: Large households can exceed 255 chars
```

### **6. NFG_Duplicate_Source** (Text - Long)
```
Example: "46190954, 38475621, 29384756, 12345678, 87654321"
Purpose: Track which N4G IDs were merged into this contact
Populated When: Contact is result of merging duplicates
Why Long Text: Merging 10+ duplicates can exceed 255 chars
Format: Comma-separated N4G Contact IDs
```

### **7. NFG_Alternate_Contacts** (Text - Long)
```
Example: "Home: 803-547-8822 | Work: 555-5678 | Alt Email: john@work.com | Work Email: john@company.com"
Purpose: Store alternate phones/emails that don't fit in primary fields
Populated When: Contact has alternate contact info
Why Long Text: Multiple alternates can exceed 255 chars
Format: Pipe-separated for readability
Note: Primary additional emails/phones go in GiveButter's "Email Addresses" and "Phone Numbers" columns
```

### **8. NFG_Original_and_Merged_Addresses** (Text - Long) **NEW**
```
Example: "PRIMARY: 123 Main St, Boston, MA 02101 | PHONE NUMBER: +245708219128"
Purpose: Store all addresses AND invalid phone numbers that can't be imported to primary fields
Populated When: 
  - Contact has address history
  - Duplicate contacts with different addresses are merged
  - Address data is incomplete/invalid (bad zip, foreign country, etc.)
  - Phone numbers in invalid format for GiveButter (international, wrong format)
Why Long Text: Multiple addresses/phones with notes can exceed 255 chars
Format: Pipe-separated, with "PRIMARY:", "MERGED:", or "PHONE NUMBER:" prefixes
Why Needed: GiveButter has NO "Additional Addresses" feature (confirmed via testing)
```

### **9. NFG_Original_Donor_Since** (Date)
```
Example: 2019-03-22
Purpose: Preserve earliest "First Donation Date" from merged records
Populated When: Contact is merged duplicate
Format: YYYY-MM-DD
```

### **10. NFG_Merge_Date** (Date)
```
Example: 2026-04-15
Purpose: Track when duplicate merge occurred
Populated When: Contact is merged duplicate
Format: YYYY-MM-DD
```

### **11. NFG_Combined_Lifetime_Value** (Number)
```
Example: 17000.00
Purpose: Sum of "Lifetime Donations" from all merged N4G records
Populated When: Contact is merged duplicate
Format: Decimal number
```

---

## 🎯 How to Create in GiveButter

### **Step-by-Step**:
1. Log into GiveButter
2. Go to **Contacts** → **Settings** → **Custom Fields**
3. Click **"Add Custom Field"**
4. For each field:
   - Enter **exact name** (case-sensitive)
   - Select **type**:
     - **Text** for standard text (fields 1-4)
     - **Text (Long Form)** for long text (fields 5-8)
     - **Date** for date fields (fields 9-10)
     - **Number** for number fields (field 11)
   - Save

### **Copy-Paste Checklist**:
```
☐ NFG_ID (Text)
☐ NFG_Type (Text)
☐ NFG_Point_Of_Contact (Text)
☐ NFG_Data_Quality_Flags (Text)
☐ NFG_Household_Members (Text - Long Form)
☐ NFG_Duplicate_Source (Text - Long Form)
☐ NFG_Alternate_Contacts (Text - Long Form)
☐ NFG_Original_and_Merged_Addresses (Text - Long Form)
☐ NFG_Original_Donor_Since (Date)
☐ NFG_Merge_Date (Date)
☐ NFG_Combined_Lifetime_Value (Number)
```

---

## 📊 Expected Population Statistics

Based on 2,853 contacts:

| Custom Field | Expected Population | Percentage |
|--------------|---------------------|------------|
| NFG_ID | 2,853 | 100% |
| NFG_Type | 2,853 | 100% |
| NFG_Point_Of_Contact | ~357 | 13% (organizations) |
| NFG_Data_Quality_Flags | ~247 | 9% |
| NFG_Household_Members | ~87 | 3% |
| NFG_Duplicate_Source | ~89 | 3% (if duplicates merged) |
| NFG_Alternate_Contacts | ~800-1000 | 28-35% |
| NFG_Original_and_Merged_Addresses | ~500-800 | 18-28% |
| NFG_Original_Donor_Since | ~89 | 3% (if duplicates merged) |
| NFG_Combined_Lifetime_Value | ~89 | 3% (if duplicates merged) |
| NFG_Merge_Date | ~89 | 3% (if duplicates merged) |

---

## 🔍 Example: What You'll See in GiveButter

### **Example 1: Regular Individual**
```
Name: Randy Vetter
Email: randyvetter1952@gmail.com
Phone: 704-905-1950
Address: 49107 Gladiolus St, Indian Land, SC 29707

Custom Fields:
  NFG_ID: 46190954
  NFG_Type: Individual
  NFG_Point_Of_Contact: (empty)
  NFG_Data_Quality_Flags: (empty)
  NFG_Household_Members: (empty)
  NFG_Duplicate_Source: (empty)
  NFG_Alternate_Contacts: Home: 803-547-8822 | Work Email: randy@work.com
  NFG_Original_and_Merged_Addresses: (empty)
  NFG_Original_Donor_Since: (empty)
  NFG_Combined_Lifetime_Value: (empty)
  NFG_Merge_Date: (empty)
```

### **Example 2: Merged Duplicate with Multiple Addresses**
```
Name: John Smith
Primary Email: john@personal.com
Email Addresses: john@work.com, john@old.com
Primary Phone: 555-1234
Phone Numbers: 555-5678, 555-9999
Address: 123 Main St, Boston, MA 02101 (current)

Custom Fields:
  NFG_ID: 12345678 (primary record)
  NFG_Type: Individual
  NFG_Point_Of_Contact: (empty)
  NFG_Data_Quality_Flags: AUTO_MERGED
  NFG_Household_Members: (empty)
  NFG_Duplicate_Source: 12345678, 23456789, 34567890
  NFG_Alternate_Contacts: (empty - all in Email Addresses/Phone Numbers)
  NFG_Original_and_Merged_Addresses: ORIGINAL: 123 Main St, Boston, MA 02101 (2020-present) | MERGED: 456 Oak Ave, Cambridge, MA 02138 (2015-2020) | MERGED: 789 Elm St, Somerville, MA 02144 (2010-2015)
  NFG_Original_Donor_Since: 2010-03-15
  NFG_Combined_Lifetime_Value: 25000.00
  NFG_Merge_Date: 2026-04-15
```

### **Example 3: Organization**
```
Company: Lakeland Homes and Realty, LLC
Email: milton@lakelandhomesandrealty.com
Address: 2331 Chesterfield Cir, Lakeland, FL 33813

Custom Fields:
  NFG_ID: 35088441
  NFG_Type: Organization
  NFG_Point_Of_Contact: Milton Johnson (milton@lakelandhomesandrealty.com, 555-1234)
  NFG_Data_Quality_Flags: CONVERTED_TO_ORG
  NFG_Household_Members: (empty)
  NFG_Duplicate_Source: (empty)
  NFG_Alternate_Contacts: (empty)
  NFG_Original_and_Merged_Addresses: (empty)
  NFG_Original_Donor_Since: (empty)
  NFG_Combined_Lifetime_Value: (empty)
  NFG_Merge_Date: (empty)
```

---

## ⚠️ Important Notes

1. **Exact Names Required**: Field names are case-sensitive and must match exactly
2. **Long Text vs Standard**: Use correct type - import fails if standard text exceeds 255 chars
3. **Create All 11**: Even if some are empty now, they'll be used in duplicate merging
4. **Address Workaround**: `NFG_Original_and_Merged_Addresses` is critical since GiveButter doesn't support multiple addresses
5. **Date Format**: YYYY-MM-DD
6. **Number Format**: Decimal (e.g., 17000.00)

---

## ✅ Verification Checklist

After creating all 11 fields:
- [ ] All field names match exactly (including underscores and capitalization)
- [ ] Types are correct (4 standard text, 4 long text, 2 date, 1 number)
- [ ] Fields appear in GiveButter contact custom fields list
- [ ] Download fresh import template to verify fields are included

---

**Ready to import!** Once all 11 fields are created, the migration scripts will populate them appropriately.
