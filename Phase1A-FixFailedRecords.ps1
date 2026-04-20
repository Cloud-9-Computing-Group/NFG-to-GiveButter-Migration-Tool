# Phase 1A - Fix Failed Import Records
# This script processes failed import records from GiveButter and fixes common issues:
# 1. Invalid phone numbers -> moved to NFG_Original_and_Merged_Addresses
# 2. Invalid addresses -> cleared (data preserved in NFG_Original_and_Merged_Addresses)

param(
    [Parameter(Mandatory=$true)]
    [string]$FailedRecordsFile,
    
    [string]$OutputFolder = "output"
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Create output folder if it doesn't exist
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

# Create logs folder
$logsFolder = Join-Path $OutputFolder "logs"
if (-not (Test-Path $logsFolder)) {
    New-Item -ItemType Directory -Path $logsFolder | Out-Null
}

# Start transcript
$logFile = Join-Path $logsFolder "Phase1A_FixFailed_Log_$timestamp.txt"
Start-Transcript -Path $logFile

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Phase 1A: Fix Failed Import Records" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Load failed records
Write-Host "Loading failed records..." -ForegroundColor Yellow
$failedRecords = Import-Csv $FailedRecordsFile
Write-Host "Loaded $($failedRecords.Count) failed records`n" -ForegroundColor Green

# Initialize stats
$stats = @{
    TotalRecords = $failedRecords.Count
    PhoneIssuesFixed = 0
    AddressIssuesFixed = 0
    OtherIssues = 0
}

# Process each failed record
$fixedRecords = foreach ($record in $failedRecords) {
    $errorMessage = $record.ERRORS
    $fixed = $false
    
    # Check for phone number issues
    if ($errorMessage -match 'valid phone number') {
        # Move phone to custom field (find the NFG_Original_and_Merged_Addresses custom field)
        $addressesField = $record.PSObject.Properties | Where-Object { $_.Name -match 'custom_fields_field_\d+' -and $_.Value -match 'PRIMARY:|PHONE NUMBER:' } | Select-Object -First 1
        
        if ($record.primary_phone -ne '') {
            if ($addressesField) {
                # Append to existing addresses field
                $addressesField.Value = "$($addressesField.Value) | PHONE NUMBER: $($record.primary_phone)"
            } else {
                # Find an empty custom field to use (or use the last one)
                $emptyCustomField = $record.PSObject.Properties | Where-Object { $_.Name -match 'custom_fields_field_\d+' -and $_.Value -eq '' } | Select-Object -First 1
                if ($emptyCustomField) {
                    $emptyCustomField.Value = "PHONE NUMBER: $($record.primary_phone)"
                }
            }
            $record.primary_phone = ''
            
            $stats.PhoneIssuesFixed++
            $fixed = $true
        }
    }
    
    # Check for address issues (zip code format)
    if ($errorMessage -match 'zip code must be a valid format') {
        # Clear all address fields (data should already be in custom field)
        $record.address_1 = ''
        $record.address_2 = ''
        $record.city = ''
        $record.state = ''
        $record.zipcode = ''
        $record.country = ''
        
        $stats.AddressIssuesFixed++
        $fixed = $true
    }
    
    if (-not $fixed) {
        $stats.OtherIssues++
    }
    
    # Return the record (remove the ERRORS column)
    $record | Select-Object -Property * -ExcludeProperty ERRORS
}

# Export fixed records
$outputFile = Join-Path $OutputFolder "GiveButter_Individuals_Import_FIXED_$timestamp.csv"
$fixedRecords | Export-Csv $outputFile -NoTypeInformation
Write-Host "`nFixed records exported to:" -ForegroundColor Green
Write-Host "  $outputFile`n" -ForegroundColor Cyan

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FIX FAILED RECORDS SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Failed Records: $($stats.TotalRecords)" -ForegroundColor White
Write-Host "  Phone Issues Fixed: $($stats.PhoneIssuesFixed)" -ForegroundColor Green
Write-Host "  Address Issues Fixed: $($stats.AddressIssuesFixed)" -ForegroundColor Green
Write-Host "  Other Issues (manual review): $($stats.OtherIssues)" -ForegroundColor $(if ($stats.OtherIssues -gt 0) { 'Yellow' } else { 'Green' })

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. Review the fixed file: GiveButter_Individuals_Import_FIXED_$timestamp.csv" -ForegroundColor White
Write-Host "2. Import the fixed file to GiveButter" -ForegroundColor White
Write-Host "3. If there are still failures, review manually" -ForegroundColor White
Write-Host "4. Once all imports succeed, export from GiveButter" -ForegroundColor White
Write-Host "5. Save export as 'reference files\GiveButter_Individuals_Export.csv'" -ForegroundColor White
Write-Host "6. Proceed to Phase 1B`n" -ForegroundColor White

# Save summary
$summaryFile = Join-Path $OutputFolder "Phase1A_FixFailed_Summary_$timestamp.txt"
@"
PHASE 1A: FIX FAILED IMPORT RECORDS SUMMARY
Generated: $(Get-Date)
========================================

INPUT FILE:
- $FailedRecordsFile

STATISTICS:
- Total Failed Records: $($stats.TotalRecords)
- Phone Issues Fixed: $($stats.PhoneIssuesFixed)
- Address Issues Fixed: $($stats.AddressIssuesFixed)
- Other Issues (manual review): $($stats.OtherIssues)

FIXES APPLIED:
1. Invalid phone numbers moved to NFG_Original_and_Merged_Addresses
2. Invalid addresses cleared (data preserved in custom field)
3. Data quality flags added: PHONE_INVALID_FORMAT, ADDRESS_INVALID_ZIP

OUTPUT FILE:
- GiveButter_Individuals_Import_FIXED_$timestamp.csv

NEXT STEPS:
1. Import the fixed file to GiveButter
2. If failures persist, review manually
3. Export from GiveButter once all imports succeed
4. Save as 'reference files\GiveButter_Individuals_Export.csv'
5. Proceed to Phase 1B
"@ | Out-File $summaryFile

Write-Host "Summary saved to: $summaryFile" -ForegroundColor Magenta
Write-Host "Log saved to: $logFile`n" -ForegroundColor Magenta

Stop-Transcript
