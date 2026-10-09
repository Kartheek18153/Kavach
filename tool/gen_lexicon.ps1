# Generates tactic_lexicon_data.dart from data/tactic_lexicon.json.
# Source lexicon: KAVACH_IQOO by Atul Chahar & Anant Sharma (Apache-2.0).
# Run from repo root: pwsh -File tool/gen_lexicon.ps1
# Re-run after any lexicon update; never edit the generated files by hand.
$ErrorActionPreference = 'Stop'

function Escape-DartString([string]$s) {
  $s = $s -replace '\\', '\\'
  $s = $s -replace "'", "\'"
  $s = $s -replace '\$', '$$'
  $s = $s -replace "`r", ''
  $s = $s -replace "`n", '\n'
  return $s
}

$root = Split-Path -Parent $PSScriptRoot
$json = Get-Content -LiteralPath (Join-Path $root 'data\tactic_lexicon.json') -Raw -Encoding UTF8 |
  ConvertFrom-Json

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("// GENERATED from data/tactic_lexicon.json - DO NOT EDIT.")
[void]$sb.AppendLine("// Lexicon: KAVACH_IQOO (Atul Chahar & Anant Sharma), Apache-2.0.")
[void]$sb.AppendLine("// Regenerate: pwsh -File tool/gen_lexicon.ps1")
[void]$sb.AppendLine()
[void]$sb.AppendLine("/// One tactic family: id, English label, per-family score cap, markers.")
[void]$sb.AppendLine("typedef TacticFamilyData = ({")
[void]$sb.AppendLine("  String id,")
[void]$sb.AppendLine("  String displayEn,")
[void]$sb.AppendLine("  int cap,")
[void]$sb.AppendLine("  List<({String t, int w})> markers,")
[void]$sb.AppendLine("});")
[void]$sb.AppendLine()
[void]$sb.AppendLine("const List<TacticFamilyData> tacticFamilies = [")

foreach ($f in $json.families) {
  $cap = $f.baseWeight
  if ($cap -gt 30) { $cap = 30 }
  [void]$sb.AppendLine("  (")
  [void]$sb.AppendLine("    id: '$($f.id)',")
  [void]$sb.AppendLine("    displayEn: '$(Escape-DartString $f.displayEn)',")
  [void]$sb.AppendLine("    cap: $cap,")
  [void]$sb.AppendLine("    markers: [")
  foreach ($m in $f.markers) {
    [void]$sb.AppendLine("      (t: '$(Escape-DartString $m.t)', w: $($m.w)),")
  }
  [void]$sb.AppendLine("    ],")
  [void]$sb.AppendLine("  ),")
}
[void]$sb.AppendLine("];")
[void]$sb.AppendLine()
[void]$sb.AppendLine("/// Negative guards: legitimate phrases that subtract score.")
[void]$sb.AppendLine("const List<({String t, int w})> negativeGuards = [")
foreach ($m in $json.negativeGuards.markers) {
  [void]$sb.AppendLine("  (t: '$(Escape-DartString $m.t)', w: $($m.w)),")
}
[void]$sb.AppendLine("];")

$code = $sb.ToString()
$appOut = Join-Path $root 'lib\services\tactic_lexicon_data.dart'
$beOut = Join-Path $root 'backend\lib\tactic_lexicon_data.dart'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($appOut, $code, $utf8)
[System.IO.File]::WriteAllText($beOut, $code, $utf8)

$n = ($json.families | ForEach-Object { $_.markers.Count } | Measure-Object -Sum).Sum
$g = $json.negativeGuards.markers.Count
Write-Output "families=$($json.families.Count) markers=$n guards=$g version=$($json.version)"
