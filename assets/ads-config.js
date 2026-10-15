/* Configurazione Google AdSense.
   Finché "client" è vuoto il sito mostra solo riquadri segnaposto "Spazio pubblicitario".
   Dopo l'approvazione AdSense: inserisci il tuo ID editore (ca-pub-...) e gli ID delle unità
   annuncio create in AdSense > Annunci > Per unità annuncio. Ricorda di aggiornare anche ads.txt. */
window.WH_ADS = {
  client: '',            // es. 'ca-pub-1234567890123456'
  slots: {
    top: '',             // banner orizzontale sotto l'header (tutte le pagine)
    infeed: '',          // annuncio tra le notizie
    sidebar: '',         // rettangolo nella colonna laterale (resta visibile scorrendo)
    calendar: '',        // annuncio tra i mesi del calendario
    article: ''          // annuncio a metà articolo nelle guide
  },
  infeedEvery: 8         // un annuncio ogni N notizie
};
