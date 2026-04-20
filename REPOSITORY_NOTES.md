# 📦 Repository Structure & Privacy

## 🔒 What's Protected (Not Committed)

The `.gitignore` file protects all sensitive donor and transaction data:

### **Folders (Completely Ignored)**
- `/output/` - Contains processed donor data ready for import
- `/archive/` - Contains old test files with real data
- `/backup/` - Contains backup copies of mapping files

### **Files (Ignored)**
- `existing_givebutter_mapping.csv` - Contains real GiveButter Contact IDs
- `/reference files/*.csv` - All CSV files with real donor/transaction data
  - **Exception**: Files with `EXAMPLE` or `TEMPLATE` in the name are included

### **Logs (Ignored)**
- `*.txt` - PowerShell transcript logs (may contain sensitive data)

---

## ✅ What's Included (Safe to Commit)

### **Scripts (6 files)**
- `Phase1A-PrepareIndividuals.ps1`
- `Phase1B-PrepareCompanies.ps1`
- `Phase2-MapIDs-Enhanced.ps1`
- `Phase3-PrepareTransactions-Enhanced.ps1`
- `Utility-CreateMappingFromGiveButter.ps1`
- `CleanupOldFiles.ps1`
- `Phase1A-FixFailedRecords.ps1` (utility)

### **Documentation (6 files)**
- `README.md` - Main project overview
- `QUICK_START_PRODUCTION.md` - Step-by-step guide
- `CUSTOM_FIELDS_FINAL.md` - GiveButter custom field setup
- `EXISTING_CONTACTS_README.md` - Handling pre-existing contacts
- `NOTES_TESTED_GIVEBUTTER_IMPORTS.md` - Testing documentation
- `SESSION_SUMMARY.md` - Development summary

### **Example Files**
- `existing_givebutter_mapping_EXAMPLE.csv` - Anonymized example
- Any other files with `EXAMPLE` or `TEMPLATE` in the name

### **Configuration**
- `.gitignore` - Protects sensitive data

---

## 🚀 Before Making Repository Public

### **1. Verify No Sensitive Data**
```powershell
# Check what would be committed
cd "C:\Users\rob\Projects\git take 2\N4G-to-GiveButter"
git status
git add .
git status
```

### **2. Review These Files Manually**
- [ ] Check all `.md` files for real names/emails/IDs
- [ ] Verify example CSV files are anonymized
- [ ] Confirm no real GiveButter Contact IDs in docs
- [ ] Check script comments for sensitive info

### **3. Safe to Share**
The following are safe and contain no sensitive data:
- ✅ All PowerShell scripts (no hardcoded data)
- ✅ Documentation files (generic examples)
- ✅ Example CSV file (anonymized)
- ✅ Custom fields documentation (field definitions only)

---

## 📝 Recommended Repository Description

**Title**: Network for Good to GiveButter Migration Tool

**Description**:
> Production-ready PowerShell migration tool to transfer contacts and transactions from Network for Good to GiveButter. Includes duplicate detection, custom field mapping, fee handling, and comprehensive documentation. Tested with 5,331 transactions and 2,800+ contacts.

**Topics/Tags**:
- `givebutter`
- `network-for-good`
- `migration-tool`
- `powershell`
- `nonprofit`
- `donor-management`
- `data-migration`

---

## 🔐 Security Checklist

Before pushing to public repository:

- [ ] `.gitignore` is in place
- [ ] No `/output/` folder committed
- [ ] No `/archive/` folder committed
- [ ] No `/backup/` folder committed
- [ ] No real CSV files in `/reference files/`
- [ ] Only `*EXAMPLE*.csv` files included
- [ ] No `existing_givebutter_mapping.csv` (only `*_EXAMPLE.csv`)
- [ ] No `.txt` log files
- [ ] All documentation reviewed for sensitive data
- [ ] Example files use anonymized data (fake names/emails)

---

## 📂 Folder Structure (Public View)

```
N4G-to-GiveButter/
├── .gitignore
├── README.md
├── QUICK_START_PRODUCTION.md
├── CUSTOM_FIELDS_FINAL.md
├── EXISTING_CONTACTS_README.md
├── NOTES_TESTED_GIVEBUTTER_IMPORTS.md
├── SESSION_SUMMARY.md
├── REPOSITORY_NOTES.md (this file)
├── Phase1A-PrepareIndividuals.ps1
├── Phase1B-PrepareCompanies.ps1
├── Phase2-MapIDs-Enhanced.ps1
├── Phase3-PrepareTransactions-Enhanced.ps1
├── Utility-CreateMappingFromGiveButter.ps1
├── CleanupOldFiles.ps1
├── Phase1A-FixFailedRecords.ps1
├── existing_givebutter_mapping_EXAMPLE.csv
└── reference files/
    └── (example files only - real CSVs ignored)
```

**Note**: `/output/`, `/archive/`, and `/backup/` folders exist locally but are not committed to the repository.
