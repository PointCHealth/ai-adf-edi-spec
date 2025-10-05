# Deploy Dependabot Configuration Files to All Repositories
# This script copies the Dependabot configuration files to each repository

param(
    [Parameter(Mandatory=$false)]
    [string]$ReposBasePath = "c:\repos\edi-platform",
    
    [Parameter(Mandatory=$false)]
    [switch]$CommitAndPush = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$CommitMessage = "chore: Add Dependabot configuration for automated dependency updates"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Dependabot Configuration Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Define repository mappings
$repositories = @(
    @{
        Name = "edi-platform-core"
        ConfigFile = "edi-platform-core-dependabot.yml"
    },
    @{
        Name = "edi-mappers"
        ConfigFile = "edi-mappers-dependabot.yml"
    },
    @{
        Name = "edi-connectors"
        ConfigFile = "edi-connectors-dependabot.yml"
    },
    @{
        Name = "edi-partner-configs"
        ConfigFile = "edi-partner-configs-dependabot.yml"
    },
    @{
        Name = "edi-data-platform"
        ConfigFile = "edi-data-platform-dependabot.yml"
    }
)

$sourceDir = "$PSScriptRoot"
$successCount = 0
$failCount = 0

foreach ($repo in $repositories) {
    $repoName = $repo.Name
    $configFile = $repo.ConfigFile
    $repoPath = Join-Path $ReposBasePath $repoName
    $sourceFile = Join-Path $sourceDir $configFile
    
    Write-Host "Processing: $repoName" -ForegroundColor Yellow
    Write-Host "  Source: $sourceFile"
    Write-Host "  Target: $repoPath"
    
    # Check if repository exists
    if (-not (Test-Path $repoPath)) {
        Write-Host "  ❌ ERROR: Repository path not found: $repoPath" -ForegroundColor Red
        $failCount++
        continue
    }
    
    # Check if source config file exists
    if (-not (Test-Path $sourceFile)) {
        Write-Host "  ❌ ERROR: Source config file not found: $sourceFile" -ForegroundColor Red
        $failCount++
        continue
    }
    
    # Create .github directory if it doesn't exist
    $githubDir = Join-Path $repoPath ".github"
    if (-not (Test-Path $githubDir)) {
        Write-Host "  📁 Creating .github directory..."
        New-Item -ItemType Directory -Path $githubDir -Force | Out-Null
    }
    
    # Copy the Dependabot config file
    $targetFile = Join-Path $githubDir "dependabot.yml"
    try {
        Copy-Item -Path $sourceFile -Destination $targetFile -Force
        Write-Host "  ✅ Copied: dependabot.yml" -ForegroundColor Green
        
        # Commit and push if requested
        if ($CommitAndPush) {
            Push-Location $repoPath
            try {
                # Check if file is already tracked or new
                $gitStatus = git status --porcelain .github/dependabot.yml 2>&1
                
                if ($gitStatus) {
                    Write-Host "  📝 Committing changes..."
                    git add .github/dependabot.yml
                    git commit -m $CommitMessage
                    
                    Write-Host "  🚀 Pushing to remote..."
                    git push origin main
                    
                    Write-Host "  ✅ Committed and pushed successfully" -ForegroundColor Green
                } else {
                    Write-Host "  ℹ️  No changes detected (file already up-to-date)" -ForegroundColor Gray
                }
            }
            catch {
                Write-Host "  ❌ ERROR during git operations: $_" -ForegroundColor Red
                $failCount++
            }
            finally {
                Pop-Location
            }
        }
        
        $successCount++
    }
    catch {
        Write-Host "  ❌ ERROR copying file: $_" -ForegroundColor Red
        $failCount++
    }
    
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ Successful: $successCount" -ForegroundColor Green
Write-Host "❌ Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($CommitAndPush) {
    Write-Host "Changes have been committed and pushed to all repositories." -ForegroundColor Green
} else {
    Write-Host "Files copied but not committed. Run with -CommitAndPush to commit and push." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To commit and push manually:" -ForegroundColor Cyan
    Write-Host "  cd <repo-path>" -ForegroundColor Gray
    Write-Host "  git add .github/dependabot.yml" -ForegroundColor Gray
    Write-Host "  git commit -m 'chore: Add Dependabot configuration'" -ForegroundColor Gray
    Write-Host "  git push origin main" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Navigate to each repository on GitHub" -ForegroundColor Gray
Write-Host "2. Go to Insights → Dependency graph → Dependabot" -ForegroundColor Gray
Write-Host "3. Verify 'Dependabot is active' message appears" -ForegroundColor Gray
Write-Host "4. Wait for initial dependency update PRs (may take up to 1 hour)" -ForegroundColor Gray
Write-Host ""

exit $(if ($failCount -gt 0) { 1 } else { 0 })
