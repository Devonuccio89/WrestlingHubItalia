/* WrestlingHub Italia - logica delle pagine.
   Dati: window.WH_NEWS (data/news.js), window.WH_EVENTS (data/events.js), window.WH_SOURCES (data/sources.js). */
(function () {
  'use strict';

  var TZ = 'Europe/Rome';
  var PROMOS = ['WWE', 'AEW', 'TNA', 'NJPW', 'ROH', 'Altre'];
  var PAGE_SIZE = 24;
  var page = document.body.getAttribute('data-page');

  // ---------- utilità ----------
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function $(sel) { return document.querySelector(sel); }
  function fmt(d, opts) { return new Intl.DateTimeFormat('it-IT', Object.assign({ timeZone: TZ }, opts)).format(d); }
  function cap(s) { return s.charAt(0).toUpperCase() + s.slice(1); }

  function timeAgo(iso) {
    var diff = (new Date(iso) - Date.now()) / 1000;
    var rtf = new Intl.RelativeTimeFormat('it', { numeric: 'auto' });
    var steps = [[60, 'second'], [3600, 'minute', 60], [86400, 'hour', 3600], [604800, 'day', 86400]];
    if (Math.abs(diff) < 60) return 'adesso';
    for (var i = 1; i < steps.length; i++) {
      if (Math.abs(diff) < steps[i][0]) return rtf.format(Math.round(diff / steps[i][2]), steps[i][1]);
    }
    return fmt(new Date(iso), { day: 'numeric', month: 'short' });
  }

  // Link alla scheda statica dell'evento, se esiste (data/pagine-eventi.js generato da genera-guide.ps1)
  function eventPage(ev) { return (window.WH_EVENT_PAGES || {})[ev.id] || ''; }

  // Data di riferimento dell'evento: orario d'inizio se noto, altrimenti la data (mezzogiorno UTC)
  function eventDate(ev) { return new Date(ev.startUtc || (ev.date + 'T12:00:00Z')); }

  function upcomingEvents() {
    var data = window.WH_EVENTS || { events: [] };
    var startOfToday = new Date(); startOfToday.setHours(0, 0, 0, 0);
    return (data.events || [])
      .filter(function (e) { return new Date(e.date + 'T23:59:59') >= startOfToday; })
      .sort(function (a, b) { return eventDate(a) - eventDate(b); });
  }

  function whenText(ev) {
    var d = eventDate(ev);
    var day = cap(fmt(d, { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }));
    if (ev.dateConfirmed === false) return day + ' (data non ufficiale)';
    if (!ev.startUtc) return day + ' · orario da confermare';
    return day + ' · ore ' + fmt(d, { hour: '2-digit', minute: '2-digit' }) + ' (ora italiana)';
  }

  // ---------- pubblicità (Google AdSense) ----------
  var ADS = window.WH_ADS || { slots: {} };
  var adsLive = !!ADS.client;

  if (adsLive) {
    var s = document.createElement('script');
    s.async = true;
    s.crossOrigin = 'anonymous';
    s.src = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=' + encodeURIComponent(ADS.client);
    document.head.appendChild(s);
  }

  // Restituisce l'HTML di uno spazio annuncio; senza ID editore mostra un segnaposto.
  function adSlot(name, cls) {
    var slot = ADS.slots && ADS.slots[name];
    var inner = adsLive && slot
      ? '<ins class="adsbygoogle" style="display:block" data-ad-client="' + esc(ADS.client) + '" data-ad-slot="' + esc(slot) +
        '" data-ad-format="' + (name === 'infeed' ? 'fluid' : 'auto') + '"' + (name === 'infeed' ? ' data-ad-layout-key="-6t+ed+2i-1n-4w"' : '') +
        ' data-full-width-responsive="true"></ins>'
      : '<div class="ad-ph">Spazio pubblicitario</div>';
    return '<div class="ad ad-' + name + ' ' + (cls || '') + '"><span class="ad-label">Pubblicità</span>' + inner + '</div>';
  }

  // Attiva gli annunci appena inseriti nella pagina
  function fillAds() {
    if (!adsLive) return;
    document.querySelectorAll('ins.adsbygoogle:not([data-adsbygoogle-status])').forEach(function () {
      try { (window.adsbygoogle = window.adsbygoogle || []).push({}); } catch (e) { /* adblock o slot non valido */ }
    });
  }

  // ---------- header / footer comuni ----------
  function chrome() {
    var links = [['index.html', 'Notizie', 'home'], ['calendario.html', 'Calendario', 'calendario'], ['italia.html', 'Wrestling italiano', 'italia'], ['guide/index.html', 'Guide', 'guide'], ['fonti.html', 'Fonti', 'fonti']];
    var nav = links.map(function (l) {
      var on = page === l[2] || (page === 'evento' && l[2] === 'calendario');
      return '<a href="' + l[0] + '"' + (on ? ' class="active"' : '') + '>' + l[1] + '</a>';
    }).join('');
    $('#site-header').innerHTML =
      '<div class="wrap"><a class="logo" href="index.html">Wrestling<span>Hub</span><small>Italia</small></a><nav class="nav">' + nav + '</nav></div>';
    $('#site-footer').innerHTML =
      '<div class="wrap"><div>© ' + new Date().getFullYear() + ' WrestlingHubItalia.com — aggregatore di notizie. ' +
      'I contenuti appartengono alle rispettive testate, linkate in ogni articolo.</div>' +
      '<div><a href="fonti.html">Fonti</a> · <a href="privacy.html">Privacy e cookie</a></div></div>';
    // banner orizzontale sotto l'header, su tutte le pagine
    var main = document.querySelector('main');
    if (main) main.insertAdjacentHTML('afterbegin', adSlot('top'));
    // spazi annuncio dichiarati nelle pagine statiche (es. <div data-ad="article"></div> nelle guide)
    document.querySelectorAll('[data-ad]').forEach(function (el) { el.outerHTML = adSlot(el.getAttribute('data-ad')); });
  }

  // ---------- prossimo evento + countdown ----------
  function renderNextEvent(el) {
    var ev = upcomingEvents()[0];
    if (!el || !ev) { if (el) el.remove(); return; }
    el.innerHTML =
      '<div><div class="label">Prossimo grande evento · ' + esc(ev.promotion) + '</div>' +
      '<h2>' + esc(ev.name) + '</h2>' +
      '<div class="meta">' + esc(whenText(ev)) + '<br>' + esc([ev.venue, ev.city, ev.country].filter(Boolean).join(', ')) +
      (ev.broadcastIT ? '<br>In Italia: <b>' + esc(ev.broadcastIT) + '</b>' : '') + '</div>' +
      '<div style="margin-top:12px;display:flex;gap:8px;flex-wrap:wrap">' +
      (ev.tickets ? '<a class="btn primary" target="_blank" rel="noopener" href="' + esc(ev.tickets) + '">Biglietti</a>' : '') +
      '<a class="btn" href="' + (eventPage(ev) || 'calendario.html#' + esc(ev.id)) + '">Card e dettagli</a></div></div>' +
      '<div class="countdown" id="cd"></div>';
    var target = eventDate(ev);
    function tick() {
      var s = Math.max(0, Math.floor((target - Date.now()) / 1000));
      var parts = [[Math.floor(s / 86400), 'giorni'], [Math.floor(s % 86400 / 3600), 'ore'], [Math.floor(s % 3600 / 60), 'min'], [s % 60, 'sec']];
      $('#cd').innerHTML = parts.map(function (p) { return '<div><b>' + p[0] + '</b><small>' + p[1] + '</small></div>'; }).join('');
    }
    tick(); setInterval(tick, 1000);
  }

  // ---------- notizie ----------
  function newsCard(n, lead) {
    var tags = (n.promos || []).slice(0, 2).map(function (p) { return '<span class="tag ' + p + '">' + p + '</span>'; }).join('');
    var thumb = n.image
      ? '<div class="thumb" style="background-image:url(\'' + esc(n.image).replace(/'/g, '%27') + '\')"><div class="tags">' + tags + '</div></div>'
      : '<div class="thumb ph">WHI<div class="tags">' + tags + '</div></div>';
    return '<a class="news-card' + (lead ? ' lead' : '') + '" href="' + esc(n.link) + '" target="_blank" rel="noopener">' + thumb +
      '<div class="body"><h3>' + esc(n.title) + '</h3><p>' + esc(n.excerpt) + '</p>' +
      '<div class="foot"><span><span class="src">' + esc(n.source) + '</span><span class="lang">' + esc((n.lang || '').toUpperCase()) + '</span></span>' +
      '<span>' + timeAgo(n.date) + '</span></div></div></a>';
  }

  // Card per gli articoli originali (classifiche, elenchi, riepilogo) mescolati alle notizie
  function articleCard(a) {
    var icon = a.section === 'Riepilogo settimanale' ? '📰' : (a.kicker === 'Classifica' ? '🏆' : '📋');
    return '<a class="news-card original" href="' + esc(a.url) + '">' +
      '<div class="thumb orig-thumb"><span class="orig-icon">' + icon + '</span><span class="orig-kick">' + esc(a.kicker) + '</span>' +
      '<div class="tags"><span class="tag orig">Originale WHI</span></div></div>' +
      '<div class="body"><h3>' + esc(a.title) + '</h3><p>' + esc(a.description) + '</p>' +
      '<div class="foot"><span class="src">WrestlingHub Italia</span><span>Leggi · ' + esc(a.minutes) + ' min →</span></div></div></a>';
  }

  function renderHome() {
    var news = window.WH_NEWS || { items: [] };
    var state = { promo: 'Tutte', lang: 'tutte', q: '', shown: PAGE_SIZE };
    renderNextEvent($('#next-event'));
    if (news.updated) $('#updated').textContent = 'Aggiornato ' + timeAgo(news.updated);

    var promoChips = ['Tutte'].concat(PROMOS).map(function (p) { return '<button class="chip" data-promo="' + p + '">' + p + '</button>'; }).join('');
    var langChips = [['tutte', 'IT + EN'], ['it', 'Solo italiano'], ['en', 'Solo estero']].map(function (l) {
      return '<button class="chip" data-lang="' + l[0] + '">' + l[1] + '</button>';
    }).join('');
    $('#filters').innerHTML = promoChips + '<span class="sep"></span>' + langChips +
      '<input class="search" id="q" type="search" placeholder="Cerca un wrestler, uno show...">';

    $('#filters').addEventListener('click', function (e) {
      var b = e.target.closest('.chip'); if (!b) return;
      if (b.dataset.promo) state.promo = b.dataset.promo;
      if (b.dataset.lang) state.lang = b.dataset.lang;
      state.shown = PAGE_SIZE; draw();
    });
    $('#q').addEventListener('input', function (e) { state.q = e.target.value.trim().toLowerCase(); state.shown = PAGE_SIZE; draw(); });
    $('#more').addEventListener('click', function () { state.shown += PAGE_SIZE; draw(); });

    var card = newsCard;

    function draw() {
      document.querySelectorAll('#filters .chip').forEach(function (c) {
        c.classList.toggle('on', c.dataset.promo === state.promo || c.dataset.lang === state.lang);
      });
      var list = news.items.filter(function (n) {
        if (state.promo !== 'Tutte' && (n.promos || []).indexOf(state.promo) < 0) return false;
        if (state.lang !== 'tutte' && n.lang !== state.lang) return false;
        if (state.q && (n.title + ' ' + n.excerpt).toLowerCase().indexOf(state.q) < 0) return false;
        return true;
      });
      // articoli originali: visibili con "Tutte" le federazioni e non in "Solo estero"; la ricerca filtra anche loro
      var articles = (window.WH_ARTICLES || []).filter(function (a) {
        if (state.promo !== 'Tutte' || state.lang === 'en') return false;
        return !state.q || (a.title + ' ' + a.description).toLowerCase().indexOf(state.q) >= 0;
      });
      var every = ADS.infeedEvery || 8;
      var ARTICLE_FIRST = 2, ARTICLE_EVERY = 5; // il primo dopo 2 notizie, poi uno ogni 5
      var html = list.slice(0, state.shown).map(function (n, i) {
        var k = (i + 1 - ARTICLE_FIRST) / ARTICLE_EVERY;
        var art = (k >= 0 && k % 1 === 0 && articles[k]) ? articleCard(articles[k]) : '';
        return card(n, i === 0 && !!n.image) + art + ((i + 1) % every === 0 ? adSlot('infeed', 'news-ad') : '');
      }).join('');
      if (!list.length && articles.length) html = articles.map(articleCard).join('');
      $('#news').innerHTML = html || '<div class="empty">Nessuna notizia trovata con questi filtri.</div>';
      $('#more').style.display = list.length > state.shown ? '' : 'none';
      fillAds();
    }
    draw();

    // sidebar: prossimi eventi + show settimanali
    var evs = upcomingEvents().slice(0, 6);
    $('#side-events').innerHTML = '<h3>Prossimi eventi</h3>' + (evs.map(miniEvent).join('') || '<div class="empty">Nessun evento in programma.</div>') +
      '<a class="btn sm" style="margin-top:10px" href="calendario.html">Calendario completo →</a>';
    $('#side-ad').innerHTML = adSlot('sidebar');
    var weekly = (window.WH_EVENTS && window.WH_EVENTS.weekly) || [];
    $('#side-weekly').innerHTML = '<h3>Show settimanali in Italia</h3>' + weekly.map(function (w) {
      return '<div class="mini-event" style="grid-template-columns:1fr"><div><div class="t">' + esc(w.show) + '</div><div class="s">' +
        esc(w.day) + (w.timeIT ? ' · ' + esc(w.timeIT) : '') + ' · ' + esc(w.broadcastIT) + '</div></div></div>';
    }).join('');
  }

  function miniEvent(ev) {
    var d = eventDate(ev);
    return '<a class="mini-event" href="' + (eventPage(ev) || 'calendario.html#' + esc(ev.id)) + '"><div class="datebox"><b>' + fmt(d, { day: 'numeric' }) + '</b><small>' +
      fmt(d, { month: 'short' }) + '</small></div><div><div class="t">' + esc(ev.name) + '</div><div class="s">' + esc(ev.promotion) + ' · ' +
      (ev.startUtc ? 'ore ' + fmt(d, { hour: '2-digit', minute: '2-digit' }) : 'orario TBA') + ' · ' + esc(ev.broadcastIT || '') + '</div></div></a>';
  }

  // ---------- calendario ----------
  function gcalLink(ev) {
    var start = eventDate(ev);
    var end = new Date(start.getTime() + 4 * 3600 * 1000);
    function z(d) { return d.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, ''); }
    var dates = ev.startUtc ? z(start) + '/' + z(end) : ev.date.replace(/-/g, '') + '/' + ev.date.replace(/-/g, '');
    return 'https://calendar.google.com/calendar/render?action=TEMPLATE&text=' + encodeURIComponent(ev.name) +
      '&dates=' + dates + '&location=' + encodeURIComponent([ev.venue, ev.city].filter(Boolean).join(', ')) +
      '&details=' + encodeURIComponent('In Italia: ' + (ev.broadcastIT || 'da confermare') + '\nBiglietti: ' + (ev.tickets || '-') + '\nwrestlinghubitalia.com');
  }

  function renderCalendar() {
    var all = upcomingEvents();
    var state = { promo: 'Tutte' };
    var present = PROMOS.filter(function (p) { return all.some(function (e) { return e.promotion === p; }); });
    $('#filters').innerHTML = ['Tutte'].concat(present).map(function (p) { return '<button class="chip" data-promo="' + p + '">' + p + '</button>'; }).join('');
    $('#filters').addEventListener('click', function (e) {
      var b = e.target.closest('.chip'); if (!b) return; state.promo = b.dataset.promo; draw();
    });
    var upd = window.WH_EVENTS && window.WH_EVENTS.updated;
    if (upd) $('#updated').textContent = 'Calendario aggiornato al ' + fmt(new Date(upd + 'T12:00:00Z'), { day: 'numeric', month: 'long', year: 'numeric' });

    function eventCard(ev) {
      var d = eventDate(ev);
      var where = [ev.venue, ev.city, ev.country].filter(Boolean).join(', ');
      var time = ev.startUtc ? 'ore ' + fmt(d, { hour: '2-digit', minute: '2-digit' }) + ' (ora italiana)' : '<span class="badge-tbc">Da confermare</span>';
      if (ev.dateConfirmed === false) time = '<span class="badge-tbc">Data non ufficiale</span>';
      return '<article class="event ' + esc(ev.promotion) + '" id="' + esc(ev.id) + '">' +
        '<div class="datebox"><small>' + fmt(d, { weekday: 'short' }) + '</small><b>' + fmt(d, { day: 'numeric' }) + '</b><small>' + fmt(d, { month: 'short' }) + '</small></div>' +
        '<div><span class="tag ' + esc(ev.promotion) + '">' + esc(ev.promotion) + '</span><h3>' + esc(ev.name) + '</h3><div class="info">' +
        '<div><span>Dove</span>' + esc(where || 'Da annunciare') + '</div>' +
        '<div><span>Orario</span>' + time + '</div>' +
        '<div><span>In TV / streaming in Italia</span>' + esc(ev.broadcastIT || 'Da confermare') + '</div></div>' +
        (ev.note ? '<div class="note">' + esc(ev.note) + '</div>' : '') + '</div>' +
        '<div class="actions">' +
        (eventPage(ev) ? '<a class="btn" href="' + eventPage(ev) + '">Scheda evento e card →</a>' : '') +
        (ev.tickets ? '<a class="btn primary" target="_blank" rel="noopener" href="' + esc(ev.tickets) + '">🎟 Acquista biglietti</a>' : '<span class="btn" style="opacity:.6;cursor:default">Biglietti non ancora disponibili</span>') +
        (ev.watchUrl ? '<a class="btn" target="_blank" rel="noopener" href="' + esc(ev.watchUrl) + '">📺 Dove vederlo</a>' : '') +
        '<a class="btn sm" target="_blank" rel="noopener" href="' + gcalLink(ev) + '">+ Google Calendar</a>' +
        '</div></article>';
    }

    function draw() {
      document.querySelectorAll('#filters .chip').forEach(function (c) { c.classList.toggle('on', c.dataset.promo === state.promo); });
      var list = all.filter(function (e) { return state.promo === 'Tutte' || e.promotion === state.promo; });
      var groups = {}, order = [];
      list.forEach(function (ev) {
        var k = cap(fmt(eventDate(ev), { month: 'long', year: 'numeric' }));
        if (!groups[k]) { groups[k] = []; order.push(k); }
        groups[k].push(ev);
      });
      $('#calendar').innerHTML = order.map(function (k, i) {
        return '<section class="month"><h2>' + k + '</h2>' + groups[k].map(eventCard).join('') + '</section>' +
          (i % 2 === 0 && i < order.length - 1 ? adSlot('calendar') : '');
      }).join('') || '<div class="empty">Nessun evento in programma.</div>';
      fillAds();
      if (location.hash) { var t = document.getElementById(location.hash.slice(1)); if (t) t.scrollIntoView(); }
    }
    draw();

    var weekly = (window.WH_EVENTS && window.WH_EVENTS.weekly) || [];
    $('#weekly').innerHTML = '<thead><tr><th>Show</th><th>Federazione</th><th>Giorno</th><th>Ora italiana</th><th>Dove vederlo</th></tr></thead><tbody>' +
      weekly.map(function (w) {
        return '<tr><td><b>' + esc(w.show) + '</b>' + (w.note ? '<br><small style="color:var(--muted)">' + esc(w.note) + '</small>' : '') + '</td><td>' + esc(w.promotion) + '</td><td>' + esc(w.day) +
          '</td><td>' + esc(w.timeIT || '—') + '</td><td>' + esc(w.broadcastIT) + '</td></tr>';
      }).join('') + '</tbody>';
  }

  // ---------- fonti ----------
  function renderSources() {
    var src = (window.WH_SOURCES || []).filter(function (s) { return s.enabled; });
    var counts = {};
    ((window.WH_NEWS || {}).items || []).forEach(function (n) { counts[n.source] = (counts[n.source] || 0) + 1; });
    $('#sources').innerHTML = src.map(function (s) {
      return '<div class="source"><b>' + esc(s.name) + '</b> <span class="lang">' + esc(s.lang.toUpperCase()) + '</span><br>' +
        '<a href="' + esc(s.site) + '" target="_blank" rel="noopener">' + esc(s.site.replace(/^https?:\/\//, '')) + '</a>' +
        '<div style="color:var(--muted);font-size:13px;margin-top:4px">' + (counts[s.name] || 0) + ' notizie in archivio</div></div>';
    }).join('');
  }

  // ---------- wrestling italiano ----------
  function linkBtn(url, label) {
    return url ? '<a class="btn sm" target="_blank" rel="noopener" href="' + esc(url) + '">' + label + '</a>' : '';
  }
  function list(arr) { return (arr || []).map(esc).join(', '); }

  function renderItalia() {
    var it = window.WH_ITALIA || {};
    $('#it-intro').textContent = it.intro || '';

    $('#companies').innerHTML = (it.companies || []).map(function (c) {
      var l = c.links || {};
      var rows = [
        ['Fondazione', [c.founded, c.founders ? 'da ' + c.founders : ''].filter(Boolean).join(' · ')],
        ['Sede', c.city],
        ['Titoli', list(c.championships)],
        ['Scuola', c.school],
        ['Eventi chiave', list(c.events)],
        ['Passati da qui', list(c.alumni)]
      ].filter(function (r) { return r[1]; });
      var milestones = (c.milestones || []).length
        ? '<details><summary>Tappe principali</summary><ul>' + c.milestones.map(function (m) {
            return '<li><b>' + esc(m.year) + '</b> — ' + esc(m.text) + '</li>';
          }).join('') + '</ul></details>' : '';
      return '<article class="company" id="' + esc(c.id) + '" style="--c:' + esc(c.color || '') + '">' +
        '<header><div class="mono">' + esc(c.acronym || c.name.slice(0, 3)) + '</div><div><h3>' + esc(c.name) +
        '<span class="status ' + (c.active ? 'on' : 'off') + '">' + (c.active ? 'Attiva' : 'Non attiva') + '</span></h3>' +
        '<div class="sub">' + esc([c.city, c.founded ? 'dal ' + c.founded : ''].filter(Boolean).join(' · ')) + '</div></div></header>' +
        '<p>' + esc(c.description) + '</p>' +
        '<dl>' + rows.map(function (r) { return '<dt>' + r[0] + '</dt><dd>' + esc(r[1]) + '</dd>'; }).join('') + '</dl>' +
        milestones +
        '<div class="links">' + linkBtn(l.site, 'Sito ufficiale') + linkBtn(l.facebook, 'Facebook') + linkBtn(l.instagram, 'Instagram') +
        linkBtn(l.youtube, 'YouTube') + linkBtn(l.tickets, '🎟 Biglietti') + '</div></article>';
    }).join('');

    $('#timeline').innerHTML = (it.timeline || []).map(function (t) {
      return '<li><div class="y">' + esc(t.year) + '</div><h4>' + esc(t.title) + '</h4><p>' + esc(t.text) + '</p></li>';
    }).join('');

    $('#articles').innerHTML = (it.articles || []).map(function (a) {
      return '<a class="article-card" href="#art-' + esc(a.id) + '"><span class="kick">' + esc(a.kicker || 'Approfondimento') + '</span>' +
        '<h3>' + esc(a.title) + '</h3><p>' + esc(a.lede) + '</p><span class="read">Leggi · ' + (a.minutes || 4) + ' min →</span></a>';
    }).join('');

    // notizie che parlano di wrestling italiano
    var re = it.newsPattern ? new RegExp(it.newsPattern, 'i') : null;
    var items = ((window.WH_NEWS || {}).items || []).filter(function (n) { return re && re.test(n.title + ' ' + n.excerpt); }).slice(0, 12);
    $('#it-news').innerHTML = items.map(function (n) { return newsCard(n, false); }).join('') ||
      '<div class="empty">Nessuna notizia recente sulle federazioni italiane.</div>';

    var baseTitle = document.title;
    function showArticle() {
      var m = location.hash.match(/^#art-(.+)$/);
      var a = m && (it.articles || []).filter(function (x) { return x.id === m[1]; })[0];
      $('#reader').hidden = !a;
      $('#italia-home').hidden = !!a;
      if (!a) { $('#reader').innerHTML = ''; document.title = baseTitle; return; }
      var body = (a.body || []).map(function (b) {
        return typeof b === 'string' ? '<p>' + esc(b) + '</p>' : '<h2>' + esc(b.h) + '</h2>';
      }).join('');
      var facts = (a.facts || []).length ? '<aside class="facts"><h3>In breve</h3><ul>' + a.facts.map(function (f) { return '<li>' + esc(f) + '</li>'; }).join('') + '</ul></aside>' : '';
      var src = (a.sources || []).length ? '<div class="sources">Fonti: ' + a.sources.map(function (s) {
        return '<a href="' + esc(s) + '" target="_blank" rel="noopener">' + esc(s.replace(/^https?:\/\/(www\.)?/, '').split('/')[0]) + '</a>';
      }).join(' · ') + '</div>' : '';
      $('#reader').innerHTML = '<a class="btn sm back" href="#approfondimenti">← Wrestling italiano</a>' +
        '<div class="kick">' + esc(a.kicker || 'Approfondimento') + '</div><h1>' + esc(a.title) + '</h1>' +
        '<p class="lede">' + esc(a.lede) + '</p><div class="byline">Redazione WrestlingHub Italia · ' + (a.minutes || 4) + ' min di lettura</div>' +
        body + facts + adSlot('calendar') + src;
      document.title = a.title + ' | WrestlingHub Italia';
      window.scrollTo(0, 0);
      fillAds();
    }
    window.addEventListener('hashchange', showArticle);
    showArticle();
  }

  chrome();
  if (page === 'home') renderHome();
  if (page === 'calendario') renderCalendar();
  if (page === 'italia') renderItalia();
  if (page === 'fonti') renderSources();
  fillAds();
})();
