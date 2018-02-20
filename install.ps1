$linkPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\"

Get-ChildItem ".\ahk-scripts" -Filter *.ahk | 
    Foreach-Object {
    $targetPath = [io.path]::combine($linkPath, $_.Name + ".ln")    
    New-Item -Path $targetPath -ItemType SymbolicLink -Value $_.FullName -Force 
}

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
