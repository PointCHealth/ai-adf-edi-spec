# Deploy Documentation to Target Location
# Script to copy deployment documentation to edi-platform repository
# Created: October 6, 2025

param(
    [Parameter(Mandatory=$false)]
    [string]$TargetPath = "C:\repos\edi-platform\edi-documentation",
    
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "c:\repos\ai-adf-edi-spec\deployment-docs",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Deployment Documentation Setup Script" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Verify source path exists
if (-not (Test-Path $SourcePath)) {
    Write-Host "❌ ERROR: Source path not found: $SourcePath" -ForegroundColor Red
    exit 1
}

# Count source files
$sourceFiles = Get-ChildItem -Path $SourcePath -File
Write-Host "📁 Source Location: $SourcePath" -ForegroundColor Yellow
Write-Host "📄 Files to copy: $($sourceFiles.Count)" -ForegroundColor Yellow
Write-Host ""

# List files to be copied
Write-Host "Files:" -ForegroundColor Cyan
foreach ($file in $sourceFiles) {
    $sizeKB = [Math]::Round($file.Length / 1KB, 1)
    Write-Host "  - $($file.Name) ($sizeKB KB)" -ForegroundColor Gray
}
Write-Host ""

# Check if target path exists
if (Test-Path $TargetPath) {
    Write-Host "⚠️  Target directory already exists: $TargetPath" -ForegroundColor Yellow
    $existingFiles = Get-ChildItem -Path $TargetPath -File
    if ($existingFiles.Count -gt 0) {
        Write-Host "⚠️  Target directory contains $($existingFiles.Count) file(s)" -ForegroundColor Yellow
        Write-Host ""
        $overwrite = Read-Host "Overwrite existing files? (y/n)"
        if ($overwrite -ne 'y') {
            Write-Host "❌ Operation cancelled by user" -ForegroundColor Red
            exit 0
        }
    }
} else {
    Write-Host "📁 Target directory does not exist. Will create: $TargetPath" -ForegroundColor Yellow
}
Write-Host ""

# Perform the copy operation
if ($WhatIf) {
    Write-Host "🔍 WhatIf Mode - No changes will be made" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Would create directory: $TargetPath" -ForegroundColor Gray
    Write-Host "Would copy $($sourceFiles.Count) files from $SourcePath to $TargetPath" -ForegroundColor Gray
} else {
    try {
        # Create target directory
        Write-Host "📁 Creating target directory..." -ForegroundColor Cyan
        New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null
        Write-Host "✅ Directory created/verified" -ForegroundColor Green
        Write-Host ""
        
        # Copy files
        Write-Host "📋 Copying files..." -ForegroundColor Cyan
        $copiedCount = 0
        foreach ($file in $sourceFiles) {
            Write-Host "  Copying $($file.Name)..." -ForegroundColor Gray
            Copy-Item -Path $file.FullName -Destination $TargetPath -Force
            $copiedCount++
        }
        Write-Host "✅ $copiedCount file(s) copied successfully" -ForegroundColor Green
        Write-Host ""
        
        # Verify the copy
        Write-Host "🔍 Verifying copy..." -ForegroundColor Cyan
        $targetFiles = Get-ChildItem -Path $TargetPath -File
        if ($targetFiles.Count -ge $sourceFiles.Count) {
            Write-Host "✅ Verification passed - All files present in target" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Warning: Target has $($targetFiles.Count) files, expected $($sourceFiles.Count)" -ForegroundColor Yellow
        }
        Write-Host ""
        
        # Success summary
        Write-Host "=====================================" -ForegroundColor Green
        Write-Host "✅ Documentation Deployment Complete!" -ForegroundColor Green
        Write-Host "=====================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "📁 Documentation Location: $TargetPath" -ForegroundColor Cyan
        Write-Host "📄 Total Files: $($targetFiles.Count)" -ForegroundColor Cyan
        Write-Host ""
        
        # Next steps
        Write-Host "📋 Next Steps:" -ForegroundColor Yellow
        Write-Host "  1. Review the documentation:" -ForegroundColor White
        Write-Host "     code `"$TargetPath\README.md`"" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  2. Start with the setup guide:" -ForegroundColor White
        Write-Host "     code `"$TargetPath\02-github-actions-setup.md`"" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  3. Navigate to the directory:" -ForegroundColor White
        Write-Host "     cd `"$TargetPath`"" -ForegroundColor Gray
        Write-Host ""
        
        # Ask to open documentation
        $openDocs = Read-Host "Open README.md now? (y/n)"
        if ($openDocs -eq 'y') {
            code "$TargetPath\README.md"
            Write-Host "✅ Opening documentation in VS Code..." -ForegroundColor Green
        }
        
    } catch {
        Write-Host "❌ ERROR: Failed to copy files" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Script completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
