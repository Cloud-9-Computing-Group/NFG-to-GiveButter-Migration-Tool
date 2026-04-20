# Phase 1A: Prepare Individual Contacts for GiveButter Import
# Based on testing completed April 15-16, 2026
# See NOTES_TESTED_GIVEBUTTER_IMPORTS.md for test results

param(
    [string]$InputFile = "N4G Contact export (full).csv",
    [string]$OutputFolder = "output",
    [string]$ExistingGiveButterMapping = "existing_givebutter_mapping.csv",  # For pre-existing contacts
    [switch]$SkipReview,
    [switch]$AutoConvertOrgs,
    [switch]$AutoMergeDuplicates
)

# Default AutoConvertOrgs to true if not explicitly set
if (-not $PSBoundParameters.ContainsKey('AutoConvertOrgs')) {
    $AutoConvertOrgs = $true
}

# Load existing GiveButter contacts mapping (if file exists)
$existingGBContacts = @{}
if ($ExistingGiveButterMapping -ne "" -and (Test-Path $ExistingGiveButterMapping)) {
    Write-Host "Loading existing GiveButter contacts mapping..." -ForegroundColor Yellow
    
    # Check file age
    $mappingFile = Get-Item $ExistingGiveButterMapping
    $fileAge = (Get-Date) - $mappingFile.LastWriteTime
    
    if ($fileAge.TotalDays -gt 2) {
        Write-Host "⚠️  WARNING: Mapping file is $([math]::Round($fileAge.TotalDays, 1)) days old!" -ForegroundColor Yellow
        Write-Host "   Consider regenerating with: .\Utility-CreateMappingFromGiveButter.ps1 -AutoFindLatest" -ForegroundColor Yellow
        Write-Host "   Press Enter to continue anyway, or Ctrl+C to cancel..." -ForegroundColor Gray
        Read-Host
    }
    
    $existingMapping = Import-Csv $ExistingGiveButterMapping
    
    # Check if file has new format (N4G_ID column) or old format (Primary_Email only)
    $hasN4GID = $existingMapping[0].PSObject.Properties.Name -contains 'N4G_ID'
    
    if ($hasN4GID) {
        # New format - use N4G_ID for matching (more accurate)
        foreach ($contact in $existingMapping) {
            if ($contact.N4G_ID -ne '' -and $contact.GiveButter_Contact_ID -ne '') {
                $existingGBContacts[$contact.N4G_ID] = $contact.GiveButter_Contact_ID
            }
        }
        Write-Host "Loaded $($existingGBContacts.Count) existing GiveButter contacts (by N4G_ID)`n" -ForegroundColor Green
    } else {
        # Old format - use email for matching (legacy)
        Write-Host "⚠️  WARNING: Using legacy email-based mapping format" -ForegroundColor Yellow
        Write-Host "   Regenerate with: .\Utility-CreateMappingFromGiveButter.ps1 -AutoFindLatest" -ForegroundColor Yellow
        foreach ($contact in $existingMapping) {
            if ($contact.Primary_Email -ne '' -and $contact.Givebutter_Contact_ID -ne '') {
                $existingGBContacts[$contact.Primary_Email] = $contact.Givebutter_Contact_ID
            }
        }
        Write-Host "Loaded $($existingGBContacts.Count) existing GiveButter contacts (by email)`n" -ForegroundColor Green
    }
}

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Constants for field length limits
$STANDARD_TEXT_LIMIT = 255
$LONG_TEXT_SAFE_LIMIT = 1900

# Create output and logs folders
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}
$logsFolder = Join-Path $OutputFolder "logs"
if (-not (Test-Path $logsFolder)) {
    New-Item -ItemType Directory -Path $logsFolder | Out-Null
}

# Start transcript logging
$logFile = Join-Path $logsFolder "Phase1A_Log_$timestamp.txt"
Start-Transcript -Path $logFile -Append

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Phase 1A: Individual Contact Preparation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Organization detection patterns
$orgPatterns = @(
    'LLC', 'Inc\.?', 'Foundation', 'Corp\.?', 'Corporation', 'Ltd\.?', 'LLP', 'PLLC', 
    'P\.C\.', 'P\.A\.', 'Trust', 'Company', 'Co\.', 'Group', 'Partners', 
    'Associates', 'Properties', 'Holdings', 'Enterprises', 'Solutions', 
    'Services', 'Management', 'Consulting', 'Advisors', 'Capital', 
    'Investments', 'Ventures', 'Fund', 'Charity', 'Society', 'Association', 
    'Institute', 'Center', 'Centre', 'Organization', 'Rotary', 'Church', 
    'Ministry', 'Ministries',
    # Specific organizations from user feedback
    'IOA', 'NuView', 'CWUSA', 'Amber Brooke Farms', 'Benevity', 
    'Florida Conference', 'AmazonSmile', 'GiveSmart', 'Eventbrite', 
    'Accelevents', 'ProVest', 'AdventHealth', 'Equity', 'Cogent Bank',
    'Texas Instruments'
)
$orgRegex = '\b(' + ($orgPatterns -join '|') + ')\b'

Write-Host "Loading contact data..." -ForegroundColor Yellow
$contacts = Import-Csv $InputFile
Write-Host "Loaded $($contacts.Count) contacts`n" -ForegroundColor Green

# Initialize tracking
$stats = @{
    TotalContacts = $contacts.Count
    Individuals = 0
    Organizations = 0
    MisclassifiedOrgs = 0
    SingleNameFixed = 0
    CoupleNames = 0
    SharedEmails = 0
    HighConfidenceDuplicates = 0
    AutoMergedDuplicates = 0
    HouseholdsPreserved = 0
    PreMatchedExisting = 0
    AddressIncomplete = 0
    AddressMissingCountry = 0
}

# Track custom field population
$customFieldStats = @{
    NFG_ID = 0
    NFG_Type = 0
    NFG_Household_Members = 0
    NFG_Point_Of_Contact = 0
    NFG_Data_Quality_Flags = 0
    NFG_Duplicate_Source = 0
    NFG_Alternate_Contacts = 0
    NFG_Original_and_Merged_Addresses = 0
    NFG_Original_Donor_Since = 0
    NFG_Combined_Lifetime_Value = 0
    NFG_Merge_Date = 0
}

Write-Host "Analyzing data quality...`n" -ForegroundColor Yellow

# 1. Filter to individuals only (organizations handled in Phase 1B)
Write-Host "1. Filtering to individual contacts..." -ForegroundColor Cyan
$individualContacts = $contacts | Where-Object { $_.Type -eq 'Individual' }
Write-Host "   Found $($individualContacts.Count) individual contacts" -ForegroundColor Green
Write-Host "   Organizations will be processed in Phase 1B`n" -ForegroundColor Gray

# 2. Detect misclassified organizations and exclude from individuals export
Write-Host "2. Detecting misclassified organizations..." -ForegroundColor Cyan
$orgConversions = @()
$misclassifiedOrgs = $individualContacts | Where-Object {
    $_.'Full Name' -match $orgRegex
}

foreach ($contact in $misclassifiedOrgs) {
    $matchedPattern = ''
    foreach ($pattern in $orgPatterns) {
        if ($contact.'Full Name' -match "\b$pattern\b") {
            $matchedPattern = $pattern -replace '\\\.?', ''
            break
        }
    }
    
    $orgConversions += [PSCustomObject]@{
        N4G_ID = $contact.Id
        Original_Type = $contact.Type
        New_Type = 'Organization'
        Name = $contact.'Full Name'
        Pattern_Matched = $matchedPattern
        Confidence = 'High'
        Lifetime_Value = $contact.'Lifetime Donations'
        Email = $contact.'Primary Email'
        Action = 'Excluded from Individuals - Will be in Phase 1B'
    }
}

$stats.MisclassifiedOrgs = $misclassifiedOrgs.Count
Write-Host "   Found $($stats.MisclassifiedOrgs) misclassified organizations" -ForegroundColor Yellow
Write-Host "   These will be EXCLUDED from individuals export" -ForegroundColor Red
Write-Host "   They will be included in Phase 1B companies export`n" -ForegroundColor Gray

# Exclude misclassified orgs from individuals processing
$misclassifiedOrgIDs = $misclassifiedOrgs | Select-Object -ExpandProperty Id
$individualContacts = $individualContacts | Where-Object { $misclassifiedOrgIDs -notcontains $_.Id }

if ($orgConversions.Count -gt 0) {
    $orgConversions | Export-Csv "$OutputFolder\REVIEW_OrgConversions_$timestamp.csv" -NoTypeInformation
    Write-Host "   → Exported to REVIEW_OrgConversions_$timestamp.csv`n" -ForegroundColor Magenta
}

Write-Host "   Remaining individuals after excluding orgs: $($individualContacts.Count)`n" -ForegroundColor Green

# 3. Validate Last Name requirement and fix single-name contacts
Write-Host "3. Validating Last Name requirement for individuals..." -ForegroundColor Cyan
$missingLastName = $individualContacts | Where-Object { $_.'Last Name' -eq '' }
$singleNameFixed = 0

if ($missingLastName.Count -gt 0) {
    Write-Host "   Found $($missingLastName.Count) individuals without Last Name" -ForegroundColor Yellow
    
    # Auto-fix single-name contacts (add "UNKNOWN" as Last Name)
    foreach ($contact in $missingLastName) {
        $contact.'Last Name' = 'UNKNOWN'
        $singleNameFixed++
    }
    $stats.SingleNameFixed = $singleNameFixed
    
    Write-Host "   Auto-fixed $singleNameFixed single-name contacts (Last Name = 'UNKNOWN')" -ForegroundColor Green
    
    # Export list of fixed contacts for review
    $missingLastName | Select-Object Id, 'Full Name', 'First Name', @{N='Last Name';E={'UNKNOWN'}}, 'Primary Email' |
        Export-Csv "$OutputFolder\INFO_SingleNameContactsFixed_$timestamp.csv" -NoTypeInformation
    Write-Host "   → Exported to INFO_SingleNameContactsFixed_$timestamp.csv`n" -ForegroundColor Magenta
}
else {
    Write-Host "   All individuals have Last Name ✓`n" -ForegroundColor Green
}

# 4. Check for couple names
Write-Host "4. Checking for couple/joint names..." -ForegroundColor Cyan
$coupleNames = $individualContacts | Where-Object {
    $_.'Full Name' -match ' (&|and) '
}
$stats.CoupleNames = $coupleNames.Count
Write-Host "   Found $($stats.CoupleNames) contacts with joint names" -ForegroundColor $(if ($stats.CoupleNames -gt 0) { 'Yellow' } else { 'Green' })

if ($coupleNames.Count -gt 0) {
    $coupleNames | Select-Object Id, 'Full Name', 'Primary Email', 'Household Name' | 
        Export-Csv "$OutputFolder\REVIEW_CoupleNames_$timestamp.csv" -NoTypeInformation
    Write-Host "   → Exported to REVIEW_CoupleNames_$timestamp.csv`n" -ForegroundColor Magenta
}

# 5. Shared email detection (family emails) and duplicate detection
Write-Host "5. Analyzing shared emails and duplicates..." -ForegroundColor Cyan

# First, group by name to find potential duplicates
$nameGroups = $individualContacts | Where-Object { $_.'Full Name' -ne '' } | Group-Object 'Full Name'
$duplicateNameGroups = $nameGroups | Where-Object { $_.Count -gt 1 }

$sharedEmails = @()
$highConfidenceDupes = @()

# Check each name group for duplicates
foreach ($nameGroup in $duplicateNameGroups) {
    # Get unique emails in this name group (excluding empty)
    $emails = $nameGroup.Group | Where-Object { $_.'Primary Email' -ne '' } | Select-Object -ExpandProperty 'Primary Email' -Unique
    
    # Check if all records with emails have the SAME email (or no emails at all)
    if ($emails.Count -le 1) {
        # Same name + (same email OR no email) = HIGH CONFIDENCE DUPLICATE
        # This includes: same name + same email, OR same name + no email
        $dupeGroup = $nameGroup.Group
        
        if ($dupeGroup.Count -gt 1) {
            # Sort by First Donation Date to determine primary (oldest donor)
            $sorted = $dupeGroup | Sort-Object { 
                if ($_.'First Donation Date' -ne '') { 
                    try {
                        [DateTime]::ParseExact($_.'First Donation Date', @('M/d/yyyy', 'yyyy-MM-dd', 'MM/dd/yyyy'), [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None)
                    } catch {
                        [DateTime]::MaxValue
                    }
                } else { 
                    [DateTime]::MaxValue 
                }
            }
            
            $primary = $sorted[0]
            
            # Create duplicate entry for each additional record
            for ($i = 1; $i -lt $sorted.Count; $i++) {
                $merge = $sorted[$i]
                $highConfidenceDupes += [PSCustomObject]@{
                    Confidence = 'High'
                    Reason = 'Same name + same email'
                    Primary_ID = $primary.Id
                    Merge_ID = $merge.Id
                    Name = $primary.'Full Name'
                    Email = $primary.'Primary Email'
                    Phone1 = $primary.'Mobile Phone'
                    Phone2 = $merge.'Mobile Phone'
                    Address1 = "$($primary.Address), $($primary.City), $($primary.State) $($primary.'Zip Code')"
                    Address2 = "$($merge.Address), $($merge.City), $($merge.State) $($merge.'Zip Code')"
                    DonorSince1 = $primary.'First Donation Date'
                    DonorSince2 = $merge.'First Donation Date'
                    Lifetime1 = $primary.'Lifetime Donations'
                    Lifetime2 = $merge.'Lifetime Donations'
                    Action = if ($AutoMergeDuplicates) { 'Auto-Merged' } else { 'Flagged for Review' }
                }
            }
        }
    }
    elseif ($emails.Count -gt 1) {
        # Same name + different emails = Different people (or data quality issue)
        # Skip - not a duplicate
    }
    # If no emails, also skip
}

# Also check for shared emails (different names, same email)
$emailGroups = $individualContacts | Where-Object { $_.'Primary Email' -ne '' } | Group-Object 'Primary Email'
$duplicateEmailGroups = $emailGroups | Where-Object { $_.Count -gt 1 }

foreach ($group in $duplicateEmailGroups) {
    $uniqueNames = ($group.Group | Select-Object -ExpandProperty 'Full Name' -Unique).Count
    if ($uniqueNames -gt 1) {
        # Different names = shared email (likely family)
        $stats.SharedEmails++
        $sharedEmails += [PSCustomObject]@{
            Email = $group.Name
            Contact_Count = $group.Count
            Names = ($group.Group.'Full Name' -join ', ')
            N4G_IDs = ($group.Group.Id -join ', ')
            Household_Info = ($group.Group.'Household Name' | Select-Object -Unique -First 1)
            Recommendation = 'Keep separate - likely family email'
        }
    }
}

$stats.HighConfidenceDuplicates = $highConfidenceDupes.Count

if ($sharedEmails.Count -gt 0) {
    $sharedEmails | Export-Csv "$OutputFolder\REVIEW_SharedEmails_$timestamp.csv" -NoTypeInformation
    Write-Host "   Found $($stats.SharedEmails) shared email groups (different names, same email)" -ForegroundColor Yellow
    Write-Host "   → Exported to REVIEW_SharedEmails_$timestamp.csv" -ForegroundColor Magenta
}

Write-Host "   Found $($stats.HighConfidenceDuplicates) high-confidence duplicates (same name + same email)" -ForegroundColor $(if ($stats.HighConfidenceDuplicates -gt 0) { 'Yellow' } else { 'Green' })

# 6. Export and process high-confidence duplicates
if ($highConfidenceDupes.Count -gt 0) {
    $highConfidenceDupes | Export-Csv "$OutputFolder\REVIEW_HighConfidenceDuplicates_$timestamp.csv" -NoTypeInformation
    Write-Host "   → Exported to REVIEW_HighConfidenceDuplicates_$timestamp.csv" -ForegroundColor Magenta
    if ($AutoMergeDuplicates) {
        Write-Host "   → Auto-merging enabled`n" -ForegroundColor Green
    } else {
        Write-Host "   → Auto-merge disabled (use -AutoMergeDuplicates to enable)`n" -ForegroundColor Gray
    }
}

# 7. Household analysis
Write-Host "7. Analyzing households..." -ForegroundColor Cyan
$householdGroups = $individualContacts | Where-Object { $_.'Household Id' -ne '' } | Group-Object 'Household Id'
$multiMemberHouseholds = $householdGroups | Where-Object { $_.Count -gt 1 }
$stats.HouseholdsPreserved = $householdGroups.Count

if ($multiMemberHouseholds.Count -gt 0) {
    $householdReport = foreach ($group in $multiMemberHouseholds) {
        [PSCustomObject]@{
            Household_ID = $group.Name
            Household_Name = ($group.Group.'Household Name' | Select-Object -Unique -First 1)
            Member_Count = $group.Count
            Members = ($group.Group.'Full Name' -join '; ')
            Head_Of_Household = ($group.Group | Where-Object { $_.'Head Of Household' -eq 'true' } | Select-Object -ExpandProperty 'Full Name' -First 1)
        }
    }
    $householdReport | Export-Csv "$OutputFolder\INFO_MultiMemberHouseholds_$timestamp.csv" -NoTypeInformation
    Write-Host "   Found $($stats.HouseholdsPreserved) households ($($multiMemberHouseholds.Count) with multiple members)" -ForegroundColor Green
    Write-Host "   → Exported to INFO_MultiMemberHouseholds_$timestamp.csv`n" -ForegroundColor Magenta
}

# 8. Prepare merged contact records
Write-Host "8. Preparing GiveButter import file with custom fields..." -ForegroundColor Cyan

# Create merge lookup (maps merge IDs to primary IDs)
$mergeLookup = @{}
$primaryToMergeIDs = @{}  # Reverse lookup: primary ID -> array of merge IDs
if ($AutoMergeDuplicates) {
    foreach ($dupe in $highConfidenceDupes) {
        $mergeLookup[$dupe.Merge_ID] = $dupe.Primary_ID
        
        # Build reverse lookup
        if (-not $primaryToMergeIDs.ContainsKey($dupe.Primary_ID)) {
            $primaryToMergeIDs[$dupe.Primary_ID] = @()
        }
        $primaryToMergeIDs[$dupe.Primary_ID] += $dupe.Merge_ID
    }
    $stats.AutoMergedDuplicates = $mergeLookup.Count
}

# Build hashtable for efficient contact lookup by ID
$contactsById = @{}
foreach ($c in $individualContacts) {
    $contactsById[$c.Id] = $c
}

# Process contacts
$processedIDs = @{}
$giveButterContacts = foreach ($contact in $individualContacts) {
    # Skip if this contact was merged into another
    if ($mergeLookup.ContainsKey($contact.Id)) {
        continue
    }
    
    # Skip if already processed
    if ($processedIDs.ContainsKey($contact.Id)) {
        continue
    }
    $processedIDs[$contact.Id] = $true
    
    # Find contacts to merge into this one (using optimized hashtable lookup)
    $mergeContacts = @()
    if ($AutoMergeDuplicates -and $primaryToMergeIDs.ContainsKey($contact.Id)) {
        $mergeIDs = $primaryToMergeIDs[$contact.Id]
        $mergeContacts = $mergeIDs | ForEach-Object { $contactsById[$_] } | Where-Object { $_ -ne $null }
    }
    
    # Initialize custom fields
    $nfg_data_quality_flags = @()
    $nfg_household_members = ''
    $nfg_duplicate_source = @($contact.Id)
    $nfg_addresses = @()
    $nfg_original_donor_since = $contact.'First Donation Date'
    $nfg_combined_lifetime = 0
    $nfg_merge_date = ''
    
    # Collect additional emails and phones
    $additionalEmails = @()
    $additionalPhones = @()
    
    # Process primary contact
    if ($contact.'Work Email' -ne '' -and $contact.'Work Email' -ne $contact.'Primary Email') {
        $additionalEmails += $contact.'Work Email'
    }
    if ($contact.'Secondary Email' -ne '' -and $contact.'Secondary Email' -ne $contact.'Primary Email') {
        $additionalEmails += $contact.'Secondary Email'
    }
    if ($contact.'Home Phone' -ne '' -and $contact.'Home Phone' -ne $contact.'Mobile Phone') {
        $additionalPhones += $contact.'Home Phone'
    }
    if ($contact.'Work Phone' -ne '' -and $contact.'Work Phone' -ne $contact.'Mobile Phone') {
        $additionalPhones += $contact.'Work Phone'
    }
    
    # Add primary address to addresses field
    if ($contact.Address -ne '') {
        $addrParts = @($contact.Address)
        if ($contact.'Address 2' -ne '') { $addrParts += $contact.'Address 2' }
        $addrParts += "$($contact.City), $($contact.State) $($contact.'Zip Code')"
        $nfg_addresses += "PRIMARY: $($addrParts -join ', ')"
    }
    
    # Parse lifetime value
    try {
        $lifetimeStr = $contact.'Lifetime Donations' -replace '[\$,]', ''
        $nfg_combined_lifetime = [decimal]$lifetimeStr
    } catch {
        $nfg_combined_lifetime = 0
        $nfg_data_quality_flags += 'INVALID_LIFETIME_VALUE'
    }
    
    # Process merged contacts
    if ($mergeContacts.Count -gt 0) {
        $nfg_data_quality_flags += 'AUTO_MERGED'
        $nfg_merge_date = Get-Date -Format 'yyyy-MM-dd'
        
        foreach ($mergeContact in $mergeContacts) {
            $nfg_duplicate_source += $mergeContact.Id
            
            # Collect additional emails
            if ($mergeContact.'Primary Email' -ne '' -and $mergeContact.'Primary Email' -ne $contact.'Primary Email') {
                $additionalEmails += $mergeContact.'Primary Email'
            }
            if ($mergeContact.'Work Email' -ne '' -and $mergeContact.'Work Email' -ne $contact.'Primary Email') {
                $additionalEmails += $mergeContact.'Work Email'
            }
            if ($mergeContact.'Secondary Email' -ne '' -and $mergeContact.'Secondary Email' -ne $contact.'Primary Email') {
                $additionalEmails += $mergeContact.'Secondary Email'
            }
            
            # Collect additional phones
            if ($mergeContact.'Mobile Phone' -ne '' -and $mergeContact.'Mobile Phone' -ne $contact.'Mobile Phone') {
                $additionalPhones += $mergeContact.'Mobile Phone'
            }
            if ($mergeContact.'Home Phone' -ne '' -and $mergeContact.'Home Phone' -ne $contact.'Mobile Phone') {
                $additionalPhones += $mergeContact.'Home Phone'
            }
            if ($mergeContact.'Work Phone' -ne '' -and $mergeContact.'Work Phone' -ne $contact.'Mobile Phone') {
                $additionalPhones += $mergeContact.'Work Phone'
            }
            
            # Collect addresses
            if ($mergeContact.Address -ne '' -and $mergeContact.Address -ne $contact.Address) {
                $addrParts = @($mergeContact.Address)
                if ($mergeContact.'Address 2' -ne '') { $addrParts += $mergeContact.'Address 2' }
                $addrParts += "$($mergeContact.City), $($mergeContact.State) $($mergeContact.'Zip Code')"
                $nfg_addresses += "MERGED: $($addrParts -join ', ')"
            }
            
            # Track earliest donor date
            if ($mergeContact.'First Donation Date' -ne '' -and 
                ($nfg_original_donor_since -eq '' -or $mergeContact.'First Donation Date' -lt $nfg_original_donor_since)) {
                $nfg_original_donor_since = $mergeContact.'First Donation Date'
            }
            
            # Sum lifetime values
            try {
                $lifetimeStr = $mergeContact.'Lifetime Donations' -replace '[\$,]', ''
                $nfg_combined_lifetime += [decimal]$lifetimeStr
            } catch {
                # Skip if can't parse (already flagged for primary contact if needed)
            }
        }
    }
    
    # Check if converted to org
    if ($orgConversions | Where-Object { $_.N4G_ID -eq $contact.Id -and $_.Action -eq 'Auto-Converted' }) {
        $nfg_data_quality_flags += 'CONVERTED_TO_ORG'
    }
    
    # Check if couple name
    if ($contact.'Full Name' -match ' (&|and) ') {
        $nfg_data_quality_flags += 'COUPLE_NAME'
    }
    
    # Check if shared email
    $sharedEmailMatch = $sharedEmails | Where-Object { $_.N4G_IDs -match $contact.Id }
    if ($sharedEmailMatch) {
        $nfg_data_quality_flags += 'SHARED_EMAIL'
    }
    
    # Populate household members
    if ($contact.'Other Household Members' -ne '') {
        $nfg_household_members = $contact.'Other Household Members'
        $customFieldStats.NFG_Household_Members++
    }
    
    # Deduplicate and format additional emails/phones
    $additionalEmails = $additionalEmails | Select-Object -Unique
    $additionalPhones = $additionalPhones | Select-Object -Unique
    
    # Format custom fields (before address validation adds flags)
    $nfg_duplicate_source_str = ($nfg_duplicate_source | Select-Object -Unique) -join ', '
    $nfg_addresses_str = ($nfg_addresses -join ' | ')
    
    # Truncate if needed (long text fields support 2000+ chars, but be safe)
    if ($nfg_addresses_str.Length -gt $LONG_TEXT_SAFE_LIMIT) {
        $nfg_addresses_str = $nfg_addresses_str.Substring(0, ($LONG_TEXT_SAFE_LIMIT - 3)) + '...'
        $nfg_data_quality_flags += 'ADDRESSES_TRUNCATED'
    }
    
    # Update stats (will update data quality flags count after address validation)
    $stats.Individuals++
    $customFieldStats.NFG_ID++
    $customFieldStats.NFG_Type++
    if ($nfg_duplicate_source.Count -gt 1) { $customFieldStats.NFG_Duplicate_Source++ }
    if ($nfg_addresses_str -ne '') { $customFieldStats.NFG_Original_and_Merged_Addresses++ }
    if ($additionalEmails.Count -gt 0 -or $additionalPhones.Count -gt 0) { $customFieldStats.NFG_Alternate_Contacts++ }
    if ($nfg_original_donor_since -ne '') { $customFieldStats.NFG_Original_Donor_Since++ }
    if ($nfg_combined_lifetime -gt 0) { $customFieldStats.NFG_Combined_Lifetime_Value++ }
    if ($nfg_merge_date -ne '') { $customFieldStats.NFG_Merge_Date++ }
    
    # Determine email subscription status
    $emailSubStatus = if ($contact.'Email Subscription Status' -eq 'yes') { 'yes' } else { 'no' }
    
    # Check if this contact exists in GiveButter (pre-match by N4G_ID or email)
    $givebutterContactID = ''
    # Try N4G_ID first (more accurate)
    if ($existingGBContacts.ContainsKey($contact.Id)) {
        $givebutterContactID = $existingGBContacts[$contact.Id]
        $stats.PreMatchedExisting++
    }
    # Fall back to email matching (legacy format)
    elseif ($existingGBContacts.ContainsKey($contact.'Primary Email')) {
        $givebutterContactID = $existingGBContacts[$contact.'Primary Email']
        $stats.PreMatchedExisting++
    }
    
    # Address validation: GiveButter requires ALL address fields or NONE
    # Check BEFORE adding to custom field so we can mark incomplete addresses
    $addressLine1 = $contact.Address
    $addressLine2 = $contact.'Address 2'
    $city = $contact.City
    $state = $contact.State
    $zipCode = $contact.'Zip Code'
    $countryCode = $contact.Country
    
    # Check if any required address fields are missing (Address Line 1, City, State, Zip Code)
    $hasIncompleteAddress = (
        ($addressLine1 -eq '' -or $city -eq '' -or $state -eq '' -or $zipCode -eq '') -and
        ($addressLine1 -ne '' -or $city -ne '' -or $state -ne '' -or $zipCode -ne '')
    )
    
    if ($hasIncompleteAddress) {
        # Mark incomplete address in custom field, then clear for import
        if ($nfg_addresses_str -ne '') {
            # Update the last address entry (PRIMARY) to mark as incomplete
            $addressParts = $nfg_addresses_str -split ' \| '
            if ($addressParts[-1] -match '^PRIMARY:') {
                $addressParts[-1] = 'INCOMPLETE: ' + $addressParts[-1]
                $nfg_addresses_str = $addressParts -join ' | '
            }
        }
        # Clear ALL address fields (including Country Code) for import
        $addressLine1 = ''
        $addressLine2 = ''
        $city = ''
        $state = ''
        $zipCode = ''
        $countryCode = ''
        $nfg_data_quality_flags += 'ADDRESS_INCOMPLETE'
        $stats.AddressIncomplete++
    }
    elseif ($addressLine1 -ne '' -and $countryCode -eq '') {
        # Address is complete but missing Country Code - flag for manual review
        $nfg_data_quality_flags += 'ADDRESS_MISSING_COUNTRY'
        $stats.AddressMissingCountry++
    }
    
    # Re-format data quality flags after address validation
    $nfg_data_quality_flags_str = ($nfg_data_quality_flags | Select-Object -Unique) -join ', '
    if ($nfg_data_quality_flags_str -ne '') { $customFieldStats.NFG_Data_Quality_Flags++ }
    
    # Create GiveButter contact record
    [PSCustomObject]@{
        'Givebutter Contact ID' = $givebutterContactID
        'Contact External ID' = $contact.Id
        'First Name' = $contact.'First Name'
        'Last Name' = $contact.'Last Name'
        'Primary Email' = $contact.'Primary Email'
        'Email Addresses' = if ($additionalEmails.Count -gt 0) { $additionalEmails -join ', ' } else { '' }
        'Primary Phone Number' = $contact.'Mobile Phone'
        'Phone Numbers' = if ($additionalPhones.Count -gt 0) { $additionalPhones -join ', ' } else { '' }
        'Address Line 1' = $addressLine1
        'Address Line 2' = $addressLine2
        'City' = $city
        'State' = $state
        'Zip Code' = $zipCode
        'Country Code' = $countryCode
        'Gender' = $contact.Gender
        'Household Name' = $contact.'Household Name'
        'Is Household Primary Contact?' = if ($contact.'Head Of Household' -eq 'true') { 'yes' } else { 'no' }
        'Tags' = $contact.Groups
        'Date of Birth' = $contact.'Date Of Birth'
        'Company' = $contact.Employer
        'Title' = $contact.'Job Title'
        'Notes' = $contact.Notes
        'Email Subscription Status' = $emailSubStatus
        
        # CUSTOM FIELDS (11 total)
        'NFG_ID' = $contact.Id
        'NFG_Type' = 'Individual'
        'NFG_Household_Members' = $nfg_household_members
        'NFG_Point_Of_Contact' = ''  # Only for organizations
        'NFG_Data_Quality_Flags' = $nfg_data_quality_flags_str
        'NFG_Duplicate_Source' = $nfg_duplicate_source_str
        'NFG_Alternate_Contacts' = ''  # Emails/phones now in Email Addresses/Phone Numbers
        'NFG_Original_and_Merged_Addresses' = $nfg_addresses_str
        'NFG_Original_Donor_Since' = $nfg_original_donor_since
        'NFG_Combined_Lifetime_Value' = if ($nfg_combined_lifetime -gt 0) { $nfg_combined_lifetime.ToString('F2') } else { '' }
        'NFG_Merge_Date' = $nfg_merge_date
    }
}

$outputFile = "$OutputFolder\GiveButter_Individuals_Import_$timestamp.csv"
$giveButterContacts | Export-Csv $outputFile -NoTypeInformation
Write-Host "   Created GiveButter import file with $($giveButterContacts.Count) individual contacts" -ForegroundColor Green
Write-Host "   → Saved to GiveButter_Individuals_Import_$timestamp.csv`n" -ForegroundColor Magenta

# 9. Create mapping file for Phase 2
Write-Host "9. Creating N4G to GiveButter ID mapping template..." -ForegroundColor Cyan
$mappingFile = foreach ($contact in $giveButterContacts) {
    [PSCustomObject]@{
        N4G_ID = $contact.'Contact External ID'
        N4G_Type = 'Individual'
        Full_Name = "$($contact.'First Name') $($contact.'Last Name')"
        Primary_Email = $contact.'Primary Email'
        GiveButter_Contact_ID = ''
        Import_Status = 'Pending'
        Import_Date = ''
        Notes = ''
    }
}

$mappingOutputFile = "$OutputFolder\N4G_to_GiveButter_Mapping_Individuals_$timestamp.csv"
$mappingFile | Export-Csv $mappingOutputFile -NoTypeInformation
Write-Host "   Created mapping template for $($mappingFile.Count) contacts" -ForegroundColor Green
Write-Host "   → Saved to N4G_to_GiveButter_Mapping_Individuals_$timestamp.csv`n" -ForegroundColor Magenta

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PHASE 1A SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total N4G Contacts Processed: $($contacts.Count)" -ForegroundColor White
Write-Host "  Individuals (exported): $($stats.Individuals)" -ForegroundColor Green
Write-Host "  Organizations (for Phase 1B): $($stats.Organizations + $stats.MisclassifiedOrgs)" -ForegroundColor Yellow

Write-Host "`nOrganization Detection:" -ForegroundColor Yellow
Write-Host "  Misclassified as Individuals: $($stats.MisclassifiedOrgs)" -ForegroundColor White
Write-Host "  Excluded from Individuals Export: $($stats.MisclassifiedOrgs)" -ForegroundColor Red
Write-Host "  Will be included in Phase 1B: $($stats.MisclassifiedOrgs)" -ForegroundColor Green

Write-Host "`nSingle-Name Contacts:" -ForegroundColor Yellow
Write-Host "  Fixed (Last Name = 'UNKNOWN'): $($stats.SingleNameFixed)" -ForegroundColor Green

Write-Host "`nDuplicate Handling:" -ForegroundColor Yellow
Write-Host "  High-Confidence Duplicates Found: $($stats.HighConfidenceDuplicates)" -ForegroundColor White
Write-Host "  Auto-Merged: $($stats.AutoMergedDuplicates)" -ForegroundColor Green
Write-Host "  Shared Emails (Family): $($stats.SharedEmails)" -ForegroundColor White

Write-Host "`nData Quality:" -ForegroundColor Yellow
Write-Host "  Couple/Joint Names: $($stats.CoupleNames)" -ForegroundColor White
Write-Host "  Households Preserved: $($stats.HouseholdsPreserved)" -ForegroundColor White

Write-Host "`nAddress Validation:" -ForegroundColor Yellow
Write-Host "  Incomplete Addresses (cleared): $($stats.AddressIncomplete)" -ForegroundColor $(if ($stats.AddressIncomplete -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "  Missing Country Code (flagged): $($stats.AddressMissingCountry)" -ForegroundColor $(if ($stats.AddressMissingCountry -gt 0) { 'Yellow' } else { 'Green' })

if ($stats.PreMatchedExisting -gt 0) {
    Write-Host "`nPre-Existing GiveButter Contacts:" -ForegroundColor Yellow
    Write-Host "  Matched for Upsert: $($stats.PreMatchedExisting)" -ForegroundColor Cyan
    Write-Host "  These will UPDATE instead of creating duplicates" -ForegroundColor Green
}

Write-Host "`nCustom Fields Populated:" -ForegroundColor Yellow
Write-Host "  NFG_ID: $($customFieldStats.NFG_ID)" -ForegroundColor Green
Write-Host "  NFG_Type: $($customFieldStats.NFG_Type)" -ForegroundColor Green
Write-Host "  NFG_Household_Members: $($customFieldStats.NFG_Household_Members)" -ForegroundColor White
Write-Host "  NFG_Data_Quality_Flags: $($customFieldStats.NFG_Data_Quality_Flags)" -ForegroundColor White
Write-Host "  NFG_Duplicate_Source: $($customFieldStats.NFG_Duplicate_Source)" -ForegroundColor White
Write-Host "  NFG_Original_and_Merged_Addresses: $($customFieldStats.NFG_Original_and_Merged_Addresses)" -ForegroundColor White
Write-Host "  NFG_Original_Donor_Since: $($customFieldStats.NFG_Original_Donor_Since)" -ForegroundColor White
Write-Host "  NFG_Combined_Lifetime_Value: $($customFieldStats.NFG_Combined_Lifetime_Value)" -ForegroundColor White
Write-Host "  NFG_Merge_Date: $($customFieldStats.NFG_Merge_Date)" -ForegroundColor White

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. Review REVIEW_*.csv files for data quality issues" -ForegroundColor Yellow
Write-Host "2. Import GiveButter_Individuals_Import_*.csv to GiveButter" -ForegroundColor Yellow
Write-Host "3. Export individuals from GiveButter (with new Contact IDs)" -ForegroundColor Yellow
Write-Host "4. Save GiveButter export as 'reference files\GiveButter_Individuals_Export.csv'" -ForegroundColor Yellow
Write-Host "5. Run Phase 1B to prepare companies (uses same N4G export)" -ForegroundColor Yellow
Write-Host "6. Import companies to GiveButter" -ForegroundColor Yellow
Write-Host "7. Export companies from GiveButter (with new Contact IDs)" -ForegroundColor Yellow
Write-Host "8. Save GiveButter export as 'reference files\GiveButter_Companies_Export.csv'" -ForegroundColor Yellow
Write-Host "9. Run Phase 2 with both GiveButter exports to map IDs" -ForegroundColor Yellow
Write-Host ""

# Save summary
$summaryFile = "$OutputFolder\Phase1A_Summary_$timestamp.txt"
@"
PHASE 1A: INDIVIDUAL CONTACT PREPARATION SUMMARY
Generated: $(Get-Date)
========================================

STATISTICS:
- Total N4G Contacts: $($contacts.Count)
- Individuals Exported: $($stats.Individuals)
- Organizations (for Phase 1B): $($stats.Organizations + $stats.MisclassifiedOrgs)

ORGANIZATION DETECTION:
- Misclassified as Individuals: $($stats.MisclassifiedOrgs)
- Excluded from Individuals Export: $($stats.MisclassifiedOrgs)
- Will be included in Phase 1B: $($stats.MisclassifiedOrgs)

SINGLE-NAME CONTACTS:
- Fixed (Last Name = 'UNKNOWN'): $($stats.SingleNameFixed)

DUPLICATE HANDLING:
- High-Confidence Duplicates: $($stats.HighConfidenceDuplicates)
- Auto-Merged: $($stats.AutoMergedDuplicates)
- Shared Emails (Family): $($stats.SharedEmails)

DATA QUALITY:
- Couple/Joint Names: $($stats.CoupleNames)
- Households Preserved: $($stats.HouseholdsPreserved)

ADDRESS VALIDATION:
- Incomplete Addresses (cleared): $($stats.AddressIncomplete)
- Missing Country Code (flagged): $($stats.AddressMissingCountry)
- Note: Original address data preserved in NFG_Original_and_Merged_Addresses

CUSTOM FIELDS POPULATED:
- NFG_ID: $($customFieldStats.NFG_ID)
- NFG_Type: $($customFieldStats.NFG_Type)
- NFG_Household_Members: $($customFieldStats.NFG_Household_Members)
- NFG_Data_Quality_Flags: $($customFieldStats.NFG_Data_Quality_Flags)
- NFG_Duplicate_Source: $($customFieldStats.NFG_Duplicate_Source)
- NFG_Original_and_Merged_Addresses: $($customFieldStats.NFG_Original_and_Merged_Addresses)
- NFG_Original_Donor_Since: $($customFieldStats.NFG_Original_Donor_Since)
- NFG_Combined_Lifetime_Value: $($customFieldStats.NFG_Combined_Lifetime_Value)
- NFG_Merge_Date: $($customFieldStats.NFG_Merge_Date)

FILES CREATED:
- GiveButter Import: $outputFile
- ID Mapping Template: $mappingOutputFile
- Org Conversions Review: REVIEW_OrgConversions_$timestamp.csv
- High Confidence Duplicates: REVIEW_HighConfidenceDuplicates_$timestamp.csv
- Shared Emails Review: REVIEW_SharedEmails_$timestamp.csv
- Couple Names Review: REVIEW_CoupleNames_$timestamp.csv
- Multi-Member Households: INFO_MultiMemberHouseholds_$timestamp.csv

NEXT STEPS:
1. Review all REVIEW_*.csv files for data quality
2. Import GiveButter_Individuals_Import_*.csv to GiveButter
3. Export individuals from GiveButter (with new Contact IDs)
4. Save GiveButter individuals export to 'reference files' folder
   Example: 'reference files\GiveButter_Individuals_Export.csv'
5. Run Phase 1B to prepare companies (uses same N4G export)
6. Import companies to GiveButter
7. Export companies from GiveButter (with new Contact IDs)
8. Save GiveButter companies export to 'reference files' folder
   Example: 'reference files\GiveButter_Companies_Export.csv'
9. Run Phase 2 to map N4G IDs to GiveButter Contact IDs
   Command: .\Phase2-MapIDs-Enhanced.ps1 `
            -IndividualMappingFile "output\N4G_to_GiveButter_Mapping_Individuals_$timestamp.csv" `
            -CompanyMappingFile "output\N4G_to_GiveButter_Mapping_Companies_*.csv" `
            -GiveButterContactsExport "reference files\GiveButter_Individuals_Export.csv" `
            -GiveButterCompaniesExport "reference files\GiveButter_Companies_Export.csv" `
            -OutputFolder "output"
"@ | Out-File $summaryFile

Write-Host "Summary saved to: $summaryFile" -ForegroundColor Green
Write-Host "Log saved to: $logFile" -ForegroundColor Green
Write-Host ""

# Stop transcript logging
Stop-Transcript
