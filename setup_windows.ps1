# libfuzzer-js Setup Script for Windows
# This script sets up the fuzzing environment for JavaScript engine vulnerability research
# Run this script in PowerShell as Administrator

#Requires -RunAsAdministrator

param(
    [switch]$SkipDependencies = $false
)

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "libfuzzer-js Windows Setup Script" -ForegroundColor Cyan
Write-Host "JavaScript Engine Fuzzing for Security Research" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Check Windows version
$osVersion = [System.Environment]::OSVersion.Version
if ($osVersion.Major -lt 10) {
    Write-Host "Error: Windows 10 or later is required" -ForegroundColor Red
    exit 1
}

if (-not $SkipDependencies) {
    Write-Host "Step 1: Checking and installing dependencies..." -ForegroundColor Yellow
    Write-Host ""

    # Check for Chocolatey
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey package manager..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }

    Write-Host "✓ Chocolatey installed" -ForegroundColor Green

    # Install required tools
    $requiredPackages = @(
        "llvm",           # Clang compiler and tools
        "make",           # GNU Make
        "git",            # Git for version control
        "svn",            # Subversion for downloading libFuzzer
        "visualstudio2022-workload-vctools"  # Visual C++ build tools
    )

    foreach ($package in $requiredPackages) {
        Write-Host "Checking for $package..." -ForegroundColor Yellow

        # Special handling for VS workload
        if ($package -eq "visualstudio2022-workload-vctools") {
            if (-not (Test-Path "C:\Program Files\Microsoft Visual Studio\2022")) {
                Write-Host "Installing Visual Studio 2022 Build Tools..." -ForegroundColor Yellow
                choco install visualstudio2022buildtools --package-parameters "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive" -y
            } else {
                Write-Host "✓ Visual Studio Build Tools already installed" -ForegroundColor Green
            }
        } else {
            $installed = choco list --local-only | Select-String -Pattern "^$package "
            if (-not $installed) {
                Write-Host "Installing $package..." -ForegroundColor Yellow
                choco install $package -y
            } else {
                Write-Host "✓ $package already installed" -ForegroundColor Green
            }
        }
    }

    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    Write-Host ""
    Write-Host "✓ All dependencies installed" -ForegroundColor Green
    Write-Host ""
}

# Display clang version
Write-Host "Clang version:" -ForegroundColor Yellow
clang --version | Select-Object -First 1
Write-Host ""

Write-Host "Step 2: Setting up build environment..." -ForegroundColor Yellow

# Create build directory
$BuildDir = "$env:USERPROFILE\fuzzer_build"
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

Set-Location $BuildDir

# Download and build libFuzzer
if (-not (Test-Path "$BuildDir\Fuzzer")) {
    Write-Host "Downloading libFuzzer from LLVM repository..." -ForegroundColor Yellow
    svn co https://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer Fuzzer
} else {
    Write-Host "Updating libFuzzer..." -ForegroundColor Yellow
    Set-Location Fuzzer
    svn update
    Set-Location ..
}

Set-Location Fuzzer

if (-not (Test-Path "libFuzzer.a")) {
    Write-Host "Building libFuzzer..." -ForegroundColor Yellow

    # Build libFuzzer using clang
    $fuzzerFiles = Get-ChildItem -Filter "*.cpp" | Where-Object { $_.Name -notmatch "test|Windows" }

    $objectFiles = @()
    foreach ($file in $fuzzerFiles) {
        $objFile = $file.BaseName + ".o"
        Write-Host "Compiling $($file.Name)..." -ForegroundColor Gray
        clang++ -std=c++17 -c $file.FullName -o $objFile -g -O2 -fno-omit-frame-pointer
        $objectFiles += $objFile
    }

    # Create static library
    Write-Host "Creating libFuzzer.a..." -ForegroundColor Yellow
    llvm-ar rcs libFuzzer.a $objectFiles

    Write-Host "✓ libFuzzer built successfully" -ForegroundColor Green
} else {
    Write-Host "✓ libFuzzer already built" -ForegroundColor Green
}

$env:LIBFUZZER_A_PATH = (Get-Location).Path + "\libFuzzer.a"
Write-Host "✓ libFuzzer location: $env:LIBFUZZER_A_PATH" -ForegroundColor Green
Write-Host ""

# Return to project directory
Set-Location $PSScriptRoot

Write-Host "Step 3: Building libfuzzer-js..." -ForegroundColor Yellow

# Clean previous build
if (Test-Path "jsfuzzer.exe") {
    Remove-Item jsfuzzer.exe -Force
}
if (Test-Path "to_bytecode.exe") {
    Remove-Item to_bytecode.exe -Force
}
if (Test-Path "js.o") {
    Remove-Item js.o -Force
}

# Build QuickJS
Write-Host "Building QuickJS library..." -ForegroundColor Yellow
Set-Location quickjs

# Note: QuickJS Makefile may need adaptation for Windows
# This is a simplified version - you may need to modify QuickJS Makefile for Windows
if (-not (Test-Path "libquickjs.a")) {
    # On Windows, we might need to use nmake or adapt the build
    Write-Host "WARNING: QuickJS build on Windows may require manual configuration" -ForegroundColor Yellow
    Write-Host "Consider using WSL (Windows Subsystem for Linux) for easier building" -ForegroundColor Yellow

    # Try to build with make if available
    if (Get-Command make -ErrorAction SilentlyContinue) {
        make libquickjs.a
    } else {
        Write-Host "ERROR: GNU Make not found. Please install make or use WSL" -ForegroundColor Red
        exit 1
    }
}

Set-Location ..

# Build js.o
Write-Host "Compiling js.cpp..." -ForegroundColor Yellow
clang++ -std=c++17 -g -I quickjs/ -fsanitize=fuzzer-no-link js.cpp -c -o js.o

# Build jsfuzzer
Write-Host "Linking jsfuzzer..." -ForegroundColor Yellow
clang++ -std=c++17 harness.cpp js.o quickjs/libquickjs.a $env:LIBFUZZER_A_PATH -o jsfuzzer.exe

# Build to_bytecode
Write-Host "Building to_bytecode utility..." -ForegroundColor Yellow
clang++ -std=c++17 -fsanitize=fuzzer-no-link to_bytecode.cpp js.o quickjs/libquickjs.a -o to_bytecode.exe

Write-Host ""
Write-Host "✓ Build complete!" -ForegroundColor Green
Write-Host ""

Write-Host "Step 4: Creating example fuzzing target..." -ForegroundColor Yellow

# Create example JavaScript file
@'
// Example fuzzing target for JavaScript engine
// This code will be executed with FuzzerInput as random data

function processInput(input) {
    try {
        // Test various JavaScript features

        // 1. String operations
        let str = String.fromCharCode.apply(null, input);

        // 2. Array operations
        let arr = Array.from(input);
        arr.sort();
        arr.reverse();

        // 3. Object operations
        let obj = {};
        for (let i = 0; i < Math.min(input.length, 100); i++) {
            obj['key' + i] = input[i];
        }

        // 4. Regular expressions (common vulnerability source)
        if (str.length > 0 && str.length < 1000) {
            try {
                let pattern = str.slice(0, 20);
                let re = new RegExp(pattern);
                re.test("test string");
            } catch(e) {}
        }

        // 5. JSON parsing (common vulnerability source)
        if (input.length > 2 && input.length < 10000) {
            try {
                JSON.parse(str);
            } catch(e) {}
        }

        // 6. Arithmetic operations
        let sum = 0;
        for (let i = 0; i < Math.min(input.length, 1000); i++) {
            sum += input[i];
        }

        // 7. Type conversions
        let num = Number(str);
        let bool = Boolean(sum);

        return sum;

    } catch(e) {
        // Catch exceptions to continue fuzzing
        return -1;
    }
}

// Main fuzzer entry point
if (typeof FuzzerInput !== 'undefined') {
    processInput(FuzzerInput);
}
'@ | Out-File -FilePath "example_fuzz.js" -Encoding UTF8

Write-Host "✓ Created example_fuzz.js" -ForegroundColor Green
Write-Host ""

Write-Host "==================================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "To run the fuzzer:" -ForegroundColor Yellow
Write-Host ".\jsfuzzer.exe --js=example_fuzz.js" -ForegroundColor Cyan
Write-Host ""
Write-Host "To create your own fuzzing targets:" -ForegroundColor Yellow
Write-Host "1. Create a .js file that uses the FuzzerInput variable"
Write-Host "2. Run: .\jsfuzzer.exe --js=your_target.js"
Write-Host ""
Write-Host "The fuzzer will:"
Write-Host "- Generate random inputs"
Write-Host "- Execute your JavaScript with each input"
Write-Host "- Detect crashes, hangs, and memory errors"
Write-Host "- Save crash-inducing inputs to disk"
Write-Host ""
Write-Host "For responsible vulnerability disclosure, see:"
Write-Host "- Apple: https://support.apple.com/en-us/HT201220"
Write-Host "- Microsoft: https://www.microsoft.com/en-us/msrc/bounty"
Write-Host "- Google: https://bughunters.google.com/"
Write-Host ""
Write-Host "ALTERNATIVE: Consider using WSL for easier Linux-based fuzzing" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT: Only use this for authorized security research!" -ForegroundColor Red
Write-Host "==================================================" -ForegroundColor Cyan
