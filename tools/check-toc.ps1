# PowerShell 5.1. Exit 0 when every file the TOC lists (outside Libs\) exists
# and every addon .lua file is listed exactly once.
$root = Split-Path -Parent $PSScriptRoot
$toc = Join-Path $root 'WhoWearsIt.toc'
$problems = 0

$listed = Get-Content -LiteralPath $toc -Encoding UTF8 |
  Where-Object { $_.Trim() -ne '' -and -not $_.StartsWith('#') } |
  ForEach-Object { $_.Trim() }

foreach ($f in $listed) {
  if ($f.StartsWith('Libs\')) { continue }
  if (-not (Test-Path -LiteralPath (Join-Path $root $f))) {
    Write-Output "Missing file listed in TOC: $f"
    $problems++
  }
}

$skip = @('Libs', 'tools', 'tests', 'docs', '.github')
$luaFiles = Get-ChildItem -LiteralPath $root -Recurse -Filter *.lua | Where-Object {
  $rel = $_.FullName.Substring($root.Length + 1)
  $top = $rel.Split('\')[0]
  -not ($skip -contains $top)
}
foreach ($file in $luaFiles) {
  $rel = $file.FullName.Substring($root.Length + 1)
  $count = @($listed | Where-Object { $_ -eq $rel }).Count
  if ($count -ne 1) {
    Write-Output "$rel is listed $count times in the TOC"
    $problems++
  }
}

if ($problems -eq 0) { Write-Output "TOC OK: $($listed.Count) entries, $($luaFiles.Count) Lua files" ; exit 0 }
Write-Output "$problems problem(s)"
exit 1
