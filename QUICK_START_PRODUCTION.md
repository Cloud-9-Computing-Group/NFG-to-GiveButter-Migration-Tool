# 🚀 Quick Start Guide - Production Migration

**Last Updated**: April 19, 2026  
**Status**: Production Ready ✅

**Recent Updates (April 19, 2026)**:
- ✅ **Phase 3 Transaction Enhancements**:
  - Payment method mapping with `ORIG PMT TYPE:` preservation in Notes (consistent prefix)
  - $0 transactions auto-reclassified as "In Kind" (GiveButter requirement)
  - Campaign Title (not Code) for flexible matching
  - Donation Notes and Payment Description included in Notes
  - 10-second timeout on mapping file update prompt (auto-runs if no response)
  - Fixed System.Object[] bug in payment method mapping
- ✅ **Utility Script**: Auto-backup and regenerate mapping file from GiveButter exports
- ✅ Phase 1B: Automatic OrgConversions loading, enhanced POC matching
- ✅ Phase 2: Duplicate column handling, merged duplicate ID mapping
- ✅ All long text custom fields properly populated

---

## ⚠️ CRITICAL: Before You Start

### **Do You Have Existing Data in GiveButter?**

**Choose your scenario:**

✅ **Scenario 1: Brand New GiveButter Tenant**
- No existing contacts in GiveButter
- This is your first import
- **Action**: Skip to Prerequisites below and proceed normally

⚠️ **Scenario 2: You Have Existing Contacts in GiveButter**
- You have test users, early donors, or any existing contacts
- Some contacts may have transactions (can't be deleted)
- **Action**: **STOP! Create mapping file FIRST** (see below)

⚠️ **Scenario 3: Re-Running Migration (Adding More Data)**
- You already completed an initial data migration
- Now adding more contacts or updated data
- **Action**: **STOP! Regenerate mapping file FIRST** (see below)

---

### **🔧 Creating the Mapping File (Scenarios 2 & 3)**

**If you have existing contacts in GiveButter, you MUST create a mapping file to prevent duplicates.**

**Steps:**
1. Export contacts from GiveButter (Contacts → Export → Individuals)
2. Export companies from GiveButter (Contacts → Export → Companies)
3. Save both exports to `reference files/` folder
4. Run the utility script:

```powershell
.\Utility-CreateMappingFromGiveButter.ps1 -AutoFindLatest
```

**What this does:**
- ✅ Automatically finds your latest GiveButter exports
- ✅ Creates `existing_givebutter_mapping.csv`
- ✅ Tells Phase 1A/1B which contacts already exist
- ✅ Prevents duplicate creation during import

**📖 For complete details**: See `EXISTING_CONTACTS_README.md`

---

## 📋 Prerequisites

### **1. Create Custom Fields in GiveButter**
Before running any scripts, create all 11 custom fields in GiveButter:

📄 **See**: `CUSTOM_FIELDS_FINAL.md` for complete setup instructions

**Quick Checklist**:
- [ ] NFG_ID (Text)
- [ ] NFG_Type (Text)
- [ ] NFG_Point_Of_Contact (Text)
- [ ] NFG_Data_Quality_Flags (Text)
- [ ] NFG_Household_Members (Text - **Long Form**)
- [ ] NFG_Duplicate_Source (Text - **Long Form**)
- [ ] NFG_Alternate_Contacts (Text - **Long Form**)
- [ ] NFG_Original_and_Merged_Addresses (Text - **Long Form**)
- [ ] NFG_Original_Donor_Since (Date)
- [ ] NFG_Combined_Lifetime_Value (Number)
- [ ] NFG_Merge_Date (Date)

Please note: It doesn't matter if your fields are visible for entry ("show when creating" toggles)for Givebutter to be able to accept data in imports.

### **2. Prepare Source Data**
Your source files are in `reference files/`:
- ✅ `N4G Contact export (full).csv`
- ✅ `N4G Transaction export (...).csv`

---

## 🎯 Migration Workflow

## 🔧 Known Issues & Workarounds

### **GiveButter Export Duplicate Columns**
- **Issue**: GiveButter exports may contain duplicate column names (e.g., "ARCHIVED <field name>" appears twice.) This is due to custom columns created in the past in your Givebutter tenant.  Some columns may also be archived and if they are the name is prepended with "ARCHIVED ".
- **Impact**: PowerShell Import-Csv fails with "member already present" error
- **Workaround**: Scripts automatically create "_CLEANED" versions that rename duplicate columns
- **Files affected**: Individual and company exports used in Phase 1B and Phase 2

---

## 📋 Phase 1A: Prepare Individual Contacts

**What it does:**
- Processes individuals from N4G
- **Detects and EXCLUDES** misclassified organizations (LLC, Inc, etc.) - they'll be included in Phase 1B
- Validates Last Name requirement
- Merges duplicates (optional)
- Exports ~2,375 individuals (2,496 - 121 excluded orgs)

```powershell
.\Phase1A-PrepareIndividuals.ps1 `
    -InputFile "reference files\N4G Contact export (full).csv" `
    -OutputFolder "output" `
    -AutoMergeDuplicates  # Optional: enable after reviewing duplicates
    # Automatically loads existing_givebutter_mapping.csv if present
```

**Key Features**:
- ✅ Validates Last Name requirement (GiveButter requires Last Name for individuals)
- ✅ Pre-matches existing GiveButter contacts (prevents duplicates on first import)
- ✅ Filters to individual contacts only
- ✅ **Detects and excludes** misclassified organizations (they'll be in Phase 1B)
- ✅ Detects and optionally merges high-confidence duplicates
- ✅ Merges multiple emails/phones into single contact
- ✅ Stores all addresses in custom field (GiveButter only supports 1 primary address)
- ✅ Populates all 11 custom fields
- ✅ Creates GiveButter import file

**Output Files**:
- `GiveButter_Individuals_Import_*.csv` ⭐ **Import this to GiveButter**
- `N4G_to_GiveButter_Mapping_Individuals_*.csv` (for Phase 2)
- `REVIEW_*.csv` files (review before importing)
- `Phase1A_Summary_*.txt`

**Review Files**:
1. `ERROR_MissingLastName_*.csv` - Individuals without Last Name (MUST FIX - import will fail)
2. `REVIEW_OrgConversions_*.csv` - Organizations auto-converted from individuals
3. `REVIEW_HighConfidenceDuplicates_*.csv` - Duplicates that will be merged
4. `REVIEW_SharedEmails_*.csv` - Family email accounts
5. `REVIEW_CoupleNames_*.csv` - Joint/couple names

**Next Steps**:
1. Review all `REVIEW_*.csv` files
2. Import `GiveButter_Individuals_Import_*.csv` to GiveButter (as **Contacts**)
3. **If there are failed records**, download the failed CSV and run the fix script (see below)
4. Export contacts from GiveButter (with new Givebutter Contact IDs)
5. Proceed to Phase 1B

---

### **Phase 1A-Fix: Fix Failed Import Records (Optional)**

**When to use:** After importing to GiveButter, if there are failed records due to invalid phone numbers or addresses.

**What it does:**
- Processes GiveButter's failed import CSV
- Moves invalid phone numbers to `NFG_Original_and_Merged_Addresses`
- Clears invalid addresses (data already preserved in custom field)
- Adds data quality flags

```powershell
.\Phase1A-FixFailedRecords.ps1 `
    -FailedRecordsFile "output\contacts-2026-04-19-failed.csv" `
    -OutputFolder "output"
```

**Output:**
- `GiveButter_Individuals_Import_FIXED_*.csv` ⭐ **Re-import this to GiveButter**

**Common Issues Fixed:**
- ✅ Invalid phone formats (international, malformed)
- ✅ Invalid zip codes (foreign addresses)
- ⚠️ Other issues require manual review

---

### **Phase 1B: Prepare Company Contacts**

**What it does:**
- Processes organizations from N4G
- **Automatically loads and includes ALL converted orgs from Phase 1A** (from `REVIEW_OrgConversions_*.csv`)
- Links companies to existing individual contacts (Point of Contact)
- Populates full POC data (ID + name + email + phone) from GiveButter export
- Validates phone numbers and addresses (same as Phase 1A)
- Exports ~478 companies (357 original orgs + 121 converted from Phase 1A)

```powershell
.\Phase1B-PrepareCompanies.ps1 `
    -InputFile "reference files\N4G Contact export (full).csv" `
    -IndividualMappingFile "reference files\GiveButter_Individuals_Export.csv" `
    -OutputFolder "output"
```

**Key Features**:
- ✅ Filters to organization contacts (Type = 'Organization')
- ✅ **Automatically loads Phase 1A OrgConversions** - includes ALL converted orgs (even those without LLC/Inc patterns)
- ✅ **Phone validation** - detects invalid formats, moves to custom field
- ✅ **Address validation** - clears incomplete addresses, flags missing country codes
- ✅ Links companies to existing individual contacts (Point of Contact)
- ✅ **Enhanced POC matching**: Name → N4G ID → GiveButter ID (handles merged duplicates)
- ✅ Fallback POC matching by email and phone
- ✅ Populates **full POC data** from GiveButter export (ID, name, email, phone)
- ✅ Auto-creates POC if not found in GiveButter
- ✅ Populates **all custom fields** (including long text fields for data preservation)
- ✅ Creates GiveButter company import file

**Output Files**:
- `GiveButter_Companies_Import_*.csv` ⭐ **Import this to GiveButter**
- `N4G_to_GiveButter_Mapping_Companies_*.csv` (for Phase 2)
- `REVIEW_CompanyPOCs_*.csv` (POC analysis)
- `Phase1B_Summary_*.txt`

**Review Files**:
1. `REVIEW_CompanyPOCs_*.csv` - POC linking analysis

**Next Steps**:
1. Review `REVIEW_CompanyPOCs_*.csv`
2. Import `GiveButter_Companies_Import_*.csv` to GiveButter (as **Companies**)
3. Export companies from GiveButter (with new Givebutter Contact IDs)
4. Proceed to Phase 2

---

### **Phase 2: Map N4G IDs to GiveButter Contact IDs**

```powershell
.\Phase2-MapIDs-Enhanced.ps1 `
    -GiveButterContactsExport "path\to\givebutter-contacts-export.csv" `
    -GiveButterCompaniesExport "path\to\givebutter-companies-export.csv" `
    -OutputFolder "output"
    # Automatically finds most recent mapping files from Phase 1A/1B
```

**What it does**:
- ✅ **Automatically handles duplicate columns** in GiveButter exports (creates _CLEANED versions)
- ✅ Matches N4G IDs to GiveButter Contact IDs
- ✅ Handles merged duplicates (maps all N4G IDs to single GiveButter ID)
- ✅ Creates unified lookup for Phase 3 (includes all merged duplicate IDs)
- ✅ Identifies unmatched contacts

**Output Files**:
- `ID_Lookup_Unified_ForPhase3_*.csv` ⭐ **Used in Phase 3** (includes merged duplicate mappings)
- `N4G_to_GiveButter_Mapping_Individuals_UPDATED_*.csv`
- `N4G_to_GiveButter_Mapping_Companies_UPDATED_*.csv`
- `REVIEW_Unmatched*.csv` (if any unmatched)
- `Phase2_Summary_*.txt`

**Critical**: This phase handles merged duplicates automatically. If contact A was merged with contacts B and C, the lookup will map all three N4G IDs to the same GiveButter Contact ID. This ensures transactions from ANY merged N4G ID will map correctly in Phase 3.

**Next Steps**:
1. Review any `REVIEW_Unmatched*.csv` files
2. Verify match rate (should be ~100%)
3. Proceed to Phase 3

---

### **Phase 3: Prepare Transactions**

```powershell
.\Phase3-PrepareTransactions-Enhanced.ps1 `
    -TransactionFile "reference files\N4G Transaction export (...).csv" `
    -IDLookupFile "output\ID_Lookup_Unified_ForPhase3_*.csv" `
    -OutputFolder "output" `
    -DefaultCampaignTitle "General Donations"
    # Add -SkipMappingUpdate to skip automatic mapping file update
```

**What it does**:
- ✅ Maps transactions to GiveButter Contact IDs
- ✅ Handles transactions from merged duplicate contacts
- ✅ Calculates fees correctly (donor-paid vs org-paid)
- ✅ Maps payment methods to GiveButter-supported formats
  - Standard: Credit Card, Check, Cash, ACH, PayPal, Venmo, Digital Wallet
  - Non-standard: Mapped to "Other" with original type in Notes (`ORIG PMT TYPE: ...`)
  - **$0 amounts: Reclassified as "In Kind"** with original type in Notes (`ORIG PMT TYPE: ...`)
  - **Consistent prefix** for both cases
- ✅ Uses Campaign Title (not Code) for auto-matching or creation
- ✅ Includes Donation Notes and Payment Description in transaction Notes
- ✅ Creates GiveButter transaction import file
- ✅ **Automatically updates mapping file** after completion (backs up current, regenerates from latest exports)
  - Use `-SkipMappingUpdate` flag to skip this step
  - Recommended to keep enabled for future imports

**Output Files**:
- `GiveButter_Transactions_Import_*.csv` ⭐ **Import this to GiveButter** (includes ALL transactions, even $0)
- `INFO_FeeAnalysis_*.csv` (fee calculation verification)
- `REVIEW_UnmatchedTransactions_*.csv` (if any unmatched)
- `Phase3_Summary_*.txt`

**⚠️ Known Limitation**:
- GiveButter's "Internal Note" field has a **255 character limit**
- Phase 3 will warn if any transactions exceed this (very rare - typically 0-1 transactions)
- You'll need to manually trim these during import

**Next Steps**:
1. Review `INFO_FeeAnalysis_*.csv` to verify fee calculations
2. Review any `REVIEW_UnmatchedTransactions_*.csv`
3. Import `GiveButter_Transactions_Import_*.csv` to GiveButter

---

## 📊 Expected Results

### **Contact Import (Phase 1A + 1B)**
Based on your actual data:
- **~2,321 individuals** (after excluding 121 converted orgs)
- **~478 companies** (357 native orgs + 121 converted from Phase 1A)
- **~45 duplicates merged** (based on NFG_Duplicate_Source)
- **121 orgs auto-converted** from individuals (includes pattern-based + high-value detection)

### **Transaction Import (Phase 3)**
Based on your actual data:
- **5,331 transactions** total
- **98.69% match rate** (5,261 matched, 70 unmatched before Phase 1B fix)
- **Expected ~99.5%+ match rate** after Phase 1B includes all converted orgs
- **56 transactions from merged duplicates** automatically linked to correct contact
- **4,857 donations** + **373 ticket purchases**

---

## ⚠️ Important Notes

### **Email Subscription Status**
- ✅ **Automatically handled** by Phase 1A
- Uses N4G "Email Subscription Status" field
- Required by GiveButter when email exists

### **Multiple Emails/Phones**
- ✅ **Supported** - Comma-separated in `Email Addresses` and `Phone Numbers` columns
- Tested with 10+ emails/phones per contact

### **Addresses & Invalid Phone Numbers**
- ⚠️ **GiveButter only supports ONE primary address**
- Additional addresses stored in `NFG_Original_and_Merged_Addresses` custom field
- **Invalid phone numbers** (international formats, etc.) also stored here with "PHONE NUMBER:" prefix
- Format: `PRIMARY: address1 | MERGED: address2 | PHONE NUMBER: +245708219128`
- This prevents import failures for contacts with invalid phone/zip formats

### **Merged Duplicates**
- ✅ All N4G IDs tracked in `NFG_Duplicate_Source` custom field
- ✅ All transactions automatically mapped to merged contact
- ✅ Earliest donor date preserved in `NFG_Original_Donor_Since`
- ✅ Combined lifetime value in `NFG_Combined_Lifetime_Value`

### **Company Point of Contact**
- ✅ Links to existing individual contacts when possible
- ✅ Auto-creates POC if not found (using POC name/email from N4G)
- ⚠️ Auto-created POCs won't have External ID (only company has it)

---

## � Utility Scripts

### **Create Mapping from GiveButter Exports**

**Purpose**: Generate `existing_givebutter_mapping.csv` from GiveButter exports for future imports.

```powershell
# Easy mode - auto-finds latest exports in reference files
.\Utility-CreateMappingFromGiveButter.ps1 -AutoFindLatest

# Or specify files manually
.\Utility-CreateMappingFromGiveButter.ps1 `
    -ContactsExportFile "reference files\givebutter-contacts-export.csv" `
    -CompaniesExportFile "reference files\givebutter-companies-export.csv"
```

**What it does:**
- ✅ Extracts all contacts/companies with `NFG_ID` from GiveButter exports
- ✅ Creates mapping file with N4G_ID → GiveButter_Contact_ID
- ✅ Handles duplicate columns automatically
- ✅ Includes both individuals and companies

**When to use:**
- After your first successful import to GiveButter
- Before re-running Phase 1A/1B to prevent duplicates
- Anytime you want to refresh the mapping from current GiveButter data

**Output:**
- `existing_givebutter_mapping.csv` - Used automatically by Phase 1A/1B

---

## �� Verification Checklist

### **After Phase 1A**
- [ ] Review all `REVIEW_*.csv` files
- [ ] Verify duplicate merge decisions
- [ ] Check organization conversions
- [ ] Verify household preservation

### **After Phase 1B**
- [ ] Review `REVIEW_CompanyPOCs_*.csv`
- [ ] Verify POC linking

### **After Phase 2**
- [ ] Verify match rate is ~100%
- [ ] Review any unmatched contacts
- [ ] Check merged duplicate mappings

### **After Phase 3**
- [ ] Review fee analysis
- [ ] Verify transaction match rate
- [ ] Check merged duplicate transaction handling

### **After GiveButter Import**
- [ ] Spot-check merged contacts (verify all emails/phones present)
- [ ] Verify custom fields populated correctly
- [ ] Check transaction totals match N4G
- [ ] Verify company POC links

---

## 🆘 Troubleshooting

### **"No matching GiveButter Contact ID found"**
- **Cause**: Contact wasn't imported in Phase 1 or Phase 2 mapping failed
- **Fix**: Check `REVIEW_Unmatched*.csv` files, manually add to mapping

### **"Import failed - standard text exceeds 255 characters"**
- **Cause**: Wrong field type (should be Long Text)
- **Fix**: Verify custom fields are correct type (see `CUSTOM_FIELDS_FINAL.md`)

### **"Email Subscription Status required"**
- **Cause**: Missing required field when email exists
- **Fix**: Phase 1A handles this automatically - check source data

### **"Last Name is required"**
- **Cause**: Individual contact missing Last Name
- **Fix**: Check `ERROR_MissingLastName_*.csv`, fix in N4G or manually add Last Name

### **Duplicate contacts created instead of merged**
- **Cause**: `-AutoMergeDuplicates` not enabled
- **Fix**: Review `REVIEW_HighConfidenceDuplicates_*.csv`, re-run with flag

### **Duplicates of existing GiveButter contacts**
- **Cause**: Pre-existing contacts not mapped
- **Fix**: Create `existing_givebutter_mapping.csv` (see `EXISTING_CONTACTS_README.md`)

---

## 📁 File Organization

```
N4G to GiveButter/
├── Phase1A-PrepareIndividuals.ps1 ⭐
├── Phase1B-PrepareCompanies.ps1 ⭐
├── Phase2-MapIDs-Enhanced.ps1 ⭐
├── Phase3-PrepareTransactions-Enhanced.ps1 ⭐
├── existing_givebutter_mapping.csv 🔧
├── CUSTOM_FIELDS_FINAL.md 📋
├── NOTES_TESTED_GIVEBUTTER_IMPORTS.md 📋
├── EXISTING_CONTACTS_README.md 📋
├── QUICK_START_PRODUCTION.md 📋 (this file)
├── README.md
├── QUICK_START.md
├── reference files/
│   ├── N4G Contact export (full).csv
│   ├── N4G Transaction export (...).csv
│   ├── contacts-2026-04-16-*.csv (GiveButter exports)
│   └── companies-2026-04-16-*.csv (GiveButter exports)
├── output/ (created by scripts)
│   ├── GiveButter_*_Import_*.csv (import files)
│   ├── REVIEW_*.csv (review files)
│   ├── INFO_*.csv (analysis files)
│   ├── Phase*_Summary_*.txt (summaries)
│   └── logs/
│       ├── Phase1A_Log_*.txt
│       ├── Phase1B_Log_*.txt
│       ├── Phase2_Log_*.txt
│       └── Phase3_Log_*.txt
└── archive/ (old versions)
```

---

## 🎯 Success Criteria

✅ **Phase 1A Complete**:
- All individuals imported to GiveButter
- Duplicates merged (if enabled)
- All 11 custom fields populated
- No import errors

✅ **Phase 1B Complete**:
- All companies imported to GiveButter
- POCs linked correctly
- No import errors

✅ **Phase 2 Complete**:
- 100% match rate (or unmatched reviewed)
- Unified lookup created
- Merged duplicates handled

✅ **Phase 3 Complete**:
- All transactions imported to GiveButter
- Fee calculations verified
- Transaction totals match N4G

---

## 📞 Support

**Documentation**:
- `CUSTOM_FIELDS_FINAL.md` - Custom field setup
- `NOTES_TESTED_GIVEBUTTER_IMPORTS.md` - Testing results and findings
- `README.md` - Original project overview

**Testing Reference**:
- All import behaviors tested April 15-16, 2026
- Test results documented in `NOTES_TESTED_GIVEBUTTER_IMPORTS.md`
- Test files archived in `archive/test_imports_corrected/`

---

**Ready to migrate!** 🚀

Start with Phase 1A and work through each phase sequentially.
