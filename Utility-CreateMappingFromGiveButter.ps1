# Utility: Create N4G to GiveButter Mapping from GiveButter Exports
# This script generates a mapping file from GiveButter contact/company exports
# Use this to create/update the existing_givebutter_mapping.csv file

param(
    [string]$ContactsExportFile = "",
    [string]$CompaniesExportFile = "",
    [string]$OutputFile = "existing_givebutter_mapping.csv",
    [switch]$AutoFindLatest  # Automatically find latest exports in reference files
)

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Create Mapping from GiveButter Exports" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Auto-find latest exports if requested
if ($AutoFindLatest) {
    Write-Host "Auto-finding latest GiveButter exports..." -ForegroundColor Yellow
    
    # Find contacts export
    $contactFiles = Get-ChildItem "reference files" -Filter "*contacts*.csv" -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Name -notmatch '_CLEANED' } |
                    Sort-Object LastWriteTime -Descending
    if ($contactFiles.Count -gt 0) {
        $ContactsExportFile = $contactFiles[0].FullName
        Write-Host "  Found contacts: $($contactFiles[0].Name)" -ForegroundColor Green
    }
    
    # Find companies export
    $companyFiles = Get-ChildItem "reference files" -Filter "*companies*.csv" -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Name -notmatch '_CLEANED' } |
                    Sort-Object LastWriteTime -Descending
    if ($companyFiles.Count -gt 0) {
        $CompaniesExportFile = $companyFiles[0].FullName
        Write-Host "  Found companies: $($companyFiles[0].Name)" -ForegroundColor Green
    }
}

# Validate inputs
if ($ContactsExportFile -eq "" -or -not (Test-Path $ContactsExportFile)) {
    Write-Host "ERROR: Contacts export file not found!" -ForegroundColor Red
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\Utility-CreateMappingFromGiveButter.ps1 -AutoFindLatest" -ForegroundColor Cyan
    Write-Host "  OR" -ForegroundColor Yellow
    Write-Host "  .\Utility-CreateMappingFromGiveButter.ps1 -ContactsExportFile 'path\to\contacts.csv' -CompaniesExportFile 'path\to\companies.csv'" -ForegroundColor Cyan
    exit 1
}

Write-Host "`nLoading GiveButter exports..." -ForegroundColor Yellow

# Function to clean duplicate columns
function Get-CleanedCsv {
    param([string]$FilePath)
    
    $cleanedFile = $FilePath -replace '\.csv$', '_CLEANED.csv'
    if (Test-Path $cleanedFile) {
        return Import-Csv $cleanedFile
    }
    
    try {
        return Import-Csv $FilePath
    } catch {
        if ($_.Exception.Message -match "already present") {
            Write-Host "  Cleaning duplicate columns in $(Split-Path $FilePath -Leaf)..." -ForegroundColor Yellow
            
            $content = Get-Content $FilePath -Raw
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
            $lines | Out-File $cleanedFile -Encoding UTF8
            
            return Import-Csv $cleanedFile
        } else {
            throw
        }
    }
}

# Load contacts
$contacts = Get-CleanedCsv -FilePath $ContactsExportFile
Write-Host "  Loaded $($contacts.Count) contacts" -ForegroundColor Green

# Load companies (optional)
$companies = @()
if ($CompaniesExportFile -ne "" -and (Test-Path $CompaniesExportFile)) {
    $companies = Get-CleanedCsv -FilePath $CompaniesExportFile
    Write-Host "  Loaded $($companies.Count) companies" -ForegroundColor Green
}

# Create mapping records
Write-Host "`nCreating mapping records..." -ForegroundColor Yellow
$mappingRecords = @()
$stats = @{
    ContactsWithNFGID = 0
    ContactsWithoutNFGID = 0
    CompaniesWithNFGID = 0
    CompaniesWithoutNFGID = 0
}

# Process contacts
foreach ($contact in $contacts) {
    if ($contact.NFG_ID -ne '' -and $contact.'Givebutter Contact ID' -ne '') {
        $mappingRecords += [PSCustomObject]@{
            N4G_ID = $contact.NFG_ID
            GiveButter_Contact_ID = $contact.'Givebutter Contact ID'
            Full_Name = "$($contact.'First Name') $($contact.'Last Name')".Trim()
            Primary_Email = $contact.'Primary Email'
            Contact_Type = 'Individual'
        }
        $stats.ContactsWithNFGID++
    } else {
        $stats.ContactsWithoutNFGID++
    }
}

# Process companies
foreach ($company in $companies) {
    if ($company.NFG_ID -ne '' -and $company.'Givebutter Contact ID' -ne '') {
        $mappingRecords += [PSCustomObject]@{
            N4G_ID = $company.NFG_ID
            GiveButter_Contact_ID = $company.'Givebutter Contact ID'
            Full_Name = $company.'Company Name'
            Primary_Email = $company.'Primary Email'
            Contact_Type = 'Organization'
        }
        $stats.CompaniesWithNFGID++
    } else {
        $stats.CompaniesWithoutNFGID++
    }
}

# Backup existing mapping file if it exists
if (Test-Path $OutputFile) {
    Write-Host "`nBacking up existing mapping file..." -ForegroundColor Yellow
    
    # Create backup folder if it doesn't exist
    $backupFolder = "backup"
    if (-not (Test-Path $backupFolder)) {
        New-Item -ItemType Directory -Path $backupFolder | Out-Null
    }
    
    # Create backup with timestamp
    $backupTimestamp = (Get-Item $OutputFile).LastWriteTime.ToString("yyyyMMdd_HHmmss")
    $backupFile = Join-Path $backupFolder "existing_givebutter_mapping_BACKUP_$backupTimestamp.csv"
    
    Copy-Item $OutputFile $backupFile
    Write-Host "  Backed up to: $backupFile" -ForegroundColor Green
}

# Export mapping file
Write-Host "`nExporting mapping file..." -ForegroundColor Yellow
$mappingRecords | Export-Csv $OutputFile -NoTypeInformation
Write-Host "  Saved to: $OutputFile" -ForegroundColor Green

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Contacts:" -ForegroundColor Yellow
Write-Host "  With NFG_ID: $($stats.ContactsWithNFGID)" -ForegroundColor Green
Write-Host "  Without NFG_ID: $($stats.ContactsWithoutNFGID)" -ForegroundColor $(if ($stats.ContactsWithoutNFGID -gt 0) { 'Yellow' } else { 'Green' })

if ($companies.Count -gt 0) {
    Write-Host "`nCompanies:" -ForegroundColor Yellow
    Write-Host "  With NFG_ID: $($stats.CompaniesWithNFGID)" -ForegroundColor Green
    Write-Host "  Without NFG_ID: $($stats.CompaniesWithoutNFGID)" -ForegroundColor $(if ($stats.CompaniesWithoutNFGID -gt 0) { 'Yellow' } else { 'Green' })
}

Write-Host "`nTotal Mappings Created: $($mappingRecords.Count)" -ForegroundColor Cyan

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. Review $OutputFile" -ForegroundColor Yellow
Write-Host "2. This file will be automatically used by Phase 1A/1B" -ForegroundColor Yellow
Write-Host "3. Re-run this script anytime you export from GiveButter" -ForegroundColor Yellow
Write-Host ""

Write-Host "NOTE: Contacts without NFG_ID are likely auto-created POCs" -ForegroundColor Gray
Write-Host "      from company imports. They don't need to be in the mapping." -ForegroundColor Gray
Write-Host ""
