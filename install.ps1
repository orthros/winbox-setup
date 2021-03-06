$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\"

Get-ChildItem ".\ahk-scripts" -Filter *.ahk | 
    Foreach-Object {
    $targetPath = [io.path]::combine($startupPath, $_.Name + ".ln")
    New-Item -Path $targetPath -ItemType SymbolicLink -Value $_.FullName -Force 
}
