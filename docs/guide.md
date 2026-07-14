---
title: "Guida al template"
layout: article
lang: it
permalink: /guide/
date: 2026-07-14
category: "Documentazione"
excerpt: "Come modificare identità, contenuti, traduzioni e aspetto del sito, e come pubblicare gli aggiornamenti."
no_alternates: true
---

Ogni sezione del portfolio è guidata da file di testo e configurazione: per i lavori di routine non serve toccare codice. Questa pagina raccoglie le operazioni più comuni.

## Struttura del repository

Tutto quello che serve modificare abitualmente sta in quattro punti. Il resto (`_layouts/`, `_includes/`, `css/`, `js/`) è la meccanica del template e si tocca raramente.

| Cosa | Dove | Quando toccarlo |
|---|---|---|
| Identità, lingue, aspetto | `_config.yml` | Nome, ruolo, link social, colori |
| Contenuti | `entries/` | Un progetto o articolo, un file per lingua |
| Testi dell'interfaccia | `_data/locales/` | Etichette, intestazioni, messaggi |
| Immagini | `images/` | Copertine e miniature dei contenuti |

In locale, lancia `bundle exec jekyll serve` e apri `http://localhost:4000` per vedere ogni modifica prima di pubblicarla.

## Identità del sito

Nome, ruolo, link e descrizione vengono letti da `_config.yml` e appaiono nell'header, in home e nel footer.

```yaml
author:
  name: "Andrei Alexandru Stefan"
  role: "MSc in AI @ Uniba"
  education: "Full-Stack Developer"
  location: "Italy"
  email: ""
  github: "https://github.com/Andrei-Stefan20"
  linkedin: "https://linkedin.com/in/..."
  cv: "/files/cv.pdf"
```

Un campo lasciato vuoto (`""`) sparisce automaticamente dall'interfaccia: non serve commentare o cancellare righe, basta svuotarle.

![Home page con profilo, biografia e contenuti recenti](/docs/readme/guide/home.jpg)

## Aggiungere un progetto

Ogni progetto vive in `entries/projects/<slug>/`, con un file Markdown per lingua. Lo `slug` deve essere identico tra le lingue: è così che il cambio lingua trova la pagina corrispondente.

1. Crea `entries/projects/nome-progetto/en.md` e `it.md` (parti da `content-templates/project.md`).
2. Compila il front matter:

```yaml
---
title: "Project title"
type: project
layout: case-study
lang: en
slug: nome-progetto
permalink: /entries/nome-progetto/
date: 2026-01-15
role: "Machine Learning Engineering"
technologies: [Python, PyTorch]
thumbnail: "/images/projects/nome-progetto/thumb.png"
cover: "/images/projects/nome-progetto/cover.png"
code: "https://github.com/tuonome/repo"
excerpt: "Riassunto breve mostrato nelle liste."
---
```

3. Aggiungi copertina e miniatura in `images/projects/nome-progetto/` (stesso nome di cartella dello slug).
4. Verifica in locale: il progetto compare subito in Projects, in home tra i più recenti e in Archivio, senza altri file da aggiornare.

![Elenco progetti con miniature](/docs/readme/guide/work.jpg)

![Pagina di dettaglio di un progetto](/docs/readme/guide/case-study.jpg)

## Aggiungere un articolo

Stessa logica dei progetti, in `entries/articles/<slug>/`, con `layout: article` invece di `case-study` e un paio di campi editoriali in più.

```yaml
---
title: "Titolo dell'articolo"
type: article
layout: article
lang: it
slug: nome-articolo
permalink: /entries/nome-articolo/
date: 2026-01-15
category: "Knowledge Graphs"
read_time: 8
cover: "/images/articles/nome-articolo/cover.png"
excerpt: "Abstract breve per liste e social preview."
---
```

Il corpo va scritto in Markdown normale sotto il front matter — titoli, paragrafi, immagini inline con `![alt](/images/...)`.

![Elenco articoli con data, categoria e tempo di lettura](/docs/readme/guide/writing.jpg)

## Traduzioni e nuove lingue

Ogni etichetta dell'interfaccia (menu, pulsanti, intestazioni, messaggi vuoti) vive in `_data/locales/en.yml` e `it.yml`, mai scritta a mano dentro un template.

![Pagina archivio in inglese](/docs/readme/guide/archive-en.jpg)

![Pagina archivio in italiano](/docs/readme/guide/archive-it.jpg)

Per aggiungere una nuova lingua (es. spagnolo):

1. Copia `_data/locales/en.yml` in `_data/locales/es.yml` e traduci i valori.
2. Registra la lingua in `_config.yml` sotto `languages.available`.
3. Duplica le pagine di primo livello (`index.html`, `work.html`, ecc.) nella cartella `/es/`: front matter con `lang: es` e permalink, corpo ridotto a un solo {% raw %}`{% include page-*.html %}`{% endraw %} — il contenuto vero resta negli include condivisi.

Ogni progetto/articolo tradotto deve avere lo stesso `slug` nella nuova lingua: è la chiave che collega le versioni tra loro nel selettore lingua.

## Colore, sfondo e carattere

Tre opzioni visive si impostano da `_config.yml`, sotto `appearance:`, e diventano anche pulsanti che il visitatore può cambiare a piacere (la scelta resta salvata nel browser).

```yaml
appearance:
  accent_color: "#2b2b2b"
  background_pattern: "grid"   # none · grid · dots
  theme_mode: "auto"           # auto · light · dark
  font_style: "default"        # default · hand
```

![Sfondo con pattern a griglia](/docs/readme/guide/bg-grid.jpg)

![Sfondo con pattern a puntini](/docs/readme/guide/bg-dots.jpg)

## I tre pulsanti in alto a destra

Sfondo, carattere scritto a mano e tema chiaro/scuro sono tre pulsanti indipendenti in `_includes/site-header.html`. Ogni pulsante è autonomo: cancellandone il blocco, lo script collegato in `js/` smette semplicemente di fare nulla, non serve toccarlo.

- `.bg-toggle` — cicla none / grid / dots.
- `.font-toggle` — attiva/disattiva il carattere manoscritto.
- `.theme-toggle` — passa da chiaro a scuro.

![Menu di navigazione mobile aperto, con i tre pulsanti in fondo](/docs/readme/guide/mobile-menu.jpg)

Per **nascondere** uno o più pulsanti, apri `_includes/site-header.html` ed elimina il blocco corrispondente:

```html
<button type="button" class="bg-toggle" ...>
  ...
</button>

<button type="button" class="font-toggle" ...>
  ...
</button>

<button type="button" class="theme-toggle" ...>
  ...
</button>
```

Cancella uno dei tre blocchi `<button>...</button>` per rimuovere quel pulsante ovunque nel sito (desktop e mobile, perché l'header è un unico include condiviso).

Se rimuovi `theme-toggle`, il tema resta comunque scelto automaticamente in base al sistema operativo del visitatore grazie a `theme_mode: "auto"` — togliere il pulsante toglie solo la possibilità di cambiarlo a mano.

## Commenti e analytics

Entrambi sono spenti finché non compili la configurazione: nessuno script esterno viene caricato di default.

**Commenti (Giscus, via GitHub Discussions):**

```yaml
discussions:
  enabled: true
  repo: "tuonome/tuonome.github.io"
  repo_id: "..."
  category: "Announcements"
  category_id: "..."
```

I valori `repo_id` e `category_id` si ottengono dal generatore ufficiale su giscus.app dopo aver attivato Discussions sul repository.

**Analytics (Plausible):**

```yaml
analytics:
  plausible_domain: "tuosito.github.io"
```

Basta un dominio: se il campo resta vuoto, nessuno script di analytics viene incluso nella pagina.

## Validare e pubblicare

Prima di ogni push importante:

```bash
ruby scripts/validate_site.rb
bundle exec jekyll build
```

`validate_site.rb` controlla i campi obbligatori di `_config.yml`, il front matter di ogni contenuto, le lingue configurate, permalink duplicati e le immagini locali referenziate.

Ogni push su `main` avvia automaticamente la pipeline GitHub Actions: build Jekyll → indice di ricerca Pagefind → pubblicazione su GitHub Pages. Non serve alcun passaggio manuale.

## Mappa rapida dei file

| File / cartella | Contiene |
|---|---|
| `_config.yml` | Identità, lingue, aspetto, integrazioni |
| `_data/locales/*.yml` | Tutti i testi dell'interfaccia, per lingua |
| `entries/projects/<slug>/` | Un file `.md` per lingua, per progetto |
| `entries/articles/<slug>/` | Un file `.md` per lingua, per articolo |
| `images/projects/`, `images/articles/` | Copertine e miniature, raggruppate per slug |
| `content-templates/` | Front matter di partenza per nuovi contenuti |
| `_includes/site-header.html` | Menu, pulsanti aspetto, selettore lingua |
| `_includes/page-*.html` | Corpo condiviso delle pagine home/work/writing/about |
| `scripts/validate_site.rb` | Controllo automatico prima della pubblicazione |
