# Export every almanac table from the Access database to UTF-8 CSV, one file per
# table, in build/almanacs/mdb_export/. R has no Access driver on this machine, so
# the export uses Windows' ACE OLEDB provider. It reads a temporary copy of
# sources/raw/almanacs/Almanacs.mdb in read-only mode and never runs saved queries.
# Run from the project root: powershell -ExecutionPolicy Bypass -File pipeline/almanacs/00_export_mdb.ps1
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath 'sources/raw/almanacs/Almanacs.mdb').Path
$outDir = 'build/almanacs/mdb_export'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Get-ChildItem -LiteralPath $outDir -Filter '*.csv' | Remove-Item -Force
$copy = Join-Path ([System.IO.Path]::GetTempPath()) ('chdr_almanacs_' + [guid]::NewGuid().ToString('N') + '.mdb')
Copy-Item -LiteralPath $source -Destination $copy
$utf8 = New-Object System.Text.UTF8Encoding($false)
$conn = New-Object System.Data.OleDb.OleDbConnection('Provider=Microsoft.ACE.OLEDB.12.0;Data Source=' + $copy + ';Mode=Read;')
try {
    $conn.Open()
    $tables = $conn.GetSchema('Tables') | Where-Object { $_.TABLE_TYPE -eq 'TABLE' } | ForEach-Object { [string]$_.TABLE_NAME } | Sort-Object
    foreach ($t in $tables) {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = 'SELECT * FROM [' + $t.Replace(']', ']]') + ']'
        $r = $cmd.ExecuteReader()
        $w = New-Object System.IO.StreamWriter((Join-Path $outDir ($t + '.csv')), $false, $utf8)
        $q = { param($s) if ($null -eq $s) { '' } else { '"' + ([string]$s).Replace('"', '""') + '"' } }
        $names = @('source_row') + (0..($r.FieldCount - 1) | ForEach-Object { $r.GetName($_) })
        $w.WriteLine((($names | ForEach-Object { & $q $_ }) -join ','))
        $n = 0
        while ($r.Read()) {
            $n++
            $vals = @([string]$n) + (0..($r.FieldCount - 1) | ForEach-Object { $v = $r.GetValue($_); if ($v -is [DBNull]) { $null } else { [string]$v } })
            $w.WriteLine((($vals | ForEach-Object { & $q $_ }) -join ','))
        }
        $w.Close(); $r.Close(); $cmd.Dispose()
        Write-Output ($t + ': ' + $n + ' rows')
    }
} finally {
    $conn.Close(); $conn.Dispose()
    Remove-Item -LiteralPath $copy -Force
}
