# Phase 1B: Prepare Company Contacts for GiveButter Import
# Based on testing completed April 15-16, 2026
# See NOTES_TESTED_GIVEBUTTER_IMPORTS.md for test results
# MUST run Phase 1A first and import individuals to GiveButter

param(
    [string]$InputFile = "N4G Contact export (full).csv",
    [string]$IndividualMappingFile = "",  # From Phase 1A export
    [string]$OutputFolder = "output",
    [switch]$SkipReview
)

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
$logFile = Join-Path $logsFolder "Phase1B_Log_$timestamp.txt"
Start-Transcript -Path $logFile -Append

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Phase 1B: Company Contact Preparation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Validate individual mapping file
if ($IndividualMappingFile -eq "" -or -not (Test-Path $IndividualMappingFile)) {
    Write-Host "ERROR: Individual mapping file required!" -ForegroundColor Red
    Write-Host "You must:" -ForegroundColor Yellow
    Write-Host "  1. Run Phase 1A to create individual import file" -ForegroundColor Yellow
    Write-Host "  2. Import individuals to GiveButter" -ForegroundColor Yellow
    Write-Host "  3. Export contacts from GiveButter (with Givebutter Contact IDs)" -ForegroundColor Yellow
    Write-Host "  4. Provide that export file as -IndividualMappingFile parameter`n" -ForegroundColor Yellow
    Write-Host "Example:" -ForegroundColor Cyan
    Write-Host '  .\Phase1B-PrepareCompanies.ps1 -IndividualMappingFile "contacts-export-2026-04-16.csv"' -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host "Loading individual mapping data..." -ForegroundColor Yellow

# Check for duplicate columns in GiveButter export (common issue with archived fields)
$cleanedFile = $IndividualMappingFile -replace '\.csv$', '_CLEANED.csv'
if (Test-Path $cleanedFile) {
    Write-Host "Using existing cleaned file: $cleanedFile" -ForegroundColor Cyan
    $individualMapping = Import-Csv $cleanedFile
} else {
    try {
        $individualMapping = Import-Csv $IndividualMappingFile
    } catch {
        if ($_.Exception.Message -match "already present") {
            Write-Host "Duplicate columns detected in GiveButter export. Creating cleaned version..." -ForegroundColor Yellow
            
            # Read raw content and fix duplicate columns
            $content = Get-Content $IndividualMappingFile -Raw
            $lines = $content -split "`r?`n"
            $header = $lines[0]
            
            # Find and rename duplicate columns
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
            
            # Write cleaned file
            $lines[0] = $newColumns -join ','
            $lines | Out-File $cleanedFile -Encoding UTF8
            
            Write-Host "Created cleaned file: $cleanedFile" -ForegroundColor Green
            $individualMapping = Import-Csv $cleanedFile
        } else {
            throw
        }
    }
}

Write-Host "Loaded $($individualMapping.Count) individual contacts from GiveButter export`n" -ForegroundColor Green

# Create lookup: NFG_ID -> Givebutter Contact ID (including merged duplicates)
$pocLookup = @{}
foreach ($individual in $individualMapping) {
    if ($individual.'Givebutter Contact ID' -ne '') {
        # Add primary NFG_ID
        if ($individual.NFG_ID -ne '') {
            $pocLookup[$individual.NFG_ID] = @{
                GivebutterID = $individual.'Givebutter Contact ID'
                FirstName = $individual.'First Name'
                LastName = $individual.'Last Name'
                Email = $individual.'Primary Email'
                Phone = $individual.'Primary Phone'
            }
        }
        
        # Add all merged NFG_IDs from NFG_Duplicate_Source
        if ($individual.NFG_Duplicate_Source -ne '') {
            $mergedIDs = $individual.NFG_Duplicate_Source -split ',\s*'
            foreach ($mergedID in $mergedIDs) {
                if ($mergedID -ne '' -and -not $pocLookup.ContainsKey($mergedID)) {
                    $pocLookup[$mergedID] = @{
                        GivebutterID = $individual.'Givebutter Contact ID'
                        FirstName = $individual.'First Name'
                        LastName = $individual.'Last Name'
                        Email = $individual.'Primary Email'
                        Phone = $individual.'Primary Phone'
                    }
                }
            }
        }
    }
}
Write-Host "Created POC lookup for $($pocLookup.Count) N4G IDs (including merged duplicates)`n" -ForegroundColor Green

Write-Host "Loading N4G contact data..." -ForegroundColor Yellow
$contacts = Import-Csv $InputFile
Write-Host "Loaded $($contacts.Count) total contacts`n" -ForegroundColor Green

# Create a name-to-N4G-ID lookup for individuals (to find POCs by name)
Write-Host "Creating POC name lookup..." -ForegroundColor Yellow
$individualsByName = @{}
$individuals = $contacts | Where-Object { $_.Type -eq 'Individual' }
foreach ($individual in $individuals) {
    if ($individual.'Full Name' -ne '') {
        # Store as array in case multiple people have same name
        if (-not $individualsByName.ContainsKey($individual.'Full Name')) {
            $individualsByName[$individual.'Full Name'] = @()
        }
        $individualsByName[$individual.'Full Name'] += $individual.Id
    }
}
Write-Host "Created name lookup for $($individualsByName.Count) unique names`n" -ForegroundColor Green

# Initialize tracking
$stats = @{
    TotalContacts = $contacts.Count
    Organizations = 0
    POC_Found = 0
    POC_NotFound = 0
    POC_WillAutoCreate = 0
}

# Track custom field population
$customFieldStats = @{
    NFG_ID = 0
    NFG_Type = 0
    NFG_Point_Of_Contact = 0
    NFG_Data_Quality_Flags = 0
    NFG_Duplicate_Source = 0
    NFG_Alternate_Contacts = 0
    NFG_Original_and_Merged_Addresses = 0
}

# 1. Filter to organizations (including misclassified individuals from Phase 1A)
Write-Host "1. Filtering to organization contacts..." -ForegroundColor Cyan

# Load OrgConversions file from Phase 1A (if it exists)
$orgConversionIDs = @()
$orgConversionFiles = Get-ChildItem $OutputFolder -Filter "REVIEW_OrgConversions_*.csv" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if ($orgConversionFiles.Count -gt 0) {
    $orgConvFile = $orgConversionFiles[0].FullName
    Write-Host "   Loading org conversions from Phase 1A: $($orgConversionFiles[0].Name)" -ForegroundColor Cyan
    $orgConversions = Import-Csv $orgConvFile
    $orgConversionIDs = $orgConversions | ForEach-Object { $_.N4G_ID }
    Write-Host "   Found $($orgConversionIDs.Count) converted orgs from Phase 1A" -ForegroundColor Green
}

# Organization detection patterns (same as Phase 1A)
$orgPatterns = @(
    'LLC', 'Inc\.?', 'Foundation', 'Corp\.?', 'Ltd\.?', 'LLP', 'PLLC', 
    'P\.C\.', 'P\.A\.', 'Trust', 'Company', 'Co\.', 'Group', 'Partners', 
    'Associates', 'Properties', 'Holdings', 'Enterprises', 'Solutions', 
    'Services', 'Management', 'Consulting', 'Advisors', 'Capital', 
    'Investments', 'Ventures', 'Fund', 'Charity', 'Society', 'Association', 
    'Institute', 'Center', 'Centre', 'Organization', 'Rotary', 'Church', 
    'Ministry', 'Ministries'
)
$orgRegex = '\b(' + ($orgPatterns -join '|') + ')\b'

# Get organizations (Type = 'Organization')
$orgContacts = $contacts | Where-Object { $_.Type -eq 'Organization' }
$orgCount = $orgContacts.Count

# Also get misclassified individuals (Type = 'Individual' but name matches org pattern OR in OrgConversions)
$misclassifiedOrgs = $contacts | Where-Object { 
    $_.Type -eq 'Individual' -and (
        $_.'Full Name' -match $orgRegex -or
        $orgConversionIDs -contains $_.Id
    )
}
$misclassifiedCount = $misclassifiedOrgs.Count

# Combine both
$orgContacts = @($orgContacts) + @($misclassifiedOrgs)

Write-Host "   Found $orgCount organizations (Type = 'Organization')" -ForegroundColor Green
Write-Host "   Found $misclassifiedCount misclassified individuals (will convert to orgs)" -ForegroundColor Yellow
if ($orgConversionIDs.Count -gt 0) {
    Write-Host "   (Includes $($orgConversionIDs.Count) from Phase 1A OrgConversions)" -ForegroundColor Cyan
}
Write-Host "   Total companies to process: $($orgContacts.Count)`n" -ForegroundColor Cyan

# 2. Analyze Point of Contact data
Write-Host "2. Analyzing Point of Contact information..." -ForegroundColor Cyan
$pocAnalysis = @()

foreach ($org in $orgContacts) {
    $pocStatus = 'Unknown'
    $pocGBID = ''
    $pocName = ''
    $pocEmail = ''
    $pocPhone = ''
    $pocMethod = ''
    
    # Check if org has POC data in N4G
    if ($org.'Point Of Contact' -ne '') {
        $pocName = $org.'Point Of Contact'
        $pocEmail = $org.'Point Of Contact Email'
        $pocPhone = $org.'Point Of Contact Phone'
        
        # FIRST: Try to find POC by name in N4G individuals, then lookup in GiveButter
        if ($pocName -ne '' -and $individualsByName.ContainsKey($pocName)) {
            $pocN4GIDs = $individualsByName[$pocName]
            # Try each N4G ID (in case of duplicate names)
            $foundPOC = $false
            foreach ($pocN4GID in $pocN4GIDs) {
                if ($pocLookup.ContainsKey($pocN4GID)) {
                    $pocData = $pocLookup[$pocN4GID]
                    $pocGBID = $pocData.GivebutterID
                    $pocStatus = 'Found in GiveButter (by name match)'
                    $pocMethod = 'Existing POC (via name → N4G ID → GiveButter ID)'
                    $stats.POC_Found++
                    $foundPOC = $true
                    break
                }
            }
            
            if (-not $foundPOC) {
                # POC name found in N4G but not yet in GiveButter (shouldn't happen after Phase 1A)
                $pocStatus = 'Found in N4G but not in GiveButter'
                $pocMethod = 'Will Auto-Create'
                $stats.POC_WillAutoCreate++
            }
        }
        # SECOND: Try to find POC by email if name lookup failed
        elseif ($pocEmail -ne '') {
            $matchedIndividual = $individualMapping | Where-Object { 
                $_.'Primary Email' -eq $pocEmail -or 
                $_.'Additional Emails' -match [regex]::Escape($pocEmail)
            } | Select-Object -First 1
            
            if ($matchedIndividual) {
                $pocGBID = $matchedIndividual.'Givebutter Contact ID'
                $pocStatus = 'Found in GiveButter (by email)'
                $pocMethod = 'Existing POC (via email match)'
                $stats.POC_Found++
            }
            else {
                $pocStatus = 'Not Found - Will Auto-Create'
                $pocMethod = 'New POC (auto-create)'
                $stats.POC_WillAutoCreate++
            }
        }
        # THIRD: Try to find POC by phone if email lookup failed
        elseif ($pocPhone -ne '') {
            # Normalize phone for comparison (remove formatting)
            $normalizedPOCPhone = $pocPhone -replace '[^\d]', ''
            
            $matchedIndividual = $individualMapping | Where-Object { 
                $primaryPhone = $_.'Primary Phone' -replace '[^\d]', ''
                $additionalPhones = $_.'Additional Phones' -replace '[^\d]', ''
                $primaryPhone -eq $normalizedPOCPhone -or 
                $additionalPhones -match [regex]::Escape($normalizedPOCPhone)
            } | Select-Object -First 1
            
            if ($matchedIndividual) {
                $pocGBID = $matchedIndividual.'Givebutter Contact ID'
                $pocStatus = 'Found in GiveButter (by phone)'
                $pocMethod = 'Existing POC (via phone match)'
                $stats.POC_Found++
            }
            else {
                $pocStatus = 'Not Found - Will Auto-Create'
                $pocMethod = 'New POC (auto-create with phone)'
                $stats.POC_WillAutoCreate++
            }
        }
        else {
            $pocStatus = 'No Contact Info - Cannot Link'
            $pocMethod = 'Manual Review Required'
            $stats.POC_NotFound++
        }
    }
    else {
        # No POC data in N4G - use organization email as POC
        $pocStatus = 'No POC Data - Using Org Email'
        $pocMethod = 'New POC (org email)'
        $stats.POC_WillAutoCreate++
    }
    
    $pocAnalysis += [PSCustomObject]@{
        N4G_ID = $org.Id
        Company_Name = $org.'Full Name'
        POC_Status = $pocStatus
        POC_Method = $pocMethod
        POC_Name = $pocName
        POC_Email = $pocEmail
        POC_Phone = $pocPhone
        POC_GiveButter_ID = $pocGBID
        Org_Email = $org.'Primary Email'
    }
}

$pocAnalysis | Export-Csv "$OutputFolder\REVIEW_CompanyPOCs_$timestamp.csv" -NoTypeInformation
Write-Host "   POCs Found in GiveButter: $($stats.POC_Found)" -ForegroundColor Green
Write-Host "   POCs Will Auto-Create: $($stats.POC_WillAutoCreate)" -ForegroundColor Yellow
Write-Host "   POCs Need Manual Review: $($stats.POC_NotFound)" -ForegroundColor $(if ($stats.POC_NotFound -gt 0) { 'Red' } else { 'Green' })
Write-Host "   → Exported to REVIEW_CompanyPOCs_$timestamp.csv`n" -ForegroundColor Magenta

# 3. Prepare GiveButter company import file
Write-Host "3. Preparing GiveButter company import file..." -ForegroundColor Cyan

$giveButterCompanies = foreach ($org in $orgContacts) {
    # Get POC analysis for this org
    $pocInfo = $pocAnalysis | Where-Object { $_.N4G_ID -eq $org.Id }
    
    # Initialize custom fields
    $nfg_data_quality_flags = @()
    $nfg_poc_info = ''
    $nfg_duplicate_source = @($org.Id)  # Start with org's own N4G ID
    $nfg_alternate_contacts = @()
    $nfg_addresses = @()
    
    # Build POC info for custom field
    if ($org.'Point Of Contact' -ne '') {
        $pocParts = @()
        if ($org.'Point Of Contact' -ne '') { $pocParts += $org.'Point Of Contact' }
        if ($org.'Point Of Contact Email' -ne '') { $pocParts += $org.'Point Of Contact Email' }
        if ($org.'Point Of Contact Phone' -ne '') { $pocParts += $org.'Point Of Contact Phone' }
        $nfg_poc_info = ($pocParts -join ', ')
        if ($nfg_poc_info.Length -gt $STANDARD_TEXT_LIMIT) {
            $nfg_poc_info = $nfg_poc_info.Substring(0, ($STANDARD_TEXT_LIMIT - 3)) + '...'
        }
    }
    
    # Collect alternate emails
    $alternateEmails = @()
    if ($org.'Work Email' -ne '' -and $org.'Work Email' -ne $org.'Primary Email') {
        $alternateEmails += $org.'Work Email'
    }
    if ($org.'Secondary Email' -ne '' -and $org.'Secondary Email' -ne $org.'Primary Email') {
        $alternateEmails += $org.'Secondary Email'
    }
    
    # Collect alternate phones
    $alternatePhones = @()
    if ($org.'Home Phone' -ne '' -and $org.'Home Phone' -ne $org.'Mobile Phone') {
        $alternatePhones += $org.'Home Phone'
    }
    if ($org.'Work Phone' -ne '' -and $org.'Work Phone' -ne $org.'Mobile Phone') {
        $alternatePhones += $org.'Work Phone'
    }
    
    # Build alternate contacts string
    if ($alternateEmails.Count -gt 0 -or $alternatePhones.Count -gt 0) {
        $contactParts = @()
        if ($alternateEmails.Count -gt 0) {
            $contactParts += "EMAILS: $($alternateEmails -join ', ')"
        }
        if ($alternatePhones.Count -gt 0) {
            $contactParts += "PHONES: $($alternatePhones -join ', ')"
        }
        $nfg_alternate_contacts = $contactParts
    }
    
    # Collect PRIMARY address (always preserve like individuals)
    if ($org.Address -ne '') {
        $primaryAddrParts = @($org.Address)
        if ($org.'Address 2' -ne '') { $primaryAddrParts += $org.'Address 2' }
        if ($org.City -ne '') { $primaryAddrParts += $org.City }
        if ($org.State -ne '') { $primaryAddrParts += $org.State }
        if ($org.'Zip Code' -ne '') { $primaryAddrParts += $org.'Zip Code' }
        if ($org.Country -ne '') { $primaryAddrParts += $org.Country }
        $nfg_addresses += "PRIMARY: $($primaryAddrParts -join ', ')"
    }
    
    # Collect work address if different from primary
    if ($org.'Work Address' -ne '' -and $org.'Work Address' -ne $org.Address) {
        $workAddrParts = @($org.'Work Address')
        if ($org.'Work Address 2' -ne '') { $workAddrParts += $org.'Work Address 2' }
        if ($org.'Work City' -ne '') { $workAddrParts += $org.'Work City' }
        if ($org.'Work State' -ne '') { $workAddrParts += $org.'Work State' }
        if ($org.'Work Zip Code' -ne '') { $workAddrParts += $org.'Work Zip Code' }
        if ($org.'Work Country' -ne '') { $workAddrParts += $org.'Work Country' }
        $nfg_addresses += "WORK: $($workAddrParts -join ', ')"
    }
    
    # Format long text fields
    $nfg_duplicate_source_str = ($nfg_duplicate_source | Select-Object -Unique) -join ', '
    $nfg_alternate_contacts_str = ($nfg_alternate_contacts -join ' | ')
    $nfg_addresses_str = ($nfg_addresses -join ' | ')
    
    # Truncate if needed (long text fields support 2000+ chars, but be safe)
    if ($nfg_alternate_contacts_str.Length -gt $LONG_TEXT_SAFE_LIMIT) {
        $nfg_alternate_contacts_str = $nfg_alternate_contacts_str.Substring(0, ($LONG_TEXT_SAFE_LIMIT - 3)) + '...'
        $nfg_data_quality_flags += 'ALTERNATE_CONTACTS_TRUNCATED'
    }
    if ($nfg_addresses_str.Length -gt $LONG_TEXT_SAFE_LIMIT) {
        $nfg_addresses_str = $nfg_addresses_str.Substring(0, ($LONG_TEXT_SAFE_LIMIT - 3)) + '...'
        $nfg_data_quality_flags += 'ADDRESSES_TRUNCATED'
    }
    
    # Determine POC fields for import
    $poc_id = ''
    $poc_first = ''
    $poc_last = ''
    $poc_email = ''
    $poc_phone = ''
    
    if ($pocInfo.POC_GiveButter_ID -ne '') {
        # Use existing POC via Contact ID - also populate name/email/phone from GiveButter export
        $poc_id = $pocInfo.POC_GiveButter_ID
        
        # Look up POC details from GiveButter export
        $pocContact = $individualMapping | Where-Object { $_.'Givebutter Contact ID' -eq $pocInfo.POC_GiveButter_ID } | Select-Object -First 1
        if ($pocContact) {
            $poc_first = $pocContact.'First Name'
            $poc_last = $pocContact.'Last Name'
            $poc_email = $pocContact.'Primary Email'
            $poc_phone = $pocContact.'Primary Phone'
        }
    }
    elseif ($pocInfo.POC_Email -ne '') {
        # Auto-create POC with name/email
        $nameParts = $pocInfo.POC_Name -split '\s+', 2
        $poc_first = $nameParts[0]
        $poc_last = if ($nameParts.Length -gt 1) { $nameParts[1] } else { '' }
        $poc_email = $pocInfo.POC_Email
        $poc_phone = $pocInfo.POC_Phone
        $nfg_data_quality_flags += 'POC_AUTO_CREATED'
    }
    else {
        # No POC data - use org email to create POC
        $poc_first = $org.'Full Name'
        $poc_last = 'Contact'
        $poc_email = $org.'Primary Email'
        $nfg_data_quality_flags += 'POC_FROM_ORG_EMAIL'
    }
    
    # Phone validation: Check for invalid formats
    $primaryPhone = $org.'Mobile Phone'
    if ($primaryPhone -ne '') {
        # Check for invalid phone patterns (international formats that GiveButter rejects)
        if ($primaryPhone -match '^\+' -or $primaryPhone -match '^00' -or $primaryPhone -match '[^\d\s\-\(\)\.]') {
            # Move invalid phone to alternate contacts if not already there
            if ($nfg_alternate_contacts_str -notmatch [regex]::Escape($primaryPhone)) {
                if ($nfg_alternate_contacts_str -ne '') {
                    $nfg_alternate_contacts_str += " | PHONE NUMBER: $primaryPhone"
                } else {
                    $nfg_alternate_contacts_str = "PHONE NUMBER: $primaryPhone"
                }
            }
            $primaryPhone = ''  # Clear invalid phone
            $nfg_data_quality_flags += 'PHONE_INVALID_FORMAT'
        }
    }
    
    # Address validation: GiveButter requires ALL address fields or NONE
    $addressLine1 = $org.Address
    $addressLine2 = $org.'Address 2'
    $city = $org.City
    $state = $org.State
    $zipCode = $org.'Zip Code'
    $countryCode = $org.Country
    
    # Check if address is incomplete (has some fields but not all required ones)
    if ($addressLine1 -ne '' -and ($city -eq '' -or $state -eq '' -or $zipCode -eq '')) {
        # Clear all address fields to prevent import errors
        $addressLine1 = ''
        $addressLine2 = ''
        $city = ''
        $state = ''
        $zipCode = ''
        $countryCode = ''
        $nfg_data_quality_flags += 'ADDRESS_INCOMPLETE'
    }
    elseif ($addressLine1 -ne '' -and $countryCode -eq '') {
        $nfg_data_quality_flags += 'ADDRESS_MISSING_COUNTRY'
    }
    
    # Update stats
    $stats.Organizations++
    $customFieldStats.NFG_ID++
    $customFieldStats.NFG_Type++
    if ($nfg_poc_info -ne '') { $customFieldStats.NFG_Point_Of_Contact++ }
    if ($nfg_alternate_contacts_str -ne '') { $customFieldStats.NFG_Alternate_Contacts++ }
    if ($nfg_addresses_str -ne '') { $customFieldStats.NFG_Original_and_Merged_Addresses++ }
    
    # Determine email subscription status (GiveButter only accepts 'yes' or 'no')
    $emailSubStatus = if ($org.'Email Subscription Status' -eq 'yes') { 'yes' } else { 'no' }
    
    # Format data quality flags (after all validation)
    $nfg_data_quality_flags_str = ($nfg_data_quality_flags | Select-Object -Unique) -join ', '
    if ($nfg_data_quality_flags_str -ne '') { $customFieldStats.NFG_Data_Quality_Flags++ }
    
    # Create GiveButter company record
    [PSCustomObject]@{
        'Contact External ID' = $org.Id
        'Company' = $org.'Full Name'
        'Primary Email' = $org.'Primary Email'
        'Primary Phone Number' = $primaryPhone
        'Address Line 1' = $addressLine1
        'Address Line 2' = $addressLine2
        'City' = $city
        'State' = $state
        'Zip Code' = $zipCode
        'Country Code' = $countryCode
        'Tags' = $org.Groups
        'Notes' = $org.Notes
        'Email Subscription Status' = $emailSubStatus
        
        # Point of Contact fields
        'Point of Contact ID' = $poc_id
        'Point of Contact First Name' = $poc_first
        'Point of Contact Last Name' = $poc_last
        'Point of Contact Primary Email' = $poc_email
        'Point of Contact Primary Phone' = $poc_phone
        
        # CUSTOM FIELDS
        'NFG_ID' = $org.Id
        'NFG_Type' = 'Organization'
        'NFG_Household_Members' = ''  # Not applicable for organizations
        'NFG_Point_Of_Contact' = $nfg_poc_info
        'NFG_Data_Quality_Flags' = $nfg_data_quality_flags_str
        'NFG_Duplicate_Source' = $nfg_duplicate_source_str  # Org's N4G ID for reference
        'NFG_Alternate_Contacts' = $nfg_alternate_contacts_str  # Work/secondary emails and phones
        'NFG_Original_and_Merged_Addresses' = $nfg_addresses_str  # Work address if different
        'NFG_Original_Donor_Since' = ''  # Not applicable
        'NFG_Combined_Lifetime_Value' = ''  # Not applicable
        'NFG_Merge_Date' = ''  # Not applicable
    }
}

$outputFile = "$OutputFolder\GiveButter_Companies_Import_$timestamp.csv"
$giveButterCompanies | Export-Csv $outputFile -NoTypeInformation
Write-Host "   Created GiveButter import file with $($giveButterCompanies.Count) companies" -ForegroundColor Green
Write-Host "   → Saved to GiveButter_Companies_Import_$timestamp.csv`n" -ForegroundColor Magenta

# 4. Create mapping file for Phase 2
Write-Host "4. Creating N4G to GiveButter ID mapping template..." -ForegroundColor Cyan
$mappingFile = foreach ($company in $giveButterCompanies) {
    [PSCustomObject]@{
        N4G_ID = $company.'Contact External ID'
        N4G_Type = 'Organization'
        Full_Name = $company.Company
        Primary_Email = $company.'Primary Email'
        GiveButter_Contact_ID = ''
        Import_Status = 'Pending'
        Import_Date = ''
        Notes = ''
    }
}

$mappingOutputFile = "$OutputFolder\N4G_to_GiveButter_Mapping_Companies_$timestamp.csv"
$mappingFile | Export-Csv $mappingOutputFile -NoTypeInformation
Write-Host "   Created mapping template for $($mappingFile.Count) companies" -ForegroundColor Green
Write-Host "   → Saved to N4G_to_GiveButter_Mapping_Companies_$timestamp.csv`n" -ForegroundColor Magenta

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PHASE 1B SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Organizations Processed: $($stats.Organizations)" -ForegroundColor White

Write-Host "`nPoint of Contact Analysis:" -ForegroundColor Yellow
Write-Host "  POCs Found in GiveButter: $($stats.POC_Found)" -ForegroundColor Green
Write-Host "  POCs Will Auto-Create: $($stats.POC_WillAutoCreate)" -ForegroundColor Yellow
Write-Host "  POCs Need Manual Review: $($stats.POC_NotFound)" -ForegroundColor $(if ($stats.POC_NotFound -gt 0) { 'Red' } else { 'Green' })

Write-Host "`nCustom Fields Populated:" -ForegroundColor Yellow
Write-Host "  NFG_ID: $($customFieldStats.NFG_ID)" -ForegroundColor Green
Write-Host "  NFG_Type: $($customFieldStats.NFG_Type)" -ForegroundColor Green
Write-Host "  NFG_Point_Of_Contact: $($customFieldStats.NFG_Point_Of_Contact)" -ForegroundColor White
Write-Host "  NFG_Data_Quality_Flags: $($customFieldStats.NFG_Data_Quality_Flags)" -ForegroundColor White
Write-Host "  NFG_Duplicate_Source: $($customFieldStats.NFG_Duplicate_Source)" -ForegroundColor White
Write-Host "  NFG_Alternate_Contacts: $($customFieldStats.NFG_Alternate_Contacts)" -ForegroundColor White
Write-Host "  NFG_Original_and_Merged_Addresses: $($customFieldStats.NFG_Original_and_Merged_Addresses)" -ForegroundColor White

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. Review REVIEW_CompanyPOCs_$timestamp.csv" -ForegroundColor Yellow
Write-Host "2. Import GiveButter_Companies_Import_*.csv to GiveButter (as COMPANIES)" -ForegroundColor Yellow
Write-Host "3. Export companies from GiveButter (with new Contact IDs)" -ForegroundColor Yellow
Write-Host "4. Run Phase 2 to map all IDs (individuals + companies)" -ForegroundColor Yellow
Write-Host ""

# Save summary
$summaryFile = "$OutputFolder\Phase1B_Summary_$timestamp.txt"
@"
PHASE 1B: COMPANY CONTACT PREPARATION SUMMARY
Generated: $(Get-Date)
========================================

STATISTICS:
- Total Organizations: $($stats.Organizations)

POINT OF CONTACT ANALYSIS:
- POCs Found in GiveButter: $($stats.POC_Found)
- POCs Will Auto-Create: $($stats.POC_WillAutoCreate)
- POCs Need Manual Review: $($stats.POC_NotFound)

CUSTOM FIELDS POPULATED:
- NFG_ID: $($customFieldStats.NFG_ID)
- NFG_Type: $($customFieldStats.NFG_Type)
- NFG_Point_Of_Contact: $($customFieldStats.NFG_Point_Of_Contact)
- NFG_Data_Quality_Flags: $($customFieldStats.NFG_Data_Quality_Flags)
- NFG_Duplicate_Source: $($customFieldStats.NFG_Duplicate_Source)
- NFG_Alternate_Contacts: $($customFieldStats.NFG_Alternate_Contacts)
- NFG_Original_and_Merged_Addresses: $($customFieldStats.NFG_Original_and_Merged_Addresses)

FILES CREATED:
- GiveButter Import: $outputFile
- ID Mapping Template: $mappingOutputFile
- Company POC Review: REVIEW_CompanyPOCs_$timestamp.csv

NEXT STEPS:
1. Review REVIEW_CompanyPOCs_$timestamp.csv
2. Import GiveButter_Companies_Import_*.csv to GiveButter (as COMPANIES)
3. Export companies from GiveButter with new Contact IDs
4. Run Phase 2 to map all N4G IDs to GiveButter Contact IDs
"@ | Out-File $summaryFile

Write-Host "Summary saved to: $summaryFile" -ForegroundColor Green
Write-Host "Log saved to: $logFile" -ForegroundColor Green
Write-Host ""

# Stop transcript logging
Stop-Transcript
