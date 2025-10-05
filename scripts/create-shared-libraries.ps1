# Create Shared Library Projects for EDI Healthcare Platform# Create Shared Library Projects for EDI Healthcare Platform

# This script creates 6 shared class library projects that will be packaged as NuGet packages# This script creates 6 shared class library projects that will be packaged as NuGet packages



$ErrorActionPreference = "Stop"$ErrorActionPreference = "Stop"



# Define root path# Define root path

$RootPath = Join-Path $PSScriptRoot ".." "src" "shared"$RootPath = Join-Path $PSScriptRoot ".." "src" "shared"



# Ensure root directory exists# Ensure root directory exists

New-Item -ItemType Directory -Force -Path $RootPath | Out-NullNew-Item -ItemType Directory -Force -Path $RootPath | Out-Null



Write-Host "Creating shared library projects in: $RootPath" -ForegroundColor CyanWrite-Host "Creating shared library projects in: $RootPath" -ForegroundColor Cyan



# Define libraries with their dependencies# Define libraries with their dependencies

$libraries = @($libraries = @(

    @{    @{

        Name = "HealthcareEDI.Core"        Name = "HealthcareEDI.Core"

        Description = "Core abstractions, interfaces, and common models"        Description = "Core abstractions, interfaces, and common models"

        Dependencies = @()        Dependencies = @()

        Folders = @("Interfaces", "Models", "Exceptions", "Constants", "Extensions")        Folders = @("Interfaces", "Models", "Exceptions", "Constants", "Extensions")

    },    },

    @{    @{

        Name = "HealthcareEDI.X12"        Name = "HealthcareEDI.X12"

        Description = "X12 EDI parsing, validation, and generation"        Description = "X12 EDI parsing, validation, and generation"

        Dependencies = @("HealthcareEDI.Core")        Dependencies = @("HealthcareEDI.Core")

        Folders = @("Parser", "Models", "Validators", "Generators", "Specifications")        Folders = @("Parser", "Models", "Validators", "Generators", "Specifications")

    },    },

    @{    @{

        Name = "HealthcareEDI.Configuration"        Name = "HealthcareEDI.Configuration"

        Description = "Configuration management and partner metadata"        Description = "Configuration management and partner metadata"

        Dependencies = @("HealthcareEDI.Core")        Dependencies = @("HealthcareEDI.Core")

        Folders = @("Interfaces", "Models", "Services", "Validation")        Folders = @("Interfaces", "Models", "Services", "Validation")

    },    },

    @{    @{

        Name = "HealthcareEDI.Storage"        Name = "HealthcareEDI.Storage"

        Description = "Storage abstractions for Blob, Queue, and Table storage"        Description = "Storage abstractions for Blob, Queue, and Table storage"

        Dependencies = @("HealthcareEDI.Core")        Dependencies = @("HealthcareEDI.Core")

        Folders = @("Interfaces", "Services", "Models")        Folders = @("Interfaces", "Services", "Models")

    },    },

    @{    @{

        Name = "HealthcareEDI.Messaging"        Name = "HealthcareEDI.Messaging"

        Description = "Service Bus abstractions for publishing and consuming messages"        Description = "Service Bus abstractions for publishing and consuming messages"

        Dependencies = @("HealthcareEDI.Core")        Dependencies = @("HealthcareEDI.Core")

        Folders = @("Interfaces", "Services", "Models")        Folders = @("Interfaces", "Services", "Models")

    },    },

    @{    @{

        Name = "HealthcareEDI.Logging"        Name = "HealthcareEDI.Logging"

        Description = "Structured logging with Application Insights integration"        Description = "Structured logging with Application Insights integration"

        Dependencies = @("HealthcareEDI.Core")        Dependencies = @("HealthcareEDI.Core")

        Folders = @("Extensions", "Models", "Middleware")        Folders = @("Extensions", "Models", "Middleware")

    }    }

))



# Function to create .csproj content# Function to create .csproj content

function Get-CsprojContent {function Get-CsprojContent {

    param (    param (

        [string]$ProjectName,        [string]$ProjectName,

        [string]$Description,        [string]$Description,

        [string[]]$Dependencies        [string[]]$Dependencies

    )    )



    $packages = ""    $csprojContent = @"

    <Project Sdk="Microsoft.NET.Sdk">

    # Add project-specific NuGet packages

    switch ($ProjectName) {  <PropertyGroup>

        "HealthcareEDI.Core" {    <TargetFramework>net9.0</TargetFramework>

            $packages = "    <!-- No external dependencies for Core library -->"    <ImplicitUsings>enable</ImplicitUsings>

        }    <Nullable>enable</Nullable>

        "HealthcareEDI.X12" {    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>

            $packages = "    <PackageReference Include=`"System.Text.Json`" Version=`"9.0.0`" />"    

        }    <!-- NuGet Package Metadata -->

        "HealthcareEDI.Configuration" {    <GeneratePackageOnBuild>true</GeneratePackageOnBuild>

            $packages = @"    <PackageId>$ProjectName</PackageId>

    <PackageReference Include="Azure.Storage.Blobs" Version="12.22.2" />    <Version>1.0.0</Version>

    <PackageReference Include="Microsoft.Extensions.Caching.Memory" Version="9.0.0" />    <Authors>PointCHealth EDI Platform Team</Authors>

    <PackageReference Include="Microsoft.Extensions.Options" Version="9.0.0" />    <Company>PointCHealth</Company>

"@    <Product>Healthcare EDI Platform</Product>

        }    <Description>$Description</Description>

        "HealthcareEDI.Storage" {    <PackageLicenseExpression>Proprietary</PackageLicenseExpression>

            $packages = @"    <PackageProjectUrl>https://github.com/PointCHealth/ai-adf-edi-spec</PackageProjectUrl>

    <PackageReference Include="Azure.Storage.Blobs" Version="12.22.2" />    <RepositoryUrl>https://github.com/PointCHealth/ai-adf-edi-spec</RepositoryUrl>

    <PackageReference Include="Azure.Storage.Queues" Version="12.20.1" />    <RepositoryType>git</RepositoryType>

    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="9.0.0" />    <PackageTags>edi;healthcare;x12;hipaa</PackageTags>

"@    

        }    <!-- Documentation -->

        "HealthcareEDI.Messaging" {    <GenerateDocumentationFile>true</GenerateDocumentationFile>

            $packages = @"    <DocumentationFile>bin\`$(Configuration)\`$(TargetFramework)\$ProjectName.xml</DocumentationFile>

    <PackageReference Include="Azure.Messaging.ServiceBus" Version="7.18.2" />    

    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="9.0.0" />    <!-- Symbols -->

"@    <IncludeSymbols>true</IncludeSymbols>

        }    <SymbolPackageFormat>snupkg</SymbolPackageFormat>

        "HealthcareEDI.Logging" {  </PropertyGroup>

            $packages = @"

    <PackageReference Include="Microsoft.ApplicationInsights" Version="2.22.0" />  <ItemGroup>

    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="9.0.0" />"@

"@

        }    # Add project-specific NuGet packages

    }    switch ($ProjectName) {

        "HealthcareEDI.Core" {

    $projectRefs = ""            $csprojContent += @"

    if ($Dependencies.Count -gt 0) {

        $refs = foreach ($dep in $Dependencies) {    <!-- No external dependencies for Core library -->

            "    <ProjectReference Include=`"..\$dep\$dep.csproj`" />""@

        }        }

        $projectRefs = @"        "HealthcareEDI.X12" {

            $csprojContent += @"

  <ItemGroup>

$($refs -join "`n")    <PackageReference Include="System.Text.Json" Version="9.0.0" />

  </ItemGroup>"@

"@        }

    }        "HealthcareEDI.Configuration" {

            $csprojContent += @"

    $content = @"

<Project Sdk="Microsoft.NET.Sdk">    <PackageReference Include="Azure.Storage.Blobs" Version="12.22.2" />

    <PackageReference Include="Microsoft.Extensions.Caching.Memory" Version="9.0.0" />

  <PropertyGroup>    <PackageReference Include="Microsoft.Extensions.Options" Version="9.0.0" />

    <TargetFramework>net9.0</TargetFramework>"@

    <ImplicitUsings>enable</ImplicitUsings>        }

    <Nullable>enable</Nullable>        "HealthcareEDI.Storage" {

    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>            $csprojContent += @"

    

    <!-- NuGet Package Metadata -->    <PackageReference Include="Azure.Storage.Blobs" Version="12.22.2" />

    <GeneratePackageOnBuild>true</GeneratePackageOnBuild>    <PackageReference Include="Azure.Storage.Queues" Version="12.20.1" />

    <PackageId>$ProjectName</PackageId>    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="9.0.0" />

    <Version>1.0.0</Version>"@

    <Authors>PointCHealth EDI Platform Team</Authors>        }

    <Company>PointCHealth</Company>        "HealthcareEDI.Messaging" {

    <Product>Healthcare EDI Platform</Product>            $csprojContent += @"

    <Description>$Description</Description>

    <PackageLicenseExpression>Proprietary</PackageLicenseExpression>    <PackageReference Include="Azure.Messaging.ServiceBus" Version="7.18.2" />

    <PackageProjectUrl>https://github.com/PointCHealth/ai-adf-edi-spec</PackageProjectUrl>    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="9.0.0" />

    <RepositoryUrl>https://github.com/PointCHealth/ai-adf-edi-spec</RepositoryUrl>"@

    <RepositoryType>git</RepositoryType>        }

    <PackageTags>edi;healthcare;x12;hipaa</PackageTags>        "HealthcareEDI.Logging" {

                $csprojContent += @"

    <!-- Documentation -->

    <GenerateDocumentationFile>true</GenerateDocumentationFile>    <PackageReference Include="Microsoft.ApplicationInsights" Version="2.22.0" />

    <DocumentationFile>bin\`$(Configuration)\`$(TargetFramework)\$ProjectName.xml</DocumentationFile>    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="9.0.0" />

    "@

    <!-- Symbols -->        }

    <IncludeSymbols>true</IncludeSymbols>    }

    <SymbolPackageFormat>snupkg</SymbolPackageFormat>

  </PropertyGroup>    $csprojContent += @"



  <ItemGroup>  </ItemGroup>

$packages

  </ItemGroup>"@

$projectRefs

    # Add project references

</Project>    if ($Dependencies.Count -gt 0) {

"@        $csprojContent += @"

  <ItemGroup>

    return $content

}"@

        foreach ($dep in $Dependencies) {

# Create each library project            $csprojContent += "    <ProjectReference Include=`"..\$dep\$dep.csproj`" />`n"

foreach ($lib in $libraries) {        }

    $projectPath = Join-Path $RootPath $lib.Name        $csprojContent += @"

    $csprojPath = Join-Path $projectPath "$($lib.Name).csproj"  </ItemGroup>

    

    Write-Host "Creating $($lib.Name)..." -ForegroundColor Green"@

        }

    # Create project directory

    New-Item -ItemType Directory -Force -Path $projectPath | Out-Null    $csprojContent += @"

    </Project>

    # Create folder structure"@

    foreach ($folder in $lib.Folders) {

        $folderPath = Join-Path $projectPath $folder    return $csprojContent

        New-Item -ItemType Directory -Force -Path $folderPath | Out-Null}

    }

    # Create each library project

    # Create .csproj fileforeach ($lib in $libraries) {

    $csprojContent = Get-CsprojContent -ProjectName $lib.Name -Description $lib.Description -Dependencies $lib.Dependencies    $projectPath = Join-Path $RootPath $lib.Name

    Set-Content -Path $csprojPath -Value $csprojContent -Encoding UTF8    $csprojPath = Join-Path $projectPath "$($lib.Name).csproj"

        

    # Create .gitkeep files to preserve empty directories    Write-Host "Creating $($lib.Name)..." -ForegroundColor Green

    foreach ($folder in $lib.Folders) {    

        $gitkeepPath = Join-Path $projectPath $folder ".gitkeep"    # Create project directory

        New-Item -ItemType File -Force -Path $gitkeepPath | Out-Null    New-Item -ItemType Directory -Force -Path $projectPath | Out-Null

    }    

        # Create folder structure

    Write-Host "  Created $($lib.Name)" -ForegroundColor Gray    foreach ($folder in $lib.Folders) {

}        $folderPath = Join-Path $projectPath $folder

        New-Item -ItemType Directory -Force -Path $folderPath | Out-Null

Write-Host ""    }

Write-Host "Created $($libraries.Count) shared library projects" -ForegroundColor Green    

Write-Host ""    # Create .csproj file

Write-Host "Next steps:" -ForegroundColor Yellow    $csprojContent = Get-CsprojContent -ProjectName $lib.Name -Description $lib.Description -Dependencies $lib.Dependencies

Write-Host "1. Build libraries: cd src\shared; dotnet build" -ForegroundColor Gray    Set-Content -Path $csprojPath -Value $csprojContent -Encoding UTF8

Write-Host "2. Run tests: dotnet test" -ForegroundColor Gray    

Write-Host "3. Pack for NuGet: dotnet pack --configuration Release" -ForegroundColor Gray    # Create .gitkeep files to preserve empty directories

    foreach ($folder in $lib.Folders) {
        $gitkeepPath = Join-Path $projectPath $folder ".gitkeep"
        New-Item -ItemType File -Force -Path $gitkeepPath | Out-Null
    }
    
    Write-Host "  ✓ Created $($lib.Name)" -ForegroundColor Gray
}

Write-Host "`n✅ Created $($libraries.Count) shared library projects" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Build libraries: cd src\shared; dotnet build" -ForegroundColor Gray
Write-Host "2. Run tests: dotnet test" -ForegroundColor Gray
Write-Host "3. Pack for NuGet: dotnet pack --configuration Release" -ForegroundColor Gray
