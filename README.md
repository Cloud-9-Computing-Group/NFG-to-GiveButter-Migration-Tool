# Network for Good to GiveButter Migration Tool

**Production Ready** ✅ | **Last Updated**: April 20, 2026  
**Testing Completed**: April 15-20, 2026 | **Enhanced**: April 19-20, 2026

A comprehensive PowerShell-based migration tool to transfer contact and transaction data from Network for Good (N4G) to GiveButter, with full support for duplicate merging, multiple emails/phones, company POC linking, and 11 custom fields.

## 🆕 What's New (April 19, 2026)

### **Code Review & Quality Improvements**
- ✅ **Performance**: Optimized duplicate detection (O(n) instead of O(n²))
- ✅ **Reliability**: Culture-invariant date parsing handles multiple formats
- ✅ **Data Quality**: Incomplete addresses marked with "INCOMPLETE:" prefix
- ✅ **Consistency**: Extracted constants for field limits (`$STANDARD_TEXT_LIMIT`, `$LONG_TEXT_SAFE_LIMIT`)
- ✅ **Phase 3 Auto-Run**: Mapping file update now automatic (use `-SkipMappingUpdate` to skip)
- ✅ **Cleanup**: Automatic removal of temporary `_CLEANED.csv` files in Phase 2

### **Feature Enhancements**
- ✅ **Phase 1B Enhancement**: Automatically loads converted orgs from Phase 1A OrgConversions file
- ✅ **Phone & Address Validation**: Added to Phase 1B (matches Phase 1A behavior)
- ✅ **Enhanced POC Matching**: Name → N4G ID → GiveButter ID lookup with merged duplicate support
- ✅ **Phase 2 Enhancement**: Automatic duplicate column handling in GiveButter exports
- ✅ **NEW Utility Script**: `Utility-CreateMappingFromGiveButter.ps1` - Auto-generate mapping file from GiveButter exports
- ✅ **Long Text Fields**: All custom fields properly populated for organizations
- ✅ **Documentation**: Updated all guides with new features and workflows

---

## 🚀 Quick Start

**📖 See**: `QUICK_START_PRODUCTION.md` for complete step-by-step instructions

### **⚠️ Before You Start: Do You Have Existing Data in GiveButter?**

**Brand new GiveButter tenant?** ✅ Skip to Prerequisites below

**Already have contacts in GiveButter?** ⚠️ **STOP!** Read this first:
- If you have test users, early donors, or any existing contacts in GiveButter
- If you're re-running the migration to add more data
- **You MUST create a mapping file first to prevent duplicates**

**📖 See**: `EXISTING_CONTACTS_README.md` for complete instructions

**Quick solution:**
```powershell
# Export contacts from GiveButter, then run:
.\Utility-CreateMappingFromGiveButter.ps1 -AutoFindLatest
```

---

### **Prerequisites**
1. Create 11 custom fields in GiveButter (see `CUSTOM_FIELDS_FINAL.md`)
2. Have N4G contact and transaction exports ready
3. **If you have existing GiveButter contacts**: Create mapping file (see above)

### **Migration Steps**
```powershell
# Phase 1A: Prepare Individuals
.\Phase1A-PrepareIndividuals.ps1

# Phase 1B: Prepare Companies  
.\Phase1B-PrepareCompanies.ps1

# Phase 2: Map IDs
.\Phase2-MapIDs-Enhanced.ps1

# Phase 3: Prepare Transactions
.\Phase3-PrepareTransactions-Enhanced.ps1
```

### **Utility Scripts**
```powershell
# Create mapping file from GiveButter exports (prevents duplicates on re-import)
.\Utility-CreateMappingFromGiveButter.ps1 -AutoFindLatest
```

---

## 📋 Overview

This tool automates the migration from Network4Good to GiveButter while:
- ✅ Preserving data integrity
- ✅ Detecting and merging duplicates
- ✅ Supporting multiple emails/phones per contact
- ✅ Maintaining household relationships
- ✅ Correctly calculating transaction fees
- ✅ Linking companies to Point of Contact individuals
- ✅ Tracking all data in 11 custom fields
- ✅ Providing comprehensive review files at each phase

---

## 🎯 Key Features

### **Phase 1A: Individual Contacts**
- **Last Name Validation**: Validates all individuals have Last Name (required by GiveButter)
- **Pre-Existing Contacts**: Prevents duplicates for contacts already in GiveButter with transactions
- **Organization Detection**: Identifies misclassified organizations (LLC, Inc, Foundation, etc.) and excludes them from individuals export
- **Duplicate Merging**: High-confidence duplicate detection and optional auto-merge
- **Multiple Emails/Phones**: Merges into comma-separated `Email Addresses` and `Phone Numbers` fields
- **Address Handling**: Stores all addresses in `NFG_Original_and_Merged_Addresses` custom field (GiveButter only supports 1 primary)
- **Invalid Phone Numbers**: Stores phone numbers in invalid formats (international, etc.) in `NFG_Original_and_Merged_Addresses` with "PHONE NUMBER:" prefix
- **Household Preservation**: Maintains household relationships from N4G
- **Data Quality Flags**: Flags couple names, shared emails, and other issues
- **11 Custom Fields**: Populates all custom fields with N4G data

### **Phase 1B: Company Contacts**
- **Includes Misclassified Orgs**: Automatically includes the 121 organizations that were excluded from Phase 1A
- **Point of Contact Linking**: Links companies to existing individual contacts (with full POC data from GiveButter export)
- **Auto-Create POC**: Creates POC automatically if not found
- **Custom Fields**: Populates company-specific custom fields

### **Phase 2: ID Mapping (Enhanced)**
- **Unified Lookup**: Combines individuals and companies
- **Merged Duplicate Handling**: Maps all N4G IDs (including merged ones) to GiveButter Contact IDs
- **Fuzzy Matching**: Falls back to email matching if External ID doesn't match
- **100% Match Rate**: Identifies any unmatched contacts for review

### **Phase 3: Transaction Preparation (Enhanced)**
- **Merged Duplicate Transactions**: Automatically links transactions from merged N4G IDs to correct GiveButter contact
- **Fee Calculation**: Correctly handles donor-paid vs organization-paid fees (validated 100% accurate)
- **Payment Method Mapping**: Converts N4G payment types to GiveButter-supported formats
  - Standard methods: Credit Card, Check, Cash, ACH, PayPal, Venmo, Digital Wallet, etc.
  - Non-standard methods: Mapped to "Other" with original type preserved in Notes
  - **$0 Transactions**: Automatically reclassified as "In Kind" (GiveButter requirement) with original type in Notes
- **Campaign Title Matching**: Uses campaign names (not codes) for auto-matching or creation
- **Contact Linking**: Uses unified lookup to credit correct contacts
- **Organization Support**: Properly attributes transactions to organizations
- **Fee Analysis**: Provides breakdown of fee structures
- **Notes Enhancement**: Includes Donation Notes and Payment Description for context

### **Utility: Create Mapping from GiveButter Exports**
- **Purpose**: Generate `existing_givebutter_mapping.csv` from GiveButter exports
- **Auto-Find**: Automatically locates latest exports in reference files
- **Comprehensive**: Includes both individuals and companies with NFG_ID
- **Duplicate Prevention**: Use before re-running Phase 1A/1B to prevent duplicates
- **Always Current**: Regenerate anytime from latest GiveButter data
- **See**: `EXISTING_CONTACTS_README.md` for details

---

## 📁 File Structure

```
N4G to GiveButter/
├── Phase1A-PrepareIndividuals.ps1 ⭐ Production script
├── Phase1B-PrepareCompanies.ps1 ⭐ Production script
├── Phase2-MapIDs-Enhanced.ps1 ⭐ Production script
├── Phase3-PrepareTransactions-Enhanced.ps1 ⭐ Production script
├── Utility-CreateMappingFromGiveButter.ps1 🔧 Utility script
├── QUICK_START_PRODUCTION.md 📋 Step-by-step guide
├── CUSTOM_FIELDS_FINAL.md 📋 Custom field setup
├── EXISTING_CONTACTS_README.md 📋 Mapping file guide
├── NOTES_TESTED_GIVEBUTTER_IMPORTS.md 📋 Testing results
├── README.md (this file)
├── existing_givebutter_mapping.csv 📄 Auto-generated mapping
├── reference files/
│   ├── N4G Contact export (full).csv
│   ├── N4G Transaction export (...).csv
│   └── GiveButter export templates
├── output/ (created by scripts)
│   ├── GiveButter_*_Import_*.csv (import files)
│   ├── REVIEW_*.csv (review files)
│   ├── INFO_*.csv (analysis files)
│   └── Phase*_Summary_*.txt (summaries)
└── archive/ (old versions)
```

---

## 🔧 Custom Fields (11 Total)

All custom fields must be created in GiveButter before importing:

**Standard Text (4)**:
1. `NFG_ID` - Original N4G Contact ID
2. `NFG_Type` - Individual or Organization
3. `NFG_Point_Of_Contact` - POC info for organizations
4. `NFG_Data_Quality_Flags` - Data quality issues

**Long Text (4)**:
5. `NFG_Household_Members` - Other household member names
6. `NFG_Duplicate_Source` - Comma-separated N4G IDs if merged
7. `NFG_Alternate_Contacts` - Alternate contact info
8. `NFG_Original_and_Merged_Addresses` - All addresses (primary + merged) + invalid phone numbers

**Date (2)**:
9. `NFG_Original_Donor_Since` - Earliest donation date from merged records
10. `NFG_Merge_Date` - When duplicate merge occurred

**Number (1)**:
11. `NFG_Combined_Lifetime_Value` - Sum of lifetime donations from merged records

📄 **See**: `CUSTOM_FIELDS_FINAL.md` for complete setup instructions

---

## 📊 Expected Results

Based on typical data (~2,853 contacts, ~15,000 transactions):

### **Contact Import**
- **~2,500 individuals** (after duplicate merging)
- **~350 companies**
- **~90 duplicates merged** (if auto-merge enabled)
- **~250 misclassified orgs** auto-converted

### **Transaction Import**
- **~15,000 transactions**
- **100% match rate** (if all contacts imported successfully)
- **Merged duplicate transactions** automatically linked to correct contact

---

## ✅ Testing & Validation

**All import behaviors tested April 15-20, 2026**

### **Confirmed Capabilities**:
- ✅ Multiple emails (10+ supported, comma-separated)
- ✅ Multiple phones (10+ supported, comma-separated)
- ✅ Long text fields (2000+ characters)
- ✅ Company POC auto-creation
- ✅ Upsert with Givebutter Contact ID
- ✅ Date formats (both MM/DD/YYYY and YYYY-MM-DD accepted)
- ✅ Standard text at 255 chars + Long text at 500+ chars in same record
- ✅ **Duplicate transaction detection** - GiveButter prevents re-import of same External ID + Label
  - Tested with all 5,331 transactions - 100% rejection rate on duplicate import attempt
  - Error format: "Duplicate transaction detected. A transaction with the same transaction external id (<id>) and label (<label>) already exists."

### **Known Limitations**:
- ❌ Multiple addresses NOT supported by GiveButter (workaround: custom field)
- ⚠️ External ID alone doesn't upsert (must include Givebutter Contact ID)
- ⚠️ Standard text hard limit: 255 characters (import fails if exceeded)

### **Best Practice Note**:
- 💡 **Transaction External ID Prefix**: For future migrations from other systems, consider prefixing External IDs (e.g., `N4G-<transaction_id>`) to prevent conflicts if another system uses the same transaction numbering scheme. Current implementation uses N4G transaction IDs directly, which works well for single-source migrations.

📄 **See**: `NOTES_TESTED_GIVEBUTTER_IMPORTS.md` for complete testing results

---

## 🔍 Data Quality Features

### **Duplicate Detection**
- **High-Confidence**: Same email + same name → Auto-merge option
- **Shared Emails**: Different names, same email → Flagged as family account
- **Couple Names**: Names with "&" or "and" → Flagged for review

### **Organization Detection**
- **Pattern Matching**: LLC, Inc, Foundation, Corp, etc.
- **Auto-Conversion**: Converts misclassified individuals to organizations
- **Review File**: All conversions documented for verification

### **Household Preservation**
- **Multi-Member Households**: Preserved from N4G
- **Head of Household**: Maintained in GiveButter
- **Household Members**: Stored in custom field

### **Data Quality Flags**
- `CONVERTED_TO_ORG` - Individual converted to organization
- `SHARED_EMAIL` - Multiple contacts with same email
- `COUPLE_NAME` - Joint/couple name detected
- `AUTO_MERGED` - High-confidence duplicate merged
- `POC_AUTO_CREATED` - Company POC auto-created
- `POC_FROM_ORG_EMAIL` - POC created from org email

---

## 💰 Fee Calculation Logic

**Validated 100% accurate across all donor-paid transactions**

### **Organization Paid Fee**:
```
IF "Org Transaction Fee" > 0:
  Amount = "Total Charged"
  Processing Fee = "Org Transaction Fee"
```

### **Donor Covered Fee**:
```
IF "Transaction Fee Covered" > 0:
  Amount = "Total Amount Received"
  Fee Covered = "Transaction Fee Covered"
```

📄 **See**: Phase 3 output file `INFO_FeeAnalysis_*.csv` for verification

---

## 📝 Review Files

Each phase generates review files for verification:

### **Phase 1A**:
- `REVIEW_OrgConversions_*.csv` - Organizations auto-converted
- `REVIEW_HighConfidenceDuplicates_*.csv` - Duplicates to be merged
- `REVIEW_SharedEmails_*.csv` - Family email accounts
- `REVIEW_CoupleNames_*.csv` - Joint/couple names
- `INFO_MultiMemberHouseholds_*.csv` - Household analysis

### **Phase 1B**:
- `REVIEW_CompanyPOCs_*.csv` - POC linking analysis

### **Phase 2**:
- `REVIEW_UnmatchedIndividuals_*.csv` - Unmatched individuals (if any)
- `REVIEW_UnmatchedCompanies_*.csv` - Unmatched companies (if any)

### **Phase 3**:
- `REVIEW_UnmatchedTransactions_*.csv` - Unmatched transactions (if any)
- `INFO_FeeAnalysis_*.csv` - Fee calculation verification

---

## 🆘 Troubleshooting

### **Common Issues**:

**"No matching GiveButter Contact ID found"**
- Check `REVIEW_Unmatched*.csv` files
- Verify contacts were imported in Phase 1
- Manually add to mapping if needed

**"Import failed - standard text exceeds 255 characters"**
- Verify custom fields are correct type (Long Text vs Text)
- See `CUSTOM_FIELDS_FINAL.md` for correct types

**"Last Name is required"**
- Check `ERROR_MissingLastName_*.csv`
- Fix in N4G or manually add Last Name before import

**"Email Subscription Status required"**
- Phase 1A handles this automatically
- Check N4G source data has subscription status

**Duplicate contacts created instead of merged**
- Enable `-AutoMergeDuplicates` flag in Phase 1A
- Review `REVIEW_HighConfidenceDuplicates_*.csv` first

**Duplicates of existing GiveButter contacts**
- Create `existing_givebutter_mapping.csv`
- See `EXISTING_CONTACTS_README.md` for instructions

---

## 📞 Support & Documentation

**Primary Documentation**:
- `QUICK_START_PRODUCTION.md` - Step-by-step migration guide
- `CUSTOM_FIELDS_FINAL.md` - Custom field setup instructions
- `NOTES_TESTED_GIVEBUTTER_IMPORTS.md` - Complete testing results

**Testing Reference**:
- All import behaviors tested April 15-16, 2026
- 6 comprehensive tests completed
- Test files archived in `archive/test_imports_corrected/`

---

## 🎯 Success Criteria

✅ **Migration Complete When**:
- All individuals imported to GiveButter (Phase 1A)
- All companies imported to GiveButter (Phase 1B)
- 100% ID match rate (Phase 2)
- All transactions imported to GiveButter (Phase 3)
- All 11 custom fields populated correctly
- Transaction totals match N4G
- Fee calculations verified

---

## 📅 Version History

**v2.0 - April 15, 2026** (Production)
- Split Phase 1 into 1A (Individuals) and 1B (Companies)
- Added support for multiple emails/phones
- Implemented address workaround (custom field)
- Enhanced duplicate merging
- Added company POC linking
- Implemented 11 custom fields
- Complete testing and validation

**v1.0 - April 2026** (Initial)
- Basic contact and transaction migration
- Fee calculation logic
- ID mapping

---

**Ready to migrate!** 🚀

Start with `QUICK_START_PRODUCTION.md` for step-by-step instructions.
