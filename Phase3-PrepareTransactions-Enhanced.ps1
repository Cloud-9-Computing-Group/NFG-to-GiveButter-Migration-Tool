# Phase 3: Prepare Transactions for GiveButter Import
# Enhanced version - uses unified lookup and correct column names
# Based on testing completed April 15-16, 2026

param(
    [string]$TransactionFile = "N4G Transaction export.csv",
    [string]$IDLookupFile = "",  # From Phase 2 (unified lookup)
    [string]$OutputFolder = "output",
    [string]$DefaultCampaignTitle = "General Donations"  # Default campaign if not mapped
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$importDate = Get-Date -Format "yyyy-MM-dd"
$externalLabel = "N4G $importDate"  # Customize with your organization name if desired

# Create logs folder
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}
$logsFolder = Join-Path $OutputFolder "logs"
if (-not (Test-Path $logsFolder)) {
    New-Item -ItemType Directory -Path $logsFolder | Out-Null
}

# Start transcript logging
$logFile = Join-Path $logsFolder "Phase3_Log_$timestamp.txt"
Start-Transcript -Path $logFile -Append

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Phase 3: Transaction Preparation (Enhanced)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Find the most recent unified ID lookup file if not specified
if ($IDLookupFile -eq "") {
    $lookupFiles = Get-ChildItem $OutputFolder -Filter "ID_Lookup_Unified_ForPhase3_*.csv" | Sort-Object LastWriteTime -Descending
    if ($lookupFiles.Count -eq 0) {
        Write-Host "ERROR: No unified ID lookup file found. Please run Phase 2 first." -ForegroundColor Red
        exit 1
    }
    $IDLookupFile = $lookupFiles[0].FullName
    Write-Host "Using ID lookup file: $($lookupFiles[0].Name)" -ForegroundColor Yellow
}

Write-Host "`nLoading data..." -ForegroundColor Yellow
$transactions = Import-Csv $TransactionFile
$idLookup = Import-Csv $IDLookupFile

# Create hashtable for fast lookup (handles merged duplicates)
$lookupTable = @{}
foreach ($record in $idLookup) {
    $lookupTable[$record.N4G_Donor_ID] = @{
        GiveButter_Contact_ID = $record.GiveButter_Contact_ID
        Contact_Name = $record.Contact_Name
        Contact_Type = $record.Contact_Type
        Is_Merged = $record.Is_Merged
    }
}

Write-Host "  Transactions: $($transactions.Count)" -ForegroundColor Green
Write-Host "  ID Mappings: $($idLookup.Count)" -ForegroundColor Green

# Statistics
$stats = @{
    Total = $transactions.Count
    Matched = 0
    Unmatched = 0
    Organizations = 0
    Individuals = 0
    DonorPaidFees = 0
    OrgPaidFees = 0
    Donations = 0
    TicketPurchases = 0
    MergedDuplicateTransactions = 0
}

Write-Host "`nProcessing transactions..." -ForegroundColor Yellow

$processedTransactions = @()
$unmatchedTransactions = @()
$feeAnalysis = @()

foreach ($txn in $transactions) {
    $donorId = $txn.'Donor/Purchaser Id'
    $lookupInfo = $lookupTable[$donorId]
    
    if (-not $lookupInfo) {
        $unmatchedTransactions += [PSCustomObject]@{
            Transaction_ID = $txn.Id
            N4G_Donor_ID = $donorId
            Donor_Name = $txn.'Full Name'
            Amount = $txn.Amount
            Date = $txn.'Donation Date'
            Type = $txn.Type
            Campaign = $txn.'Campaign/Event'
            Reason = "No matching GiveButter Contact ID found"
        }
        $stats.Unmatched++
        continue
    }
    
    $stats.Matched++
    
    # Track if this transaction is from a merged duplicate
    if ($lookupInfo.Is_Merged -eq 'Yes') {
        $stats.MergedDuplicateTransactions++
    }
    
    # Track statistics
    if ($txn.'Donor/Purchaser Type' -eq 'Organization') { $stats.Organizations++ }
    else { $stats.Individuals++ }
    
    if ($txn.Type -eq 'Donation') { $stats.Donations++ }
    elseif ($txn.Type -eq 'Ticket Purchase') { $stats.TicketPurchases++ }
    
    # Calculate fees based on validated logic:
    # If "Org Transaction Fee" (col 32) has a value:
    #   - Amount = "Total Charged" (col 31)
    #   - Processing Fee = "Org Transaction Fee" (col 32)
    # If "Transaction Fee Covered" (col 30) has a value:
    #   - Amount = "Total Amount Received" (col 33)
    #   - Fee Covered = "Transaction Fee Covered" (col 30)
    
    $amount = ""
    $processingFee = ""
    $feeCovered = ""
    $feeType = ""
    
    $orgFee = $txn.'Org Transaction Fee'
    $donorFeeCovered = $txn.'Transaction Fee Covered'
    $totalCharged = $txn.'Total Charged'
    $totalReceived = $txn.'Total Amount Received'
    
    # Clean currency values (remove $, commas, and convert to decimal)
    $orgFee = if ($orgFee) { $orgFee -replace '[\$,]', '' } else { '0' }
    $donorFeeCovered = if ($donorFeeCovered) { $donorFeeCovered -replace '[\$,]', '' } else { '0' }
    $totalCharged = if ($totalCharged) { $totalCharged -replace '[\$,]', '' } else { '0' }
    $totalReceived = if ($totalReceived) { $totalReceived -replace '[\$,]', '' } else { '0' }
    
    # Also clean the raw amount field in case we need it
    $rawAmount = if ($txn.Amount) { $txn.Amount -replace '[\$,]', '' } else { '0' }
    
    if ([decimal]$orgFee -gt 0) {
        # Organization paid the fee - amount is what org received (donation minus fee)
        $amount = if ($totalReceived -and [decimal]$totalReceived -gt 0) { $totalReceived } else { $rawAmount }
        $processingFee = $orgFee
        $feeCovered = ""
        $feeType = "Org Paid"
        $stats.OrgPaidFees++
    }
    elseif ([decimal]$donorFeeCovered -gt 0) {
        # Donor covered the fee - amount is donation only (NOT including fee donor paid)
        # GiveButter docs: "Amount – amount donated, not including transaction or platform fees"
        # GiveButter docs: "Fee Covered – cannot be more than Platform Fee + Processing Fee"
        # So we must provide BOTH processing_fee AND fee_covered
        $amount = if ($totalReceived -and [decimal]$totalReceived -gt 0) { $totalReceived } else { $rawAmount }
        $processingFee = $donorFeeCovered  # The fee amount
        $feeCovered = $donorFeeCovered     # The fee the donor covered (same value)
        $feeType = "Donor Covered"
        $stats.DonorPaidFees++
    }
    else {
        # No fees (or both are zero) - use raw amount as fallback
        $amount = if ($totalReceived -and [decimal]$totalReceived -gt 0) { $totalReceived } else { $rawAmount }
        $processingFee = ""
        $feeCovered = ""
        $feeType = "No Fee"
    }
    
    # Track fee analysis
    $feeAnalysis += [PSCustomObject]@{
        Transaction_ID = $txn.Id
        Fee_Type = $feeType
        Amount = $amount
        Processing_Fee = $processingFee
        Fee_Covered = $feeCovered
        Total_Charged = $totalCharged
        Total_Received = $totalReceived
        Org_Fee = $orgFee
        Donor_Fee_Covered = $donorFeeCovered
    }
    
    # Map payment method and track if it's non-standard or remapped
    $originalPaymentMethod = $txn.'Payment Method'
    $isNonStandardPayment = $false
    $isRemappedPayment = $false
    
    # Use if-elseif to ensure only one match (switch can return multiple with -Wildcard)
    if ($originalPaymentMethod -like '*Credit Card*' -or $originalPaymentMethod -like '*Card*') {
        $paymentMethod = 'Credit Card'
    }
    elseif ($originalPaymentMethod -like '*Check*') {
        $paymentMethod = 'Check'
    }
    elseif ($originalPaymentMethod -like '*Cash*') {
        $paymentMethod = 'Cash'
    }
    elseif ($originalPaymentMethod -like '*ACH*' -or $originalPaymentMethod -like '*Bank*') {
        $paymentMethod = 'ACH'
    }
    elseif ($originalPaymentMethod -like '*PayPal*') {
        $paymentMethod = 'PayPal'
    }
    elseif ($originalPaymentMethod -like '*Venmo*') {
        $paymentMethod = 'Venmo'
    }
    elseif ($originalPaymentMethod -like '*Google Pay*' -or $originalPaymentMethod -like '*Apple Pay*') {
        # Digital Wallet is a generic category - preserve specific service in notes
        $paymentMethod = 'Digital Wallet'
        $isRemappedPayment = $true
    }
    elseif ($originalPaymentMethod -like '*Donor Advised*') {
        $paymentMethod = 'Donor Advised Fund'
    }
    elseif ($originalPaymentMethod -like '*Stock*') {
        $paymentMethod = 'Stock'
    }
    elseif ($originalPaymentMethod -like '*In Kind*') {
        $paymentMethod = 'In Kind'
    }
    elseif ($originalPaymentMethod -like '*Property*') {
        $paymentMethod = 'Property'
    }
    else {
        # Non-standard payment method - map to "Other" and flag it
        $isNonStandardPayment = $true
        $paymentMethod = 'Other'
    }
    
    # Use campaign from N4G or default
    $campaignTitle = if ($txn.'Campaign/Event' -ne '') { 
        $txn.'Campaign/Event' 
    } else { 
        $DefaultCampaignTitle 
    }
    
    # Check if this is a $0 transaction - must be reclassified as "In Kind" for GiveButter
    $isZeroAmount = [decimal]$amount -eq 0
    $finalPaymentMethod = $paymentMethod
    
    # Build notes from Donation Notes and Payment Description
    $noteParts = @()
    
    # If $0 transaction, preserve original payment type in notes and change to In Kind
    if ($isZeroAmount) {
        $noteParts += "ORIG PMT TYPE: $originalPaymentMethod"
        $finalPaymentMethod = 'In Kind'
    }
    # Add payment type if remapped (e.g., Google Pay → Digital Wallet) or non-standard
    elseif (($isRemappedPayment -or $isNonStandardPayment) -and $originalPaymentMethod -ne '') {
        $noteParts += "ORIG PMT TYPE: $originalPaymentMethod"
    }
    
    if ($txn.'Donation Notes' -ne '') {
        $noteParts += $txn.'Donation Notes'
    }
    if ($txn.'Payment Description' -ne '') {
        $noteParts += $txn.'Payment Description'
    }
    if ($lookupInfo.Is_Merged -eq 'Yes') {
        $noteParts += "Merged from N4G ID: $donorId"
    }
    $notes = $noteParts -join ' | '
    
    # Create GiveButter transaction record
    $processedTransactions += [PSCustomObject]@{
        'Contact ID' = $lookupInfo.GiveButter_Contact_ID
        'Campaign Title' = $campaignTitle
        'Amount' = $amount
        'Payment Method' = $finalPaymentMethod
        'Transaction date' = $txn.'Donation Date'
        'Processing Fee' = $processingFee
        'Fee Covered' = $feeCovered
        'External Label' = $externalLabel
        'External ID' = $txn.Id
        'Notes' = $notes
    }
}

# Count $0 transactions that were reclassified to "In Kind"
$zeroTransactions = $processedTransactions | Where-Object { [decimal]$_.Amount -eq 0 }

# Check for Notes field length issues (GiveButter has 255 char limit on Internal Note field)
$longNotes = $processedTransactions | Where-Object { $_.Notes.Length -gt 255 }

# Save all transactions for import (including $0 as "In Kind")
$outputFile = "$OutputFolder\GiveButter_Transactions_Import_$timestamp.csv"
$processedTransactions | Export-Csv $outputFile -NoTypeInformation
Write-Host "`nCreated GiveButter import file with $($processedTransactions.Count) transactions" -ForegroundColor Green
Write-Host "  → Saved to GiveButter_Transactions_Import_$timestamp.csv" -ForegroundColor Magenta

# Report on $0 transactions that were reclassified
if ($zeroTransactions.Count -gt 0) {
    Write-Host "`nReclassified $0 transactions: $($zeroTransactions.Count)" -ForegroundColor Cyan
    Write-Host "  → Changed to 'In Kind' payment method (GiveButter requirement)" -ForegroundColor Gray
    Write-Host "  → Original payment type preserved in Notes as 'ORIG PMT TYPE: ...'" -ForegroundColor Gray
}

# Warn about long notes (GiveButter has 255 char limit)
if ($longNotes.Count -gt 0) {
    Write-Host "`n⚠️  WARNING: $($longNotes.Count) transaction(s) have Notes > 255 characters" -ForegroundColor Yellow
    Write-Host "  → GiveButter's 'Internal Note' field has a 255 character limit" -ForegroundColor Gray
    Write-Host "  → You may need to manually trim these during import" -ForegroundColor Gray
    Write-Host "  → Affected transactions:" -ForegroundColor Gray
    foreach ($txn in $longNotes) {
        Write-Host "     - ID $($txn.'External ID'): $($txn.Notes.Length) chars" -ForegroundColor Gray
    }
}

# Save unmatched transactions
if ($unmatchedTransactions.Count -gt 0) {
    $unmatchedFile = "$OutputFolder\REVIEW_UnmatchedTransactions_$timestamp.csv"
    $unmatchedTransactions | Export-Csv $unmatchedFile -NoTypeInformation
    Write-Host "`nUnmatched transactions: $($unmatchedTransactions.Count)" -ForegroundColor Yellow
    Write-Host "  → Saved to REVIEW_UnmatchedTransactions_$timestamp.csv" -ForegroundColor Magenta
}

# Save fee analysis
$feeAnalysisFile = "$OutputFolder\INFO_FeeAnalysis_$timestamp.csv"
$feeAnalysis | Export-Csv $feeAnalysisFile -NoTypeInformation
Write-Host "`nFee analysis saved" -ForegroundColor Green
Write-Host "  → Saved to INFO_FeeAnalysis_$timestamp.csv" -ForegroundColor Magenta

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PHASE 3 SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Transactions: $($stats.Total)" -ForegroundColor White
Write-Host "  Matched: $($stats.Matched) ($([math]::Round(($stats.Matched/$stats.Total)*100, 2))%)" -ForegroundColor Green
Write-Host "  Unmatched: $($stats.Unmatched) ($([math]::Round(($stats.Unmatched/$stats.Total)*100, 2))%)" -ForegroundColor $(if ($stats.Unmatched -gt 0) { 'Yellow' } else { 'Green' })

Write-Host "`nImport Ready:" -ForegroundColor Yellow
Write-Host "  Total Transactions: $($processedTransactions.Count)" -ForegroundColor Green
if ($zeroTransactions.Count -gt 0) {
    Write-Host "  Reclassified `$0 as 'In Kind': $($zeroTransactions.Count)" -ForegroundColor Cyan
}

Write-Host "`nTransaction Types:" -ForegroundColor Yellow
Write-Host "  Donations: $($stats.Donations)" -ForegroundColor White
Write-Host "  Ticket Purchases: $($stats.TicketPurchases)" -ForegroundColor White

Write-Host "`nDonor Types:" -ForegroundColor Yellow
Write-Host "  Individuals: $($stats.Individuals)" -ForegroundColor White
Write-Host "  Organizations: $($stats.Organizations)" -ForegroundColor White

Write-Host "`nFee Handling:" -ForegroundColor Yellow
Write-Host "  Donor Covered Fees: $($stats.DonorPaidFees)" -ForegroundColor White
Write-Host "  Organization Paid Fees: $($stats.OrgPaidFees)" -ForegroundColor White

if ($stats.MergedDuplicateTransactions -gt 0) {
    Write-Host "`nMerged Duplicates:" -ForegroundColor Yellow
    Write-Host "  Transactions from Merged Contacts: $($stats.MergedDuplicateTransactions)" -ForegroundColor Cyan
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
if ($stats.Unmatched -gt 0) {
    Write-Host "1. Review REVIEW_UnmatchedTransactions_*.csv" -ForegroundColor Yellow
    Write-Host "2. Resolve unmatched donors (add to Phase 2 mapping)" -ForegroundColor Yellow
    Write-Host "3. Import GiveButter_Transactions_Import_*.csv to GiveButter" -ForegroundColor Yellow
}
else {
    Write-Host "1. All transactions matched successfully!" -ForegroundColor Green
    Write-Host "2. Review INFO_FeeAnalysis_*.csv to verify fee calculations" -ForegroundColor Yellow
    Write-Host "3. Import GiveButter_Transactions_Import_*.csv to GiveButter" -ForegroundColor Yellow
}
Write-Host ""

# Save summary
$summaryFile = "$OutputFolder\Phase3_Summary_$timestamp.txt"
@"
PHASE 3 TRANSACTION PREPARATION SUMMARY (ENHANCED)
Generated: $(Get-Date)
========================================

STATISTICS:
- Total Transactions: $($stats.Total)
- Matched: $($stats.Matched) ($([math]::Round(($stats.Matched/$stats.Total)*100, 2))%)
- Unmatched: $($stats.Unmatched) ($([math]::Round(($stats.Unmatched/$stats.Total)*100, 2))%)

TRANSACTION TYPES:
- Donations: $($stats.Donations)
- Ticket Purchases: $($stats.TicketPurchases)

DONOR TYPES:
- Individuals: $($stats.Individuals)
- Organizations: $($stats.Organizations)

FEE HANDLING:
- Donor Covered Fees: $($stats.DonorPaidFees)
- Organization Paid Fees: $($stats.OrgPaidFees)

MERGED DUPLICATES:
- Transactions from Merged Contacts: $($stats.MergedDuplicateTransactions)

FILES CREATED:
- GiveButter Import: $outputFile
- Fee Analysis: $feeAnalysisFile
$(if ($stats.Unmatched -gt 0) { "- Unmatched Transactions: REVIEW_UnmatchedTransactions_$timestamp.csv" } else { "" })

NEXT STEPS:
$(if ($stats.Unmatched -gt 0) { 
"1. Review unmatched transactions
2. Resolve unmatched donors
3. Import to GiveButter" 
} else { 
"1. All transactions matched!
2. Review fee analysis
3. Import to GiveButter" 
})
"@ | Out-File $summaryFile

Write-Host "Summary saved to: $summaryFile" -ForegroundColor Green
Write-Host "Log saved to: $logFile" -ForegroundColor Green
Write-Host ""

# Suggest updating mapping file for future imports
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RECOMMENDED: Update Mapping File" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "To prevent duplicates on future imports, update the mapping file now:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  .\Utility-CreateMappingFromGiveButter.ps1 -AutoFindLatest" -ForegroundColor White
Write-Host ""
Write-Host "This will:" -ForegroundColor Gray
Write-Host "  - Backup your current mapping file to backup\" -ForegroundColor Gray
Write-Host "  - Create fresh mapping from latest GiveButter exports" -ForegroundColor Gray
Write-Host "  - Include all $($stats.Matched) imported contacts" -ForegroundColor Gray
Write-Host ""
Write-Host "Run now? (Y/N - auto-skip in 10 seconds): " -ForegroundColor Yellow -NoNewline

# Simple timeout using host.UI.RawUI.KeyAvailable
$response = $null
$timeoutSeconds = 10
$startTime = Get-Date

while (((Get-Date) - $startTime).TotalSeconds -lt $timeoutSeconds) {
    if ([Console]::KeyAvailable) {
        $response = Read-Host
        break
    }
    Start-Sleep -Milliseconds 100
}

if ($null -eq $response) {
    Write-Host ""
    Write-Host "`nNo response - auto-running backup (timed out after 10 seconds)." -ForegroundColor Cyan
    $response = 'Y'
}

if ($response -eq 'Y' -or $response -eq 'y') {
    Write-Host "`nRunning utility script..." -ForegroundColor Cyan
    & ".\Utility-CreateMappingFromGiveButter.ps1" -AutoFindLatest
} elseif ($response -eq 'N' -or $response -eq 'n') {
    Write-Host "`nSkipped. You can run it manually later." -ForegroundColor Gray
}

Write-Host ""

# Stop transcript logging
Stop-Transcript
