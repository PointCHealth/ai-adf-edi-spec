<#
.SYNOPSIS
    Creates all Azure Function projects for the Healthcare EDI Platform.

.DESCRIPTION
    This script scaffolds all function projects across the platform with proper
    structure, dependencies, and configuration for .NET 9 isolated worker model.

.NOTES
    Author: AI Agent
    Date: October 5, 2025
    Requires: .NET 9 SDK, Azure Functions Core Tools v4
#>

param(
    [string]$RootPath = "src/functions",
    [switch]$SkipRestore,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Function definitions
$functions = @(
    # edi-platform-core functions
    @{
        Name = "InboundRouter"
        Path = "platform-core"
        Description = "Routes incoming EDI files to processing queues"
        Triggers = @("EventGrid", "HTTP")
    },
    @{
        Name = "EnterpriseScheduler"
        Path = "platform-core"
        Description = "Schedules recurring EDI processing jobs"
        Triggers = @("Timer", "HTTP")
    },
    @{
        Name = "ControlNumberGenerator"
        Path = "platform-core"
        Description = "Generates and manages EDI control numbers"
        Triggers = @("ServiceBus", "HTTP")
    },
    @{
        Name = "FileArchiver"
        Path = "platform-core"
        Description = "Archives processed EDI files with retention policies"
        Triggers = @("Timer", "Queue")
    },
    @{
        Name = "NotificationService"
        Path = "platform-core"
        Description = "Sends notifications for processing events"
        Triggers = @("ServiceBus", "HTTP")
    },
    
    # edi-mappers functions
    @{
        Name = "EligibilityMapper"
        Path = "mappers"
        Description = "Maps 270/271 eligibility transactions"
        Triggers = @("ServiceBus", "HTTP")
    },
    @{
        Name = "ClaimsMapper"
        Path = "mappers"
        Description = "Maps 837/277 claims transactions"
        Triggers = @("ServiceBus", "HTTP")
    },
    @{
        Name = "EnrollmentMapper"
        Path = "mappers"
        Description = "Maps 834 enrollment transactions"
        Triggers = @("ServiceBus", "HTTP")
    },
    @{
        Name = "RemittanceMapper"
        Path = "mappers"
        Description = "Maps 835 remittance transactions"
        Triggers = @("ServiceBus", "HTTP")
    },
    
    # edi-connectors functions
    @{
        Name = "SftpConnector"
        Path = "connectors"
        Description = "SFTP-based file transfer connector"
        Triggers = @("ServiceBus", "Timer")
    },
    @{
        Name = "ApiConnector"
        Path = "connectors"
        Description = "RESTful API connector for partner integration"
        Triggers = @("ServiceBus", "HTTP")
    },
    @{
        Name = "DatabaseConnector"
        Path = "connectors"
        Description = "Database connector for direct partner integration"
        Triggers = @("ServiceBus", "Timer")
    }
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Healthcare EDI Function Projects Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Verify prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

try {
    $dotnetVersion = dotnet --version
    Write-Host "✓ .NET SDK: $dotnetVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ .NET SDK not found. Please install .NET 9 SDK." -ForegroundColor Red
    exit 1
}

try {
    $funcVersion = func --version
    Write-Host "✓ Azure Functions Core Tools: $funcVersion" -ForegroundColor Green
} catch {
    Write-Host "⚠ Azure Functions Core Tools not found. Install for local testing." -ForegroundColor Yellow
}

Write-Host ""

# Create root directories
$categories = @("platform-core", "mappers", "connectors")
foreach ($category in $categories) {
    $categoryPath = Join-Path $RootPath $category
    if (-not (Test-Path $categoryPath)) {
        New-Item -ItemType Directory -Path $categoryPath -Force | Out-Null
        Write-Host "Created directory: $categoryPath" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Creating function projects..." -ForegroundColor Yellow
Write-Host ""

# Create each function project
foreach ($func in $functions) {
    $funcName = "$($func.Name).Function"
    $funcPath = Join-Path (Join-Path $RootPath $func.Path) $funcName
    
    Write-Host "[$($func.Path)] Creating $funcName..." -ForegroundColor Cyan
    
    # Create function project directory
    if (Test-Path $funcPath) {
        Write-Host "  ⚠ Directory already exists, skipping..." -ForegroundColor Yellow
        continue
    }
    
    New-Item -ItemType Directory -Path $funcPath -Force | Out-Null
    
    # Create subdirectories
    $subdirs = @("Functions", "Services", "Models", "Configuration")
    foreach ($subdir in $subdirs) {
        New-Item -ItemType Directory -Path (Join-Path $funcPath $subdir) -Force | Out-Null
    }
    
    # Create .csproj file
    $csprojContent = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <AzureFunctionsVersion>v4</AzureFunctionsVersion>
    <OutputType>Exe</OutputType>
    <RootNamespace>HealthcareEDI.$($func.Name)</RootNamespace>
    <LangVersion>latest</LangVersion>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.21.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="1.17.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http" Version="3.1.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.ServiceBus" Version="5.16.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Timer" Version="4.3.0" />
    <PackageReference Include="Microsoft.ApplicationInsights.WorkerService" Version="2.22.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.ApplicationInsights" Version="1.2.0" />
    <PackageReference Include="Azure.Storage.Blobs" Version="12.19.1" />
    <PackageReference Include="Azure.Messaging.ServiceBus" Version="7.17.5" />
    <PackageReference Include="Azure.Identity" Version="1.11.3" />
    <PackageReference Include="Microsoft.Extensions.Configuration.AzureKeyVault" Version="3.1.24" />
    <PackageReference Include="Microsoft.Extensions.Logging" Version="8.0.0" />
    <PackageReference Include="System.Text.Json" Version="8.0.3" />
  </ItemGroup>

  <ItemGroup>
    <None Update="host.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </None>
    <None Update="local.settings.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
      <CopyToPublishDirectory>Never</CopyToPublishDirectory>
    </None>
  </ItemGroup>
</Project>
"@
    
    Set-Content -Path (Join-Path $funcPath "$funcName.csproj") -Value $csprojContent
    Write-Host "  ✓ Created $funcName.csproj" -ForegroundColor Green
    
    Write-Host "  ✓ Created project structure for $funcName" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Function Projects Created Successfully!" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review generated projects in: $RootPath" -ForegroundColor Gray
Write-Host "2. Run: dotnet restore" -ForegroundColor Gray
Write-Host "3. Implement function logic (Program.cs, Functions/*)" -ForegroundColor Gray
Write-Host "4. Configure local.settings.json for local testing" -ForegroundColor Gray
Write-Host "5. Run: func start (in each function directory)" -ForegroundColor Gray
Write-Host ""
Write-Host "Created $($functions.Count) function projects across 3 categories" -ForegroundColor Green
Write-Host ""
