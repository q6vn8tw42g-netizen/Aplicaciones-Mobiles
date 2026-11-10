$linea = .\supabase.exe status -o env | Where-Object { $_ -like 'ANON_KEY=*' } | Select-Object -First 1
if (-not $linea) { Write-Host "No encontre ANON_KEY"; exit 1 }
$k = ($linea -replace '^ANON_KEY="', '') -replace '"\s*$', ''
if (-not $k.StartsWith('eyJ')) { Write-Host "La llave no empieza con eyJ"; exit 1 }
foreach ($f in @('.env', 'api\.env')) {
    $t = [IO.File]::ReadAllText($f)
    $t = [regex]::Replace($t, '(?m)^SUPABASE_PUBLISHABLE_KEY=.*\r?\n?', '')
    if ($t.Length -gt 0 -and -not $t.EndsWith("`n")) { $t += "`r`n" }
    $t += "SUPABASE_PUBLISHABLE_KEY=$k`r`n"
    [IO.File]::WriteAllText($f, $t, (New-Object Text.UTF8Encoding($false)))
    Write-Host "OK: $f"
}
