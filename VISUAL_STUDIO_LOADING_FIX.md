# Visual Studio Loading Issue - Troubleshooting Guide

## Problem
SimpleSmartMail.API won't load into Visual Studio 2022

## Quick Fixes (Try in Order)

### Fix 1: Clean and Rebuild Solution
1. Close Visual Studio
2. Delete the following folders if they exist:
   - `SimpleSmartMail/bin`
   - `SimpleSmartMail/obj`
   - `SimpleSmartMail/.vs` (hidden folder)
   - `SimpleSmartMail/src/SimpleSmartMail.API/bin`
   - `SimpleSmartMail/src/SimpleSmartMail.API/obj`
   - `SimpleSmartMail/src/SimpleSmartMail.Business/bin`
   - `SimpleSmartMail/src/SimpleSmartMail.Business/obj`
   - `SimpleSmartMail/src/SimpleSmartMail.Data/bin`
   - `SimpleSmartMail/src/SimpleSmartMail.Data/obj`
   - `SimpleSmartMail/src/SimpleSmartMail.Models/bin`
   - `SimpleSmartMail/src/SimpleSmartMail.Models/obj`
3. Open Visual Studio 2022
4. Open `SimpleSmartMail.sln`
5. Right-click Solution → Restore NuGet Packages
6. Build → Rebuild Solution

### Fix 2: Restore NuGet Packages from Command Line
Open PowerShell or Command Prompt in the `SimpleSmartMail` directory:

```powershell
dotnet restore SimpleSmartMail.sln
dotnet build SimpleSmartMail.sln
```

If successful, try opening in Visual Studio again.

### Fix 3: Check .NET 6.0 SDK Installation
1. Open PowerShell or Command Prompt
2. Run: `dotnet --list-sdks`
3. Verify .NET 6.0 SDK is installed (e.g., `6.0.xxx`)
4. If not installed, download from: https://dotnet.microsoft.com/download/dotnet/6.0
5. Install .NET 6.0 SDK
6. Restart Visual Studio

### Fix 4: Reset Visual Studio Component Cache
1. Close Visual Studio
2. Delete: `%LOCALAPPDATA%\Microsoft\VisualStudio\17.0_*\ComponentModelCache`
3. Delete: `%LOCALAPPDATA%\Microsoft\VisualStudio\17.0_*\PrivateAssemblies`
4. Restart Visual Studio

### Fix 5: Check Project File Encoding
The project file should be UTF-8 or ASCII. If you have Notepad++:
1. Open `SimpleSmartMail.API.csproj` in Notepad++
2. Encoding menu → Convert to UTF-8
3. Save
4. Try loading in Visual Studio

### Fix 6: Manual Project Reload
1. Open Visual Studio 2022
2. File → Open → Project/Solution
3. Navigate to `SimpleSmartMail.sln`
4. If you see "Project failed to load" for SimpleSmartMail.API:
   - Right-click on the project (grayed out)
   - Select "Reload Project"
5. Check Output window for specific error messages

### Fix 7: Verify Package Versions
Some package versions might be incompatible. Here are the known working versions:

**SimpleSmartMail.API.csproj:**
- Swashbuckle.AspNetCore: 6.5.0
- Microsoft.AspNetCore.Authentication.JwtBearer: 6.0.25

**SimpleSmartMail.Business.csproj:**
- SendGrid: 9.28.1
- System.IdentityModel.Tokens.Jwt: 6.35.0
- Microsoft.IdentityModel.Tokens: 6.35.0
- Microsoft.Extensions.Configuration.Abstractions: 6.0.0
- Microsoft.Extensions.Logging.Abstractions: 6.0.0

### Fix 8: Check Error List Window
1. In Visual Studio, open View → Error List
2. Look for specific error messages
3. Common errors and fixes:
   - **"The SDK 'Microsoft.NET.Sdk.Web' not found"** → Install .NET 6.0 SDK
   - **"Package restore failed"** → Run `dotnet restore` in terminal
   - **"Project reference could not be resolved"** → Check project paths in .sln file

### Fix 9: Create New API Project and Copy Files
If nothing works, create a fresh API project:

1. In Visual Studio → New Project → ASP.NET Core Web API
2. Name: SimpleSmartMail.API
3. Framework: .NET 6.0
4. Delete the default files
5. Copy all files from the broken project
6. Add project references manually:
   - Right-click Dependencies → Add Project Reference
   - Select SimpleSmartMail.Business and SimpleSmartMail.Models
7. Add NuGet packages manually

### Fix 10: Check Visual Studio Version
Ensure you're using Visual Studio 2022 (17.0 or later):
1. Help → About Microsoft Visual Studio
2. Should show Version 17.x.x
3. If using older version (VS 2019), you may need to:
   - Upgrade to VS 2022, OR
   - Change `VisualStudioVersion = 17.0.31903.59` to `16.0` in .sln file

---

## Getting Specific Error Messages

### From Visual Studio:
1. View → Output
2. Show output from: Build
3. Copy error messages

### From Command Line:
```powershell
cd SimpleSmartMail
dotnet build -v detailed > build-log.txt 2>&1
notepad build-log.txt
```

### From Visual Studio Developer Command Prompt:
```cmd
msbuild SimpleSmartMail.sln /v:detailed > build-log.txt 2>&1
notepad build-log.txt
```

---

## Common Issues and Solutions

### Issue: "Could not load file or assembly"
**Solution:**
```powershell
dotnet nuget locals all --clear
dotnet restore
```

### Issue: "Project targeting 'net6.0' cannot run on .NET Framework runtime"
**Solution:** Ensure .NET 6.0 SDK is installed, not just runtime

### Issue: "The project file could not be loaded"
**Solution:** Check for:
- Invalid XML characters
- Incorrect file encoding
- Missing closing tags
- Corrupted file (compare with GitHub)

### Issue: "Assets file project.assets.json not found"
**Solution:**
```powershell
dotnet restore src/SimpleSmartMail.API/SimpleSmartMail.API.csproj
```

---

## Last Resort: Fresh Clone
If all else fails:

1. Commit your changes to a different branch
2. Clone the repository fresh:
   ```bash
   git clone https://github.com/eleg8r/SimpleSmartMail.git SimpleSmartMail-fresh
   cd SimpleSmartMail-fresh
   git checkout claude/create-simplesmartmail-project-011TNQM9xEG2T5iaDFgawvur
   dotnet restore
   dotnet build
   ```
3. Open in Visual Studio

---

## What to Share for Further Help

If none of these work, please provide:

1. **Exact error message** from Error List or Output window
2. **Visual Studio version**: Help → About
3. **.NET SDK version**: Run `dotnet --version` in PowerShell
4. **Build output**:
   ```powershell
   dotnet build SimpleSmartMail.sln > build-output.txt 2>&1
   ```
5. **Screenshot** of the error in Visual Studio

---

## Project File Validation

Your project files should match these exactly:

### SimpleSmartMail.API.csproj
```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net6.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.5.0" />
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="6.0.25" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\SimpleSmartMail.Models\SimpleSmartMail.Models.csproj" />
    <ProjectReference Include="..\SimpleSmartMail.Business\SimpleSmartMail.Business.csproj" />
  </ItemGroup>

</Project>
```

If your file is different, copy the above content and paste it into SimpleSmartMail.API.csproj.

---

## Prevention

To avoid this in the future:

1. Always commit before making major changes
2. Run `dotnet build` after pulling changes
3. Keep Visual Studio updated
4. Clear bin/obj folders regularly
5. Don't manually edit .sln files
