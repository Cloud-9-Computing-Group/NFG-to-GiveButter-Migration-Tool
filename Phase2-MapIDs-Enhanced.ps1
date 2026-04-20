# Phase 2: Map Network4Good IDs to GiveButter Contact IDs
# Enhanced version - handles individuals, companies, and merged duplicates
# Run this AFTER importing contacts to GiveButter and exporting them with their new IDs

param(
    [string]$IndividualMappingFile = "",  # From Phase 1A
    [string]$CompanyMappingFile = "",  # From Phase 1B
    [string]$GiveButterContactsExport = "",  # Individual contacts export from GiveButter
    [string]$GiveButterCompaniesExport = "",  # Companies export from GiveButter
    [string]$OutputFolder = "output"
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Create logs folder
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}
$logsFolder = Join-Path $OutputFolder "logs"
if (-not (Test-Path $logsFolder)) {
    New-Item -ItemType Directory -Path $logsFolder | Out-Null
}

# Start transcript logging
$logFile = Join-Path $logsFolder "Phase2_Log_$timestamp.txt"
Start-Transcript -Path $logFile -Append

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Phase 2: ID Mapping (Enhanced)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Find most recent mapping files if not specified
if ($IndividualMappingFile -eq "") {
    $mappingFiles = Get-ChildItem $OutputFolder -Filter "N4G_to_GiveButter_Mapping_Individuals_*.csv" | Sort-Object LastWriteTime -Descending
    if ($mappingFiles.Count -eq 0) {
        Write-Host "ERROR: No individual mapping file found. Please run Phase 1A first." -ForegroundColor Red
        exit 1
    }
    $IndividualMappingFile = $mappingFiles[0].FullName
    Write-Host "Using individual mapping file: $($mappingFiles[0].Name)" -ForegroundColor Yellow
}

if ($CompanyMappingFile -eq "") {
    $mappingFiles = Get-ChildItem $OutputFolder -Filter "N4G_to_GiveButter_Mapping_Companies_*.csv" | Sort-Object LastWriteTime -Descending
    if ($mappingFiles.Count -gt 0) {
        $CompanyMappingFile = $mappingFiles[0].FullName
        Write-Host "Using company mapping file: $($mappingFiles[0].Name)" -ForegroundColor Yellow
    }
    else {
        Write-Host "WARNING: No company mapping file found. Skipping companies." -ForegroundColor Yellow
        Write-Host "         Run Phase 1B if you have organizations to import.`n" -ForegroundColor Gray
    }
}

# Prompt for GiveButter exports if not specified
if ($GiveButterContactsExport -eq "") {
    Write-Host "`nPlease provide the GiveButter CONTACTS export file:" -ForegroundColor Yellow
    Write-Host "1. Go to GiveButter → Contacts → Export" -ForegroundColor Cyan
    Write-Host "2. Download the CSV with all contact fields" -ForegroundColor Cyan
    Write-Host "3. Enter the full path to that file:`n" -ForegroundColor Cyan
    $GiveButterContactsExport = Read-Host "Contacts file path"
    
    if (-not (Test-Path $GiveButterContactsExport)) {
        Write-Host "ERROR: File not found: $GiveButterContactsExport" -ForegroundColor Red
        exit 1
    }
}

if ($CompanyMappingFile -ne "" -and $GiveButterCompaniesExport -eq "") {
    Write-Host "`nPlease provide the GiveButter COMPANIES export file:" -ForegroundColor Yellow
    Write-Host "1. Go to GiveButter → Companies → Export" -ForegroundColor Cyan
    Write-Host "2. Download the CSV with all company fields" -ForegroundColor Cyan
    Write-Host "3. Enter the full path to that file:`n" -ForegroundColor Cyan
    $GiveButterCompaniesExport = Read-Host "Companies file path"
    
    if ($GiveButterCompaniesExport -ne "" -and -not (Test-Path $GiveButterCompaniesExport)) {
        Write-Host "ERROR: File not found: $GiveButterCompaniesExport" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`nLoading data..." -ForegroundColor Yellow

# Load mapping files
$individualMapping = Import-Csv $IndividualMappingFile
Write-Host "  Individual Mapping Records: $($individualMapping.Count)" -ForegroundColor Green

$companyMapping = @()
if ($CompanyMappingFile -ne "" -and (Test-Path $CompanyMappingFile)) {
    $companyMapping = Import-Csv $CompanyMappingFile
    Write-Host "  Company Mapping Records: $($companyMapping.Count)" -ForegroundColor Green
}

# Load GiveButter exports (handle duplicate columns)
Write-Host "`nLoading GiveButter exports..." -ForegroundColor Yellow

# Clean contacts export if needed
$cleanedContactsFile = $GiveButterContactsExport -replace '\.csv$', '_CLEANED.csv'
if (Test-Path $cleanedContactsFile) {
    Write-Host "Using existing cleaned contacts file" -ForegroundColor Cyan
    $gbContacts = Import-Csv $cleanedContactsFile
} else {
    try {
        $gbContacts = Import-Csv $GiveButterContactsExport
    } catch {
        if ($_.Exception.Message -match "already present") {
            Write-Host "Duplicate columns detected in contacts export. Creating cleaned version..." -ForegroundColor Yellow
            
            $content = Get-Content $GiveButterContactsExport -Raw
            $lines = $content -split "`r?`n"
            $header = $lines[0]
            
            $columns = $header -split ','
            $seen = @{}
            $newColumns = foreach ($col in $columns) {
                $cleanCol = $col.Trim('"')
                if ($seen.ContainsKey($cleanCol)) {
                    $seen[$cleanCol]++
                    "`"$cleanCol`_$($seen[$cleanCol])`""
                } else {
                    $seen[$cleanCol] = 1
                    $col
                }
            }
            
            $lines[0] = $newColumns -join ','
            $lines | Out-File $cleanedContactsFile -Encoding UTF8
            
            Write-Host "Created cleaned file: $cleanedContactsFile" -ForegroundColor Green
            $gbContacts = Import-Csv $cleanedContactsFile
        } else {
            throw
        }
    }
}
Write-Host "  GiveButter Contacts: $($gbContacts.Count)" -ForegroundColor Green

# Clean companies export if needed
$gbCompanies = @()
if ($GiveButterCompaniesExport -ne "" -and (Test-Path $GiveButterCompaniesExport)) {
    $cleanedCompaniesFile = $GiveButterCompaniesExport -replace '\.csv$', '_CLEANED.csv'
    if (Test-Path $cleanedCompaniesFile) {
        Write-Host "Using existing cleaned companies file" -ForegroundColor Cyan
        $gbCompanies = Import-Csv $cleanedCompaniesFile
    } else {
        try {
            $gbCompanies = Import-Csv $GiveButterCompaniesExport
        } catch {
            if ($_.Exception.Message -match "already present") {
                Write-Host "Duplicate columns detected in companies export. Creating cleaned version..." -ForegroundColor Yellow
                
                $content = Get-Content $GiveButterCompaniesExport -Raw
                $lines = $content -split "`r?`n"
                $header = $lines[0]
                
                $columns = $header -split ','
                $seen = @{}
                $newColumns = foreach ($col in $columns) {
                    $cleanCol = $col.Trim('"')
                    if ($seen.ContainsKey($cleanCol)) {
                        $seen[$cleanCol]++
                        "`"$cleanCol`_$($seen[$cleanCol])`""
                    } else {
                        $seen[$cleanCol] = 1
                        $col
                    }
                }
                
                $lines[0] = $newColumns -join ','
                $lines | Out-File $cleanedCompaniesFile -Encoding UTF8
                
                Write-Host "Created cleaned file: $cleanedCompaniesFile" -ForegroundColor Green
                $gbCompanies = Import-Csv $cleanedCompaniesFile
            } else {
                throw
            }
        }
    }
    Write-Host "  GiveButter Companies: $($gbCompanies.Count)" -ForegroundColor Green
}

# Initialize stats
$stats = @{
    IndividualsMatched = 0
    IndividualsUnmatched = 0
    CompaniesMatched = 0
    CompaniesUnmatched = 0
    MergedDuplicatesDetected = 0
}

# Match individuals
Write-Host "`nMatching individual contacts..." -ForegroundColor Yellow
$unmatchedIndividuals = @()

foreach ($n4gRecord in $individualMapping) {
    # Try to find matching GiveButter contact by External ID or NFG_ID custom field
    $gbContact = $gbContacts | Where-Object { 
        $_.'Contact External ID' -eq $n4gRecord.N4G_ID -or
        $_.NFG_ID -eq $n4gRecord.N4G_ID
    } | Select-Object -First 1
    
    if ($gbContact) {
        # Update the mapping with GiveButter Contact ID
        $n4gRecord.GiveButter_Contact_ID = $gbContact.'Givebutter Contact ID'
        $n4gRecord.Import_Status = 'Matched'
        $n4gRecord.Import_Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $stats.IndividualsMatched++
        
        # Check if this contact has merged duplicates (NFG_Duplicate_Source will have multiple IDs)
        if ($gbContact.NFG_Duplicate_Source -match ',') {
            $stats.MergedDuplicatesDetected++
            $n4gRecord.Notes = "Contains merged duplicates: $($gbContact.NFG_Duplicate_Source)"
        }
    }
    else {
        # Try fuzzy matching by email
        if ($n4gRecord.Primary_Email -ne '') {
            $gbContact = $gbContacts | Where-Object { 
                $_.'Primary Email' -eq $n4gRecord.Primary_Email -or
                $_.'Additional Emails' -match [regex]::Escape($n4gRecord.Primary_Email)
            } | Select-Object -First 1
            
            if ($gbContact) {
                $n4gRecord.GiveButter_Contact_ID = $gbContact.'Givebutter Contact ID'
                $n4gRecord.Import_Status = 'Matched-ByEmail'
                $n4gRecord.Import_Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $n4gRecord.Notes = "Matched by email, not External ID"
                $stats.IndividualsMatched++
            }
            else {
                $n4gRecord.Import_Status = 'Unmatched'
                $stats.IndividualsUnmatched++
                $unmatchedIndividuals += $n4gRecord
            }
        }
        else {
            $n4gRecord.Import_Status = 'Unmatched'
            $stats.IndividualsUnmatched++
            $unmatchedIndividuals += $n4gRecord
        }
    }
}

Write-Host "  Matched: $($stats.IndividualsMatched)" -ForegroundColor Green
Write-Host "  Unmatched: $($stats.IndividualsUnmatched)" -ForegroundColor $(if ($stats.IndividualsUnmatched -gt 0) { 'Yellow' } else { 'Green' })
if ($stats.MergedDuplicatesDetected -gt 0) {
    Write-Host "  Merged Duplicates Detected: $($stats.MergedDuplicatesDetected)" -ForegroundColor Cyan
}

# Match companies
$unmatchedCompanies = @()
if ($companyMapping.Count -gt 0) {
    Write-Host "`nMatching company contacts..." -ForegroundColor Yellow
    
    foreach ($n4gRecord in $companyMapping) {
        # Try to find matching GiveButter company by External ID or NFG_ID custom field
        $gbCompany = $gbCompanies | Where-Object { 
            $_.'Contact External ID' -eq $n4gRecord.N4G_ID -or
            $_.NFG_ID -eq $n4gRecord.N4G_ID
        } | Select-Object -First 1
        
        if ($gbCompany) {
            # Update the mapping with GiveButter Contact ID
            $n4gRecord.GiveButter_Contact_ID = $gbCompany.'Givebutter Contact ID'
            $n4gRecord.Import_Status = 'Matched'
            $n4gRecord.Import_Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $stats.CompaniesMatched++
        }
        else {
            # Try fuzzy matching by company name and email
            if ($n4gRecord.Primary_Email -ne '') {
                $gbCompany = $gbCompanies | Where-Object { 
                    $_.'Primary Email' -eq $n4gRecord.Primary_Email
                } | Select-Object -First 1
                
                if ($gbCompany) {
                    $n4gRecord.GiveButter_Contact_ID = $gbCompany.'Givebutter Contact ID'
                    $n4gRecord.Import_Status = 'Matched-ByEmail'
                    $n4gRecord.Import_Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $n4gRecord.Notes = "Matched by email, not External ID"
                    $stats.CompaniesMatched++
                }
                else {
                    $n4gRecord.Import_Status = 'Unmatched'
                    $stats.CompaniesUnmatched++
                    $unmatchedCompanies += $n4gRecord
                }
            }
            else {
                $n4gRecord.Import_Status = 'Unmatched'
                $stats.CompaniesUnmatched++
                $unmatchedCompanies += $n4gRecord
            }
        }
    }
    
    Write-Host "  Matched: $($stats.CompaniesMatched)" -ForegroundColor Green
    Write-Host "  Unmatched: $($stats.CompaniesUnmatched)" -ForegroundColor $(if ($stats.CompaniesUnmatched -gt 0) { 'Yellow' } else { 'Green' })
}

# Save updated mappings
Write-Host "`nSaving updated mappings..." -ForegroundColor Yellow

$updatedIndividualMappingFile = "$OutputFolder\N4G_to_GiveButter_Mapping_Individuals_UPDATED_$timestamp.csv"
$individualMapping | Export-Csv $updatedIndividualMappingFile -NoTypeInformation
Write-Host "  Individual mapping: $updatedIndividualMappingFile" -ForegroundColor Green

if ($companyMapping.Count -gt 0) {
    $updatedCompanyMappingFile = "$OutputFolder\N4G_to_GiveButter_Mapping_Companies_UPDATED_$timestamp.csv"
    $companyMapping | Export-Csv $updatedCompanyMappingFile -NoTypeInformation
    Write-Host "  Company mapping: $updatedCompanyMappingFile" -ForegroundColor Green
}

# Save unmatched records for review
if ($stats.IndividualsUnmatched -gt 0) {
    $unmatchedFile = "$OutputFolder\REVIEW_UnmatchedIndividuals_$timestamp.csv"
    $unmatchedIndividuals | Export-Csv $unmatchedFile -NoTypeInformation
    Write-Host "  Unmatched individuals: $unmatchedFile" -ForegroundColor Yellow
}

if ($stats.CompaniesUnmatched -gt 0) {
    $unmatchedFile = "$OutputFolder\REVIEW_UnmatchedCompanies_$timestamp.csv"
    $unmatchedCompanies | Export-Csv $unmatchedFile -NoTypeInformation
    Write-Host "  Unmatched companies: $unmatchedFile" -ForegroundColor Yellow
}

# Create unified lookup file for Phase 3
Write-Host "`nCreating unified ID lookup for Phase 3..." -ForegroundColor Yellow

# Combine individuals and companies
$allMappings = @()
$allMappings += $individualMapping | Where-Object { $_.Import_Status -like 'Matched*' }
if ($companyMapping.Count -gt 0) {
    $allMappings += $companyMapping | Where-Object { $_.Import_Status -like 'Matched*' }
}

# Create quick lookup with merged duplicate handling
$quickLookup = @()
foreach ($mapping in $allMappings) {
    # Add primary mapping
    $quickLookup += [PSCustomObject]@{
        N4G_Donor_ID = $mapping.N4G_ID
        GiveButter_Contact_ID = $mapping.GiveButter_Contact_ID
        Contact_Name = $mapping.Full_Name
        Contact_Type = $mapping.N4G_Type
        Is_Merged = 'No'
        Notes = $mapping.Notes
    }
    
    # If this contact has merged duplicates, add mappings for those IDs too
    if ($mapping.Notes -match 'merged duplicates: (.+)') {
        $mergedIDs = $matches[1] -split ',\s*'
        foreach ($mergedID in $mergedIDs) {
            if ($mergedID -ne $mapping.N4G_ID) {
                $quickLookup += [PSCustomObject]@{
                    N4G_Donor_ID = $mergedID.Trim()
                    GiveButter_Contact_ID = $mapping.GiveButter_Contact_ID
                    Contact_Name = $mapping.Full_Name
                    Contact_Type = $mapping.N4G_Type
                    Is_Merged = 'Yes'
                    Notes = "Merged into $($mapping.N4G_ID)"
                }
            }
        }
    }
}

$lookupFile = "$OutputFolder\ID_Lookup_Unified_ForPhase3_$timestamp.csv"
$quickLookup | Export-Csv $lookupFile -NoTypeInformation
Write-Host "  Unified lookup: $lookupFile" -ForegroundColor Green
Write-Host "  Total mappings (including merged): $($quickLookup.Count)" -ForegroundColor Cyan

# Summary
$totalRecords = $individualMapping.Count + $companyMapping.Count
$totalMatched = $stats.IndividualsMatched + $stats.CompaniesMatched
$totalUnmatched = $stats.IndividualsUnmatched + $stats.CompaniesUnmatched

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PHASE 2 SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Records: $totalRecords" -ForegroundColor White
Write-Host "  Individuals: $($individualMapping.Count)" -ForegroundColor White
Write-Host "  Companies: $($companyMapping.Count)" -ForegroundColor White

Write-Host "`nMatching Results:" -ForegroundColor Yellow
Write-Host "  Successfully Matched: $totalMatched ($([math]::Round(($totalMatched/$totalRecords)*100, 2))%)" -ForegroundColor Green
Write-Host "    Individuals: $($stats.IndividualsMatched)" -ForegroundColor White
Write-Host "    Companies: $($stats.CompaniesMatched)" -ForegroundColor White
Write-Host "  Unmatched: $totalUnmatched ($([math]::Round(($totalUnmatched/$totalRecords)*100, 2))%)" -ForegroundColor $(if ($totalUnmatched -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "    Individuals: $($stats.IndividualsUnmatched)" -ForegroundColor White
Write-Host "    Companies: $($stats.CompaniesUnmatched)" -ForegroundColor White

if ($stats.MergedDuplicatesDetected -gt 0) {
    Write-Host "`nMerged Duplicates:" -ForegroundColor Yellow
    Write-Host "  Contacts with Merged Duplicates: $($stats.MergedDuplicatesDetected)" -ForegroundColor Cyan
    Write-Host "  Total ID Mappings Created: $($quickLookup.Count)" -ForegroundColor Cyan
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
if ($totalUnmatched -gt 0) {
    Write-Host "1. Review REVIEW_Unmatched*.csv files" -ForegroundColor Yellow
    Write-Host "2. Manually update the mapping files if needed" -ForegroundColor Yellow
    Write-Host "3. Run Phase 3 to prepare transaction imports" -ForegroundColor Yellow
}
else {
    Write-Host "1. All contacts matched successfully!" -ForegroundColor Green
    Write-Host "2. Run Phase 3 to prepare transaction imports" -ForegroundColor Yellow
}
Write-Host ""

# Save summary
$summaryFile = "$OutputFolder\Phase2_Summary_$timestamp.txt"
@"
PHASE 2 ID MAPPING SUMMARY (ENHANCED)
Generated: $(Get-Date)
========================================

STATISTICS:
- Total Records: $totalRecords
  - Individuals: $($individualMapping.Count)
  - Companies: $($companyMapping.Count)

MATCHING RESULTS:
- Successfully Matched: $totalMatched ($([math]::Round(($totalMatched/$totalRecords)*100, 2))%)
  - Individuals: $($stats.IndividualsMatched)
  - Companies: $($stats.CompaniesMatched)
- Unmatched: $totalUnmatched ($([math]::Round(($totalUnmatched/$totalRecords)*100, 2))%)
  - Individuals: $($stats.IndividualsUnmatched)
  - Companies: $($stats.CompaniesUnmatched)

MERGED DUPLICATES:
- Contacts with Merged Duplicates: $($stats.MergedDuplicatesDetected)
- Total ID Mappings Created: $($quickLookup.Count)

FILES CREATED:
- Individual Mapping: $updatedIndividualMappingFile
$(if ($companyMapping.Count -gt 0) { "- Company Mapping: $updatedCompanyMappingFile" } else { "" })
- Unified Lookup: $lookupFile
$(if ($stats.IndividualsUnmatched -gt 0) { "- Unmatched Individuals: REVIEW_UnmatchedIndividuals_$timestamp.csv" } else { "" })
$(if ($stats.CompaniesUnmatched -gt 0) { "- Unmatched Companies: REVIEW_UnmatchedCompanies_$timestamp.csv" } else { "" })

NEXT STEPS:
$(if ($totalUnmatched -gt 0) { 
"1. Review unmatched records
2. Manually update mapping if needed
3. Run Phase 3" 
} else { 
"1. All contacts matched!
2. Run Phase 3 to prepare transactions" 
})
"@ | Out-File $summaryFile

Write-Host "Summary saved to: $summaryFile" -ForegroundColor Green
Write-Host "Log saved to: $logFile" -ForegroundColor Green
Write-Host ""

# Cleanup temporary _CLEANED.csv files
Write-Host "Cleaning up temporary files..." -ForegroundColor Gray
$cleanedFiles = @()
if (Test-Path $cleanedContactsFile) { $cleanedFiles += $cleanedContactsFile }
if ($cleanedCompaniesFile -ne "" -and (Test-Path $cleanedCompaniesFile)) { $cleanedFiles += $cleanedCompaniesFile }

if ($cleanedFiles.Count -gt 0) {
    foreach ($file in $cleanedFiles) {
        Remove-Item $file -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Removed $($cleanedFiles.Count) temporary _CLEANED.csv file(s)" -ForegroundColor Gray
}
Write-Host ""

# Stop transcript logging
Stop-Transcript
