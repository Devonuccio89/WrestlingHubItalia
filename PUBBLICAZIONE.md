# Pubblicare WrestlingHub Italia su wrestlinghubitalia.com

**Come funziona, in breve**
- **GitHub** conserva i file del sito e ogni 30 minuti aggiorna le notizie in automatico.
- **Cloudflare Pages** mette il sito online, gratis e senza limiti di traffico.
- **Cloudflare Registrar** è dove comprare il dominio.

Tempo richiesto: circa un'ora la prima volta. Poi non devi più fare nulla.

| Cosa | Costo |
|---|---|
| GitHub (repository pubblico) | Gratis |
| Cloudflare Pages | Gratis |
| Dominio wrestlinghubitalia.com | Circa 10–11 $/anno su Cloudflare (prezzo di costo) |
| Email info@wrestlinghubitalia.com (inoltro a Gmail) | Gratis |

---

## Passo 0: metti il progetto in una cartella stabile

Oggi i file sono in una cartella temporanea creata per questa sessione. Prima di tutto chiedi a Claude di spostare la sessione in una cartella tua, per esempio `Documenti\WrestlingHubItalia`.

## Passo 1: account Cloudflare e dominio

1. Crea un account gratuito su **dash.cloudflare.com/sign-up**.
2. Nel menu a sinistra apri **Domain Registration → Register Domains**, cerca `wrestlinghubitalia.com` e acquistalo.
   - *Hai già comprato il dominio altrove?* Vai su **Add a domain** e segui la procedura. Alla fine Cloudflare ti indica due *nameserver* da impostare dal tuo registrar, cioè dove hai comprato il dominio.
3. Annota il tuo **Account ID**. Lo trovi in **Workers & Pages**, nella colonna di destra della pagina, oppure nell'indirizzo del browser: è la lunga sequenza di lettere e numeri dopo `dash.cloudflare.com/`.

## Passo 2: crea il token per la pubblicazione

Serve a GitHub per pubblicare il sito sul tuo account Cloudflare.

1. In alto a destra apri **icona profilo → My Profile → API Tokens → Create Token**.
2. Scegli **Create Custom Token** e compila così:
   - **Token name:** `GitHub WrestlingHub`
   - **Permissions:** `Account` · `Cloudflare Pages` · `Edit`
3. Clicca **Continue to summary → Create Token**.
4. **Copia il token e tienilo da parte**: Cloudflare te lo mostra una sola volta.

## Passo 3: account GitHub e caricamento dei file

1. Crea un account gratuito su **github.com/signup**.
2. Installa **GitHub Desktop** da **desktop.github.com** ed entra con il tuo account.
3. In GitHub Desktop: **File → Add local repository…** e scegli la cartella del progetto.
   - Ti dirà che non è ancora un repository: clicca **create a repository**, poi **Create repository**.
4. Clicca **Publish repository**:
   - Nome: `wrestlinghubitalia`
   - **Togli la spunta da "Keep this code private"**. Con un repository pubblico i minuti di automazione sono illimitati. Con uno privato il piano gratuito non basta per un aggiornamento ogni 30 minuti: in quel caso chiedi a Claude di passare a un aggiornamento all'ora.

## Passo 4: dai a GitHub le chiavi di Cloudflare

1. Su github.com apri il repository `wrestlinghubitalia`, poi **Settings → Secrets and variables → Actions**.
2. Clicca **New repository secret** due volte e crea:

| Name | Secret |
|---|---|
| `CLOUDFLARE_API_TOKEN` | il token del passo 2 |
| `CLOUDFLARE_ACCOUNT_ID` | l'Account ID del passo 1 |

## Passo 5: prima pubblicazione

1. Nel repository apri la scheda **Actions**. Se te lo chiede, clicca **I understand my workflows, go ahead and enable them**.
2. A sinistra scegli **Aggiorna e pubblica**, poi **Run workflow → Run workflow**.
3. Dopo 1–2 minuti il pallino diventa verde ✅. Il sito è online all'indirizzo provvisorio **https://wrestlinghubitalia.pages.dev**.

Se il pallino diventa rosso ❌, apri l'esecuzione, copia il messaggio di errore e incollalo a Claude.

## Passo 6: collega il dominio

1. Su Cloudflare apri **Workers & Pages → wrestlinghubitalia → Custom domains → Set up a custom domain**.
2. Aggiungi `wrestlinghubitalia.com` e conferma.
3. Ripeti con `www.wrestlinghubitalia.com`.
4. Dopo qualche minuto, a volte fino a un'ora, il sito risponde su **https://wrestlinghubitalia.com**, con il lucchetto HTTPS già attivo.

## Passo 7: email info@wrestlinghubitalia.com

1. Su Cloudflare apri il dominio, poi **Email → Email Routing → Get started**.
2. Crea l'indirizzo `info` e fallo inoltrare alla tua Gmail.

---

## Dopo la pubblicazione

- **Google Search Console** (search.google.com/search-console): aggiungi il sito e invia la sitemap `https://wrestlinghubitalia.com/sitemap.xml`. Così Google trova subito tutte le pagine.
- **Google AdSense**: aspetta una o due settimane perché Google indicizzi il sito, poi fai domanda. Una volta approvato, comunica a Claude il tuo ID editore (`ca-pub-…`): lo inserirà in `assets/ads-config.js` e `ads.txt`.
- **Banner cookie**: in AdSense attiva **Privacy e messaggi → GDPR** (è gratuito). Completa anche l'informativa in `privacy.html` con i dati del titolare.

## Come si lavora dopo

- **Notizie:** si aggiornano da sole ogni 30 minuti. Non devi fare nulla.
- **Nuovi contenuti** (articoli, eventi, fonti, correzioni): chiedili a Claude, che modifica i file nella cartella del progetto. Poi apri **GitHub Desktop**: vedrai le modifiche, scrivi una breve descrizione, clicca **Commit to main** e poi **Push origin**. In 1–2 minuti sono online.
  - Prima di iniziare a lavorare clicca **Fetch origin** (e **Pull** se compare): così hai le ultime notizie scaricate dall'automazione e non ci sono conflitti.
- **Per non fare nemmeno questo passaggio:** installa Git per Windows e Claude potrà pubblicare direttamente le modifiche che ti prepara.
