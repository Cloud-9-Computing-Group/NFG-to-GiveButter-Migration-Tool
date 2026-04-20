# Handling Pre-Existing GiveButter Contacts

**Purpose**: Prevent duplicate contacts when migrating from N4G to GiveButter

---

## 🎯 The Problem

**Scenario 1: Brand New GiveButter Tenant**
- ✅ No existing contacts
- ✅ No mapping file needed
- ✅ Just run Phase 1A/1B and import

**Scenario 2: Existing GiveButter Tenant with Contacts**
- ⚠️ You already have contacts in GiveButter (test users, early donors, etc.)
- ⚠️ Some may have transactions (can't be deleted)
- ⚠️ These contacts also exist in your N4G export
- ❌ **Problem**: Re-importing creates duplicates!

**Scenario 3: Re-Running Migration (Adding More Data)**
- ⚠️ You already completed an initial data migration
- ⚠️ Now you need to migrate additional contacts or updated data
- ⚠️ All previously imported contacts exist in both N4G and GiveButter
- ❌ **Problem**: Re-running Phase 1A/1B creates duplicates!

**Solution**: Use `existing_givebutter_mapping.csv` to tell Phase 1A/1B which contacts already exist in GiveButter  
💡 **This can be generated for you!** See [Automatic Mapping File Generation](#-new-automatic-mapping-file-generation) below

---

## 📖 Example: The 3 Test Users

During development and testing, we had **3 contacts** already in GiveButter that couldn't be deleted (they had transactions):

1. **Ellie Anderson**
   - GiveButter Contact ID: `23230045`
   - N4G ID: `26878816`
   - Email: `ellie.a@example.com`
   - Had test transactions: $1.00

2. **Robert Martinez**
   - GiveButter Contact ID: `23228455`
   - N4G ID: `32695585`
   - Email: `robert.m@example.org`
   - Had test transactions

3. **Rachel Chen**
   - GiveButter Contact ID: `21966402`
   - N4G ID: `26877604`
   - Email: `rachel.c@example.net`
   - Had test transactions: $6.00

**The mapping file** told Phase 1A: "These 3 contacts already exist in GiveButter - update them instead of creating new ones."

**See**: `existing_givebutter_mapping_EXAMPLE.csv` for the exact format used

---

## ✅ How It Works

**File**: `existing_givebutter_mapping.csv`

This file maps N4G IDs to existing GiveButter Contact IDs so Phase 1A/1B can pre-populate the Givebutter Contact ID field.

### **The Process:**

1. **Phase 1A/1B** loads `existing_givebutter_mapping.csv`
2. When processing each N4G contact, checks if N4G_ID exists in mapping
3. If match found, adds the GiveButter Contact ID to the import file
4. **GiveButter import** sees the Contact ID and **updates** the existing contact (no duplicate!)

### **Matching Logic:**
- **Primary**: Match by N4G_ID (most accurate)
- **Fallback**: Match by Primary Email (case-insensitive)
- **Result**: Existing contacts are updated, new contacts are created

---

## 📁 Mapping File Format

```csv
N4G_ID,GiveButter_Contact_ID,Full_Name,Primary_Email,Contact_Type
26878816,23230045,Ellie Anderson,ellie.a@example.com,Individual
32695585,23228455,Robert Martinez,robert.m@example.org,Individual
26877604,21966402,Rachel Chen,rachel.c@example.net,Individual
```

**Columns:**
- `N4G_ID` - The ID from Network for Good export
- `GiveButter_Contact_ID` - The Contact ID from GiveButter (from export)
- `Full_Name` - For reference only
- `Primary_Email` - For reference and fallback matching
- `Contact_Type` - Individual or Organization

---

## 🔧 **NEW: Automatic Mapping File Generation**

**Use the utility script to automatically create/update the mapping file from GiveButter exports:**

```powershell
# Easy mode - auto-finds latest exports
.\Utility-CreateMappingFromGiveButter.ps1 -AutoFindLatest

# Or specify files manually
.\Utility-CreateMappingFromGiveButter.ps1 `
    -ContactsExportFile "reference files\givebutter-contacts-export.csv" `
    -CompaniesExportFile "reference files\givebutter-companies-export.csv"
```

**What it does:**
- ✅ Loads GiveButter contacts and companies exports
- ✅ Extracts all contacts with `NFG_ID` custom field
- ✅ Creates `existing_givebutter_mapping.csv` with proper format
- ✅ Includes both individuals AND companies
- ✅ Handles duplicate columns automatically

**Benefits:**
- 🎯 **Always accurate** - regenerate anytime from GiveButter
- 🎯 **No manual editing** - fully automated
- 🎯 **Comprehensive** - includes all imported contacts

---

## 📝 **Manual Method (Legacy)**

**To manually add contacts:**
1. Export from GiveButter
2. Find the contact's Givebutter Contact ID, NFG_ID, and Primary Email
3. Add a new row to `existing_givebutter_mapping.csv`

**Note:** The utility script above is recommended over manual editing.

---

## 🚀 Usage

Phase1A automatically uses this file:

```powershell
.\Phase1A-PrepareIndividuals.ps1 `
    -InputFile "reference files\CTL N4G Contact export (full).csv" `
    -OutputFolder "output"
    # Automatically loads existing_givebutter_mapping.csv
```

**To disable** (not recommended):
```powershell
.\Phase1A-PrepareIndividuals.ps1 `
    -ExistingGiveButterMapping ""
```

---

## 📊 What You'll See

**First Import (with 3 pre-existing contacts):**
```
Loading existing GiveButter contacts mapping...
Loaded 3 existing GiveButter contacts

...

Pre-Existing GiveButter Contacts:
  Matched for Upsert: 3
  These will UPDATE instead of creating duplicates
```

**After Full Import (regenerated mapping file):**
```
Loading existing GiveButter contacts mapping...
Loaded 2796 existing GiveButter contacts

...

Pre-Existing GiveButter Contacts:
  Matched for Upsert: 2321
  These will UPDATE instead of creating duplicates
```

**Note**: The second example shows a full mapping file generated after initial import. This prevents duplicates on re-runs.

---

## 🔍 Verification

**After your first import:**
1. Check GiveButter - pre-existing contacts should still have same Contact IDs
2. Check for duplicates - should NOT have duplicate contacts
3. Verify data updated - should have latest info from N4G merged with existing data

**Example (3 test users):**
- Ellie Anderson: Still Contact ID `23230045` (not duplicated)
- Robert Martinez: Still Contact ID `23228455` (not duplicated)
- Rachel Chen: Still Contact ID `21966402` (not duplicated)

---

## ⚠️ Important Notes

1. **Brand New Tenant?** - No mapping file needed! Just run Phase 1A/1B and import
2. **Existing Contacts?** - Create mapping file first to prevent duplicates
3. **Automated Generation**: Use `Utility-CreateMappingFromGiveButter.ps1` to auto-generate from GiveButter exports
4. **After Each Import**: Regenerate the mapping file before re-running Phase 1A/1B
5. **Comprehensive**: Includes both individuals AND companies with NFG_ID custom field
6. **Matching Logic**: Primary by N4G_ID, fallback by email (case-insensitive)
7. **Future Imports**: Always use latest mapping file to prevent duplicates

---

## 🎯 Quick Decision Guide

**Do I need a mapping file?**

| Situation | Need Mapping File? | Action |
|-----------|-------------------|--------|
| Brand new GiveButter tenant | ❌ No | Just run Phase 1A/1B |
| Have test users/early donors in GiveButter | ✅ Yes | Create mapping file first |
| Re-running Phase 1A/1B after initial import | ✅ Yes | Regenerate mapping file |
| Running Phase 3 (transactions only) | ❌ No | Mapping already done in Phase 2 |

---

## 💰 What About Transactions?

**Good news!** Transaction duplicate prevention is **automatic** - no mapping file needed.

### **How Phase 3 Prevents Duplicate Transactions:**

Phase 3 uses the **External ID** field to prevent duplicates:
- Each transaction gets: `External ID = N4G Transaction ID`
- GiveButter checks External ID during import
- If External ID already exists → **Skips** (no duplicate created)
- If External ID is new → **Imports** the transaction

**Example:**
```
Transaction from N4G:
  N4G Transaction ID: 64881257
  
Phase 3 creates:
  External ID: 64881257
  External Label: N4G-64881257
  
GiveButter import:
  First import → Creates transaction
  Re-import → Skips (External ID 64881257 already exists)
```

**This means:**
- ✅ You can re-run Phase 3 safely
- ✅ Only new transactions will import
- ✅ Existing transactions are automatically skipped
- ✅ No manual tracking needed

**Why this is asked at the end of Phase 3:**
The utility script regenerates the mapping file from GiveButter exports, which now include all your newly imported contacts. This keeps the mapping file current for future contact imports.

---

**This prevents duplicate creation and enables safe re-imports for both contacts AND transactions!** ✅
