# Cleanup script - Archives old test/duplicate files, keeps only latest production files

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "CLEANUP: Archive Old Files" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# ============================================
# REFERENCE FILES CLEANUP
# ============================================
Write-Host "Cleaning reference files..." -ForegroundColor Yellow

# Files to KEEP in reference files (latest/needed only)
$keepReferenceFiles = @(
    "CTL N4G Contact export (full).csv",  # Source data
    "CTL N4G Transaction export (Through 2026-04-08 1600p eastern) (1).csv",  # Source data
    "givebutter-export-contacts-2026-04-19-925810037.csv",  # Latest contacts export
    "givebutter-export-companies-2026-04-19-1920878459.csv",  # Latest companies export
    "givebutter-contacts-import-template.csv",  # Template
    "givebutter-contacts-import-template.xlsx"  # Template
)

# Archive everything else
$allReferenceFiles = Get-ChildItem "reference files" -File
$archived = 0
foreach ($file in $allReferenceFiles) {
    if ($keepReferenceFiles -notcontains $file.Name) {
        Move-Item $file.FullName "reference files\archive\$($file.Name)" -Force
        $archived++
    }
}
Write-Host "  Archived $archived old reference files" -ForegroundColor Green

# ============================================
# OUTPUT FILES CLEANUP
# ============================================
Write-Host "`nCleaning output files..." -ForegroundColor Yellow

# Keep only the LATEST of each type
$latestFiles = @{
    "GiveButter_Individuals_Import" = "20260419_115800"
    "GiveButter_Companies_Import" = "20260419_153330"
    "GiveButter_Transactions_Import" = "20260419_172117"
    "ID_Lookup_Unified_ForPhase3" = "20260419_161324"
    "INFO_FeeAnalysis" = "20260419_172117"
    "N4G_to_GiveButter_Mapping_Individuals_UPDATED" = "20260419_161324"
    "N4G_to_GiveButter_Mapping_Companies_UPDATED" = "20260419_161324"
}

# Keep these review/info files (from latest runs)
$keepOutputFiles = @(
    "INFO_MultiMemberHouseholds_20260419_115800.csv",
    "INFO_SingleNameContactsFixed_20260419_115800.csv",
    "REVIEW_CompanyPOCs_20260419_153330.csv",
    "REVIEW_CoupleNames_20260419_115800.csv",
    "REVIEW_HighConfidenceDuplicates_20260419_115800.csv",
    "REVIEW_OrgConversions_20260419_115800.csv",
    "Phase1A_Summary_20260419_115800.txt",
    "Phase1B_Summary_20260419_153330.txt",
    "Phase2_Summary_20260419_161324.txt",
    "Phase3_Summary_20260419_172117.txt"
)

# Add latest versions to keep list
foreach ($pattern in $latestFiles.Keys) {
    $timestamp = $latestFiles[$pattern]
    $keepOutputFiles += "${pattern}_${timestamp}.csv"
}

# Archive everything else
$allOutputFiles = Get-ChildItem "output" -File
$archivedOutput = 0
foreach ($file in $allOutputFiles) {
    if ($keepOutputFiles -notcontains $file.Name) {
        Move-Item $file.FullName "output\archive\$($file.Name)" -Force
        $archivedOutput++
    }
}
Write-Host "  Archived $archivedOutput old output files" -ForegroundColor Green

# ============================================
# SUMMARY
# ============================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "CLEANUP COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Reference Files:" -ForegroundColor Yellow
Write-Host "  Kept: $($keepReferenceFiles.Count) essential files" -ForegroundColor Green
Write-Host "  Archived: $archived old files" -ForegroundColor Gray

Write-Host "`nOutput Files:" -ForegroundColor Yellow
Write-Host "  Kept: $($keepOutputFiles.Count) latest production files" -ForegroundColor Green
Write-Host "  Archived: $archivedOutput old test/duplicate files" -ForegroundColor Gray

Write-Host "`nArchived files can be found in:" -ForegroundColor White
Write-Host "  reference files\archive\" -ForegroundColor Magenta
Write-Host "  output\archive\" -ForegroundColor Magenta
Write-Host ""
