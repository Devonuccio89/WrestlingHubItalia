# WrestlingHub Italia - genera le pagine statiche (guide ed eventi).
# - contenuti/guide/*.html  -> guide/<slug>.html + guide/index.html (divise per sezione)
# - contenuti/eventi/<id>.html + data/events.json -> eventi/<id>.html (scheda evento)
# - sitemap.xml, robots.txt e data/pagine-eventi.js (link alle schede usati da calendario e home)
# Ogni file di contenuto inizia con un'intestazione tra <!-- --> (chiave: valore) seguita dal corpo HTML.
# Pagine HTML vere (non generate via JavaScript) cosi' Google le indicizza.

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$site = 'https://wrestlinghubitalia.com'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$it = [Globalization.CultureInfo]'it-IT'
$tz = try { [TimeZoneInfo]::FindSystemTimeZoneById('Europe/Rome') } catch { [TimeZoneInfo]::FindSystemTimeZoneById('W. Europe Standard Time') }

function HtmlEnc([string]$s) { return [System.Net.WebUtility]::HtmlEncode($s) }
function J([string]$s) { return ($s -replace '\\', '\\' -replace '"', '\"') }
function Write-Utf8($path, $text) { [IO.File]::WriteAllText($path, $text, $utf8) }

$head = @'
<!doctype html>
<html lang="it">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <base href="/">
  <title>{TITLE} | WrestlingHub Italia</title>
  <meta name="description" content="{DESC}">
  <link rel="canonical" href="{URL}">
  <meta property="og:type" content="{OGTYPE}">
  <meta property="og:title" content="{TITLE}">
  <meta property="og:description" content="{DESC}">
  <meta property="og:url" content="{URL}">
  <meta property="og:locale" content="it_IT">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&family=Oswald:wght@500;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="assets/style.css">
{JSONLD}
</head>
<body data-page="{PAGE}">
  <header class="site-header" id="site-header"></header>
  <main class="wrap">
'@

$foot = @'
  </main>
  <footer class="site-footer" id="site-footer"></footer>
  <script src="assets/ads-config.js"></script>
  <script src="assets/app.js"></script>
</body>
</html>
'@

function Page($meta, $url, $ogType, $jsonLd, $body, $page) {
  $h = $head.Replace('{TITLE}', (HtmlEnc $meta.title)).Replace('{DESC}', (HtmlEnc $meta.description)).Replace('{URL}', $url).Replace('{OGTYPE}', $ogType).Replace('{JSONLD}', $jsonLd).Replace('{PAGE}', $page)
  return $h + $body + "`n" + $foot
}

function Read-Content($dir) {
  $list = @()
  if (-not (Test-Path $dir)) { return $list }
  foreach ($f in (Get-ChildItem $dir -Filter *.html)) {
    $raw = [IO.File]::ReadAllText($f.FullName, $utf8)
    if ($raw -notmatch '(?s)^\s*<!--(.*?)-->(.*)$') { Write-Warning "Intestazione mancante: $($f.Name)"; continue }
    $header = $Matches[1]
    $meta = @{ body = $Matches[2].Trim(); file = $f.BaseName }
    foreach ($line in ($header -split "`n")) {
      if ($line -match '^\s*([a-z]+)\s*:\s*(.+?)\s*$') { $meta[$Matches[1]] = $Matches[2] }
    }
    if (-not $meta.slug) { $meta.slug = $f.BaseName }
    if (-not $meta.order) { $meta.order = 99 }
    if (-not $meta.section) { $meta.section = 'Altre guide' }
    $list += [pscustomobject]$meta
  }
  return $list
}

function Fmt-Date([string]$iso) { return [datetime]::ParseExact($iso, 'yyyy-MM-dd', $null).ToString('d MMMM yyyy', $it) }

function Guide-Card($g, [switch]$WithRead) {
  $read = if ($WithRead) { '<span class="read">Leggi &middot; ' + $g.minutes + ' min &rarr;</span>' } else { '' }
  return '<a class="article-card" href="guide/' + $g.slug + '.html"><span class="kick">' + (HtmlEnc $g.kicker) + '</span><h3>' + (HtmlEnc $g.title) +
    '</h3><p>' + (HtmlEnc $g.description) + '</p>' + $read + '</a>'
}

# =================== GUIDE ===================
$guideDir = Join-Path $root 'guide'
New-Item -ItemType Directory -Force $guideDir | Out-Null
$guides = @(Read-Content (Join-Path $root 'contenuti/guide') | Sort-Object { [int]$_.order })

foreach ($g in $guides) {
  $url = "$site/guide/$($g.slug).html"
  $jsonLd = '  <script type="application/ld+json">{"@context":"https://schema.org","@type":"Article","headline":"' + (J $g.title) +
    '","description":"' + (J $g.description) + '","dateModified":"' + $g.updated + '","inLanguage":"it-IT","mainEntityOfPage":"' + $url +
    '","author":{"@type":"Organization","name":"WrestlingHub Italia"},"publisher":{"@type":"Organization","name":"WrestlingHub Italia","url":"' + $site + '"}}</script>'
  # correlati: prima la stessa sezione, poi le altre (massimo 4)
  $others = @($guides | Where-Object { $_.slug -ne $g.slug })
  $related = @($others | Where-Object { $_.section -eq $g.section }) + @($others | Where-Object { $_.section -ne $g.section })
  $relatedHtml = ($related | Select-Object -First 4 | ForEach-Object { Guide-Card $_ }) -join "`n"
  $body = @"
    <article class="reader">
      <nav class="crumbs"><a href="index.html">Home</a> &rsaquo; <a href="guide/index.html">Guide</a> &rsaquo; $(HtmlEnc $g.section)</nav>
      <div class="kick">$(HtmlEnc $g.kicker)</div>
      <h1>$(HtmlEnc $g.title)</h1>
      <p class="lede">$(HtmlEnc $g.description)</p>
      <div class="byline">Redazione WrestlingHub Italia &middot; Aggiornato il $(Fmt-Date $g.updated) &middot; $($g.minutes) min di lettura</div>
$($g.body)
    </article>
    <div class="section-title"><h2>Leggi anche</h2></div>
    <div class="articles">
$relatedHtml
    </div>
"@
  Write-Utf8 (Join-Path $guideDir "$($g.slug).html") (Page $g $url 'article' $jsonLd $body 'guide')
}

# indice delle guide, diviso per sezione (ordine: sezione con l'articolo di ordine piu' basso prima)
$sections = $guides | Group-Object section | Sort-Object { ($_.Group | ForEach-Object { [int]$_.order } | Measure-Object -Minimum).Minimum }
$sectionsHtml = ($sections | ForEach-Object {
  "    <div class=""section-title""><h2>$(HtmlEnc $_.Name)</h2></div>`n    <div class=""articles"">`n" +
  (($_.Group | ForEach-Object { Guide-Card $_ -WithRead }) -join "`n") + "`n    </div>"
}) -join "`n"
$indexMeta = @{ title = 'Guide al wrestling: dove vederlo in Italia, per chi inizia e classifiche'; description = 'Le guide di WrestlingHub Italia: dove vedere WWE, AEW, TNA e NJPW in Italia, orari, guida per principianti, glossario e classifiche dei match e delle mosse più famose.' }
$indexBody = @"
    <div class="section-title"><h1>Guide</h1><span class="updated">Dove vederlo, per chi inizia, classifiche</span></div>
$sectionsHtml
"@
Write-Utf8 (Join-Path $guideDir 'index.html') (Page $indexMeta "$site/guide/index.html" 'website' '' $indexBody 'guide')

# articoli originali da mostrare nel flusso notizie della home (riepilogo piu' recente prima, poi le classifiche)
$feedSections = @('Riepilogo settimanale', 'Classifiche ed elenchi')
$feedItems = @($guides | Where-Object { $feedSections -contains $_.section } |
  Sort-Object @{ e = { $feedSections.IndexOf($_.section) } }, @{ e = { if ($_.section -eq 'Riepilogo settimanale') { $_.updated } else { '' } }; Descending = $true }, @{ e = { [int]$_.order } } |
  ForEach-Object { [ordered]@{ url = "guide/$($_.slug).html"; title = $_.title; description = $_.description; kicker = $_.kicker; section = $_.section; updated = $_.updated; minutes = $_.minutes } })
Write-Utf8 (Join-Path $root 'data/articoli.js') ('window.WH_ARTICLES = ' + (ConvertTo-Json @($feedItems) -Depth 3 -Compress) + ';')

# =================== EVENTI ===================
$eventDir = Join-Path $root 'eventi'
New-Item -ItemType Directory -Force $eventDir | Out-Null
$eventsData = [IO.File]::ReadAllText((Join-Path $root 'data/events.json'), $utf8) | ConvertFrom-Json
$eventContent = @{}
foreach ($c in (Read-Content (Join-Path $root 'contenuti/eventi'))) { $eventContent[$c.file] = $c }
$guideFor = @{ WWE = 'dove-vedere-wwe-in-italia'; AEW = 'dove-vedere-aew-in-italia'; TNA = 'dove-vedere-tna-in-italia'; NJPW = 'dove-vedere-njpw-in-italia' }

$withPages = @($eventsData.events | Where-Object { $eventContent.ContainsKey($_.id) } | Sort-Object date)
$pageMap = [ordered]@{}
foreach ($ev in $withPages) {
  $c = $eventContent[$ev.id]
  $url = "$site/eventi/$($ev.id).html"
  $pageMap[$ev.id] = "eventi/$($ev.id).html"

  function Day-Text([datetime]$d) { $t = $d.ToString('dddd d MMMM yyyy', $it); return $t.Substring(0, 1).ToUpper() + $t.Substring(1) }
  $dayText = Day-Text ([datetime]::ParseExact($ev.date, 'yyyy-MM-dd', $null))
  if ($ev.dateConfirmed -eq $false) { $whenHtml = "$dayText <span class=""badge-tbc"">data non ufficiale</span>"; $startIso = $ev.date }
  elseif ($ev.startUtc) {
    # giorno e ora in Italia (uno show serale americano cade spesso il giorno dopo)
    $utc = [DateTimeOffset]::Parse($ev.startUtc, [Globalization.CultureInfo]::InvariantCulture)
    $local = [TimeZoneInfo]::ConvertTime($utc, $tz)
    $whenHtml = "$(Day-Text $local.DateTime), ore $($local.ToString('HH:mm')) (ora italiana)"; $startIso = $local.ToString('yyyy-MM-ddTHH:mm:sszzz')
  } else { $whenHtml = "$dayText <span class=""badge-tbc"">orario da confermare</span>"; $startIso = $ev.date }

  $where = (@($ev.venue, $ev.city, $ev.country) | Where-Object { $_ }) -join ', '
  $buttons = @()
  if ($ev.tickets) { $buttons += '<a class="btn primary" target="_blank" rel="noopener" href="' + (HtmlEnc $ev.tickets) + '">&#127903; Acquista biglietti</a>' }
  if ($ev.watchUrl) { $buttons += '<a class="btn" target="_blank" rel="noopener" href="' + (HtmlEnc $ev.watchUrl) + '">&#128250; Dove vederlo</a>' }
  if ($guideFor[$ev.promotion]) { $buttons += '<a class="btn" href="guide/' + $guideFor[$ev.promotion] + '.html">Guida: ' + $ev.promotion + ' in Italia</a>' }

  $offers = if ($ev.tickets) { ',"offers":{"@type":"Offer","url":"' + (J $ev.tickets) + '"}' } else { '' }
  $jsonLd = '  <script type="application/ld+json">{"@context":"https://schema.org","@type":"SportsEvent","name":"' + (J $ev.name) +
    '","description":"' + (J $c.description) + '","startDate":"' + $startIso + '","eventStatus":"https://schema.org/EventScheduled",' +
    '"eventAttendanceMode":"https://schema.org/MixedEventAttendanceMode","location":{"@type":"Place","name":"' + (J $ev.venue) +
    '","address":"' + (J ((@($ev.city, $ev.country) | Where-Object { $_ }) -join ', ')) + '"},"organizer":{"@type":"Organization","name":"' + (J $ev.promotion) + '"}' + $offers + '}</script>'

  $otherEvents = ($withPages | Where-Object { $_.id -ne $ev.id } | ForEach-Object {
    $d = [datetime]::ParseExact($_.date, 'yyyy-MM-dd', $null)
    '<a class="mini-event" href="eventi/' + $_.id + '.html"><div class="datebox"><b>' + $d.Day + '</b><small>' + $d.ToString('MMM', $it) + '</small></div><div><div class="t">' +
      (HtmlEnc $_.name) + '</div><div class="s">' + (HtmlEnc $_.promotion) + ' &middot; ' + (HtmlEnc $_.city) + '</div></div></a>'
  }) -join "`n"

  $meta = @{ title = $c.title; description = $c.description }
  $body = @"
    <article class="reader">
      <nav class="crumbs"><a href="index.html">Home</a> &rsaquo; <a href="calendario.html">Calendario</a> &rsaquo; $(HtmlEnc $ev.promotion)</nav>
      <span class="tag $(HtmlEnc $ev.promotion)">$(HtmlEnc $ev.promotion)</span>
      <h1>$(HtmlEnc $c.title)</h1>
      <p class="lede">$(HtmlEnc $c.description)</p>
      <div class="byline">Redazione WrestlingHub Italia &middot; Aggiornato il $(Fmt-Date $c.updated)</div>
      <section class="event-box $(HtmlEnc $ev.promotion)">
        <div><span>Quando</span>$whenHtml</div>
        <div><span>Dove</span>$(HtmlEnc $where)</div>
        <div><span>In TV / streaming in Italia</span>$(HtmlEnc $ev.broadcastIT)</div>
        <div class="event-box-actions">$($buttons -join ' ')</div>
      </section>
$($c.body)
    </article>
    <div class="section-title"><h2>Altri eventi in arrivo</h2><a class="updated" href="calendario.html">Calendario completo &rarr;</a></div>
    <div class="box event-list">
$otherEvents
    </div>
"@
  Write-Utf8 (Join-Path $eventDir "$($ev.id).html") (Page $meta $url 'article' $jsonLd $body 'evento')
}
Write-Utf8 (Join-Path $root 'data/pagine-eventi.js') ('window.WH_EVENT_PAGES = ' + ($pageMap | ConvertTo-Json -Compress) + ';')

# =================== SITEMAP E ROBOTS ===================
$today = (Get-Date).ToString('yyyy-MM-dd')
$urls = @(
  @("$site/", $today, 'hourly'), @("$site/calendario.html", $today, 'daily'), @("$site/italia.html", $today, 'weekly'),
  @("$site/guide/index.html", $today, 'weekly'), @("$site/fonti.html", $today, 'monthly')
)
foreach ($g in $guides) { $urls += ,@("$site/guide/$($g.slug).html", $g.updated, 'monthly') }
foreach ($ev in $withPages) { $urls += ,@("$site/eventi/$($ev.id).html", $eventContent[$ev.id].updated, 'daily') }
$xml = '<?xml version="1.0" encoding="UTF-8"?>' + "`n" + '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + "`n" +
  (($urls | ForEach-Object { "  <url><loc>$($_[0])</loc><lastmod>$($_[1])</lastmod><changefreq>$($_[2])</changefreq></url>" }) -join "`n") + "`n</urlset>`n"
Write-Utf8 (Join-Path $root 'sitemap.xml') $xml
Write-Utf8 (Join-Path $root 'robots.txt') "User-agent: *`nAllow: /`n`nSitemap: $site/sitemap.xml`n"

"Guide generate: $($guides.Count)"
"Schede evento generate: $($withPages.Count)"
$withPages | ForEach-Object { "  eventi/$($_.id).html" }
