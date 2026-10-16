# WrestlingHub Italia - sincronizzazione notizie e calendario.
# Legge i feed RSS in data/sources.json, unisce le notizie in data/news.json
# e rigenera i file data/*.js usati dalle pagine. Compatibile con
# Windows PowerShell 5.1 e PowerShell 7 (anche su Linux, per l'automazione).

param(
  [int]$MaxItems = 400,   # notizie massime conservate
  [int]$MaxDays  = 10     # notizie piu' vecchie di N giorni vengono scartate
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dataDir = Join-Path $root 'data'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$inv = [Globalization.CultureInfo]::InvariantCulture
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

function Read-Json($path) {
  if (-not (Test-Path $path)) { return $null }
  return [IO.File]::ReadAllText($path, $utf8) | ConvertFrom-Json
}

function Write-Text($path, $text) { [IO.File]::WriteAllText($path, $text, $utf8) }

function Get-Child($node, [string]$localName) {
  foreach ($c in $node.ChildNodes) { if ($c.LocalName -eq $localName) { return $c } }
  return $null
}

function Get-Children($node, [string]$localName) {
  $list = @()
  foreach ($c in $node.ChildNodes) { if ($c.LocalName -eq $localName) { $list += $c } }
  return $list
}

function Clean-Text([string]$html) {
  if (-not $html) { return '' }
  $t = $html -replace '(?s)<script.*?</script>', ' ' -replace '(?s)<style.*?</style>', ' ' -replace '<[^>]+>', ' '
  $t = [System.Net.WebUtility]::HtmlDecode($t)
  $t = $t -replace '\s+', ' '
  # rimuove le code tipiche dei feed WordPress ("L'articolo ... proviene da ...", "The post ... appeared first on ...")
  $t = $t -replace "\s*(L'articolo|The post) .*$", ''
  return $t.Trim()
}

function Shorten([string]$t, [int]$n) {
  if ($t.Length -le $n) { return $t }
  $cut = $t.Substring(0, $n)
  $sp = $cut.LastIndexOf(' ')
  if ($sp -gt $n * 0.6) { $cut = $cut.Substring(0, $sp) }
  return $cut.TrimEnd(',', ';', ':', '.', ' ') + '...'
}

function Parse-Date([string]$s) {
  if (-not $s) { return $null }
  $s = $s.Trim() -replace '\s(GMT|UTC|UT|Z)$', ' +00:00' -replace '\s([+-]\d{2})(\d{2})$', ' $1:$2'
  $d = [DateTimeOffset]::MinValue
  if ([DateTimeOffset]::TryParse($s, $inv, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$d)) { return $d.ToUniversalTime() }
  # rimuove il giorno della settimana se non coerente con la data
  $s2 = $s -replace '^[A-Za-z]{3},\s*', ''
  if ([DateTimeOffset]::TryParse($s2, $inv, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$d)) { return $d.ToUniversalTime() }
  return $null
}

function Find-Image($item, [string]$html) {
  foreach ($n in @('content', 'thumbnail')) {
    foreach ($m in (Get-Children $item $n)) {
      if ($m.NamespaceURI -like '*search.yahoo.com/mrss*' -and $m.GetAttribute('url')) { return $m.GetAttribute('url') }
    }
  }
  $group = Get-Child $item 'group'
  if ($group) {
    $m = Get-Child $group 'content'
    if ($m -and $m.GetAttribute('url')) { return $m.GetAttribute('url') }
  }
  $enc = Get-Child $item 'enclosure'
  if ($enc -and $enc.GetAttribute('type') -like 'image*') { return $enc.GetAttribute('url') }
  if ($html -match '<img[^>]+src=["'']([^"'']+)["'']') { return $Matches[1] }
  return ''
}

# Immagine di anteprima dalla pagina dell'articolo (og:image / twitter:image), usata quando il feed non ne ha
function Get-PageImage([string]$url) {
  try {
    $html = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 12 -UserAgent 'Mozilla/5.0 (compatible; WrestlingHubItalia/1.0; +https://wrestlinghubitalia.com)').Content
  } catch { return '' }
  foreach ($p in @(
    '<meta[^>]+(?:property|name)=["''](?:og:image|og:image:url|twitter:image)["''][^>]+content=["'']([^"'']+)',
    '<meta[^>]+content=["'']([^"'']+)["''][^>]+(?:property|name)=["''](?:og:image|og:image:url|twitter:image)["'']')) {
    $m = [regex]::Match($html, $p, 'IgnoreCase')
    if ($m.Success -and $m.Groups[1].Value -match '^https?://') { return [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value) }
  }
  return ''
}

# Federazioni riconosciute nel titolo/estratto (il primo match e' la federazione principale)
$promoRules = [ordered]@{
  'WWE'  = '\bWWE\b|\bRaw\b|SmackDown|\bNXT\b|WrestleMania|Royal Rumble|Survivor Series|SummerSlam|Crown Jewel|Elimination Chamber|Saturday Night.s Main Event|\bTKO\b'
  'AEW'  = '\bAEW\b|All Elite|Dynamite|\bCollision\b|Full Gear|Worlds End|Tony Khan|\bAll In\b|Forbidden Door'
  'TNA'  = '\bTNA\b|\biMPACT\b|Bound for Glory'
  'NJPW' = '\bNJPW\b|New Japan|Wrestle Kingdom|\bIWGP\b|\bG1\b|Stardom'
  'ROH'  = '\bROH\b|Ring of Honor'
  'Altre'= '\bCMLL\b|\bAAA\b|\bGCW\b|\bMLW\b|\bNWA\b|\bICW\b|\bPWG\b|\bWWE ID\b'
}

function Get-Promotions([string]$text) {
  $found = @()
  foreach ($k in $promoRules.Keys) { if ($text -cmatch $promoRules[$k]) { $found += $k } }
  return ,$found
}

function Get-Id([string]$s) {
  $sha = [Security.Cryptography.SHA1]::Create()
  $b = $sha.ComputeHash($utf8.GetBytes($s))
  return ([BitConverter]::ToString($b) -replace '-', '').Substring(0, 12).ToLower()
}

# ---------- 1. Notizie ----------
$sources = Read-Json (Join-Path $dataDir 'sources.json')
$existing = Read-Json (Join-Path $dataDir 'news.json')
$byLink = @{}
if ($existing -and $existing.items) { foreach ($i in $existing.items) { $byLink[$i.link] = $i } }

$report = @()
$now = [DateTimeOffset]::UtcNow
foreach ($src in $sources) {
  if (-not $src.enabled) { continue }
  try {
    $resp = Invoke-WebRequest -Uri $src.feed -UseBasicParsing -TimeoutSec 25 -UserAgent 'Mozilla/5.0 (compatible; WrestlingHubItalia/1.0; +https://wrestlinghubitalia.com)'
    $ms = New-Object IO.MemoryStream
    $resp.RawContentStream.Position = 0
    $resp.RawContentStream.CopyTo($ms)
    $xmlText = $utf8.GetString($ms.ToArray()).TrimStart([char]0xFEFF)
    # alcuni feed (plugin WordPress) dichiarano due volte lo stesso attributo nel tag radice: tiene solo il primo
    $rootTag = [regex]::Match($xmlText, '<(rss|feed)\b[^>]*>')
    if ($rootTag.Success) {
      $seenAttr = @{}
      $fixedTag = [regex]::Replace($rootTag.Value, '\s([\w:.-]+)\s*=\s*("[^"]*"|''[^'']*'')', {
        param($m) if ($seenAttr.ContainsKey($m.Groups[1].Value)) { '' } else { $seenAttr[$m.Groups[1].Value] = 1; $m.Value } })
      if ($fixedTag -ne $rootTag.Value) { $xmlText = $xmlText.Remove($rootTag.Index, $rootTag.Length).Insert($rootTag.Index, $fixedTag) }
    }
    $xml = New-Object System.Xml.XmlDocument
    $xml.XmlResolver = $null
    $xml.LoadXml($xmlText)

    $nodes = @($xml.SelectNodes('//*[local-name()="item"]'))
    if ($nodes.Count -eq 0) { $nodes = @($xml.SelectNodes('//*[local-name()="entry"]')) }
    $count = 0
    foreach ($it in $nodes) {
      $title = Clean-Text ((Get-Child $it 'title').InnerText)
      $linkNode = Get-Child $it 'link'
      $link = if ($linkNode -and $linkNode.GetAttribute('href')) { $linkNode.GetAttribute('href') } elseif ($linkNode) { $linkNode.InnerText.Trim() } else { '' }
      if (-not $title -or -not $link) { continue }
      $descNode = Get-Child $it 'description'; if (-not $descNode) { $descNode = Get-Child $it 'summary' }
      $encNode  = Get-Child $it 'encoded';     if (-not $encNode)  { $encNode  = Get-Child $it 'content' }
      $descHtml = if ($descNode) { $descNode.InnerText } else { '' }
      $encHtml  = if ($encNode)  { $encNode.InnerText }  else { '' }
      $dateNode = Get-Child $it 'pubDate'; if (-not $dateNode) { $dateNode = Get-Child $it 'published' }; if (-not $dateNode) { $dateNode = Get-Child $it 'updated' }
      $date = if ($dateNode) { Parse-Date $dateNode.InnerText } else { $null }
      if (-not $date) { $date = $now }
      if ($date -gt $now.AddHours(1)) { $date = $now }

      # toglie i link all'autore (/author/, /autore/) che alcuni feed mettono prima del testo
      $authorLink = '(?is)<a[^>]+/(author|autore)/[^>]*>.*?</a>'
      $excerpt = Clean-Text ($descHtml -replace $authorLink, ' ')
      if (-not $excerpt) { $excerpt = Clean-Text ($encHtml -replace $authorLink, ' ') }
      # alcuni feed ripetono autore e titolo all'inizio dell'estratto: tiene solo il testo dopo il titolo
      $pos = $excerpt.IndexOf($title)
      if ($pos -ge 0 -and $pos -le 60 -and $excerpt.Length -gt $pos + $title.Length + 20) { $excerpt = $excerpt.Substring($pos + $title.Length).Trim() }
      $excerpt = Shorten $excerpt 240
      $image = Find-Image $it ($descHtml + ' ' + $encHtml)
      # se il feed non ha immagine, conserva quella gia' recuperata dalla pagina nelle esecuzioni precedenti
      $old = $byLink[$link]
      $imgTried = [bool]($old -and $old.imgTried)
      if (-not $image -and $old -and $old.image) { $image = $old.image }

      $byLink[$link] = [pscustomobject]@{
        id       = Get-Id $link
        title    = $title
        link     = $link
        excerpt  = $excerpt
        image    = $image
        source   = $src.name
        lang     = $src.lang
        date     = $date.ToString('yyyy-MM-ddTHH:mm:ssZ', $inv)
        promos   = Get-Promotions ($title + ' ' + $excerpt)
        imgTried = $imgTried
      }
      $count++
    }
    $report += '{0,-18} OK   {1} notizie' -f $src.name, $count
  } catch {
    $report += '{0,-18} ERRORE {1}' -f $src.name, $_.Exception.Message
  }
}

# ordina, rimuove doppioni per titolo, taglia per eta' e quantita'
$cutoff = $now.AddDays(-$MaxDays)
$seenTitles = @{}
$items = @()
foreach ($i in ($byLink.Values | Sort-Object { [DateTimeOffset]::Parse($_.date, $inv) } -Descending)) {
  if ([DateTimeOffset]::Parse($i.date, $inv) -lt $cutoff) { continue }
  $key = ($i.title.ToLower() -replace '[^a-z0-9]', '')
  if ($seenTitles.ContainsKey($key)) { continue }
  $seenTitles[$key] = $true
  $items += $i
  if ($items.Count -ge $MaxItems) { break }
}

# recupera l'immagine dalla pagina dell'articolo per le notizie che ne sono prive
# (una sola volta per articolo, al massimo 60 per esecuzione)
$fetched = 0; $recovered = 0
foreach ($i in $items) {
  if ($i.image -or $i.imgTried -or $fetched -ge 60) { continue }
  $fetched++
  $img = Get-PageImage $i.link
  if ($img) { $i.image = $img; $recovered++ }
  $i | Add-Member -NotePropertyName imgTried -NotePropertyValue $true -Force
}
if ($fetched) { $report += "Immagini recuperate dalle pagine: $recovered su $fetched" }

$news = [pscustomobject]@{ updated = $now.ToString('yyyy-MM-ddTHH:mm:ssZ', $inv); items = $items }
$newsJson = $news | ConvertTo-Json -Depth 6 -Compress
Write-Text (Join-Path $dataDir 'news.json') $newsJson
Write-Text (Join-Path $dataDir 'news.js') ("window.WH_NEWS = $newsJson;")

# ---------- 2. Calendario e fonti (da JSON a JS per le pagine) ----------
foreach ($pair in @(@('events.json', 'events.js', 'WH_EVENTS'), @('sources.json', 'sources.js', 'WH_SOURCES'), @('italia.json', 'italia.js', 'WH_ITALIA'))) {
  $p = Join-Path $dataDir $pair[0]
  if (Test-Path $p) {
    $raw = [IO.File]::ReadAllText($p, $utf8)
    $null = $raw | ConvertFrom-Json   # verifica che il JSON sia valido
    Write-Text (Join-Path $dataDir $pair[1]) ("window.$($pair[2]) = " + $raw.Trim() + ';')
  }
}

$report
"Totale notizie nel sito: $($items.Count)  (aggiornato $($news.updated))"
