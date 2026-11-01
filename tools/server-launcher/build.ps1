# Builds ServerLauncher.exe with the C# compiler that ships with Windows (.NET Framework 4),
# then copies it to the Desktop. Run from anywhere:  & 'C:\Claude\Projects\Warband\tools\server-launcher\build.ps1'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$out = Join-Path $here 'ServerLauncher.exe'
& $csc /nologo /target:winexe /platform:x64 /optimize "/out:$out" `
    /reference:System.Windows.Forms.dll /reference:System.Drawing.dll (Join-Path $here 'ServerLauncher.cs')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Copy-Item $out ([Environment]::GetFolderPath('Desktop')) -Force
Write-Output "Built $out and copied it to the Desktop."
