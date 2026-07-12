# Simple Template

## Avvio rapido

1. Premi **Use this template → Create a new repository**.
2. Nomina la repository `tuo-username.github.io`.
3. Modifica `_config.yml` con identità, contatti, URL e profili.
4. Modifica `data/locales/en.yml` (e `data/locales/it.yml`) per cambiare ogni etichetta visibile, la navigazione e il testo "About".
5. Esegui `ruby scripts/sync_repository.rb` per aggiornare licenza, sicurezza, robots e link della repository.
6. In `data/locales/<lingua>.yml`, dentro `navigation.main`, scegli quali sezioni mostrare.
7. In **Settings → Pages → Source** seleziona **GitHub Actions**.

## Dove si personalizza

| Elemento | File/cartella |
|---|---|
| Nome, email, social, SEO, colore e lingue attive | `_config.yml` |
| Etichette, menu e testo "About" per ogni lingua | `data/locales/en.yml`, `data/locales/it.yml` |
| Tutti i progetti e articoli | `_entries/*.md` |
| Righe progetto/articolo | `includes/work-entry.html`, `includes/writing-entry.html` |
| Header e footer | `includes/site-header.html`, `includes/site-footer.html` |
| Struttura generale | `layouts/site.html` |
| Case study e articoli | `layouts/case-study.html`, `layouts/article.html` |
| Stile e responsive | `css/style.css` |
| Foto, anteprime e allegati | `images/` e `files/` |

## Multi-lingua

Il sito supporta più lingue con URL separati: l'inglese resta sulla root (`/`, `/work/`, ecc.) mentre le altre lingue vivono in una sottocartella (es. `/it/`, `/it/work/`). La lingua di default e quelle disponibili si configurano in `_config.yml`:

```yaml
languages:
  default: en
  available:
    - code: en
      label: "EN"
      home_url: "/"
    - code: it
      label: "IT"
      home_url: "/it/"
```

- **Etichette e testi fissi**: un file per lingua in `data/locales/<codice>.yml` (navigazione, testo "About", etichette dei bottoni, ecc.).
- **Pagine di sezione**: la lingua di default usa le pagine alla radice (`index.html`, `work.html`, `writing.html`, `archive.html`, `about.html`). Ogni altra lingua ha le sue pagine in una cartella `<codice>/` (es. `it/index.html`) con lo stesso contenuto Liquid ma `lang: <codice>` e `permalink: /<codice>/...` nel front matter.
- **Progetti e articoli**: ogni file in `_entries/` ha un campo `lang` (es. `lang: en`, `lang: it`) e uno `slug` condiviso tra le traduzioni dello stesso contenuto. La traduzione in una lingua diversa dal default si chiama `nome-file.<codice>.md` e ha un `permalink` esplicito, es.:

```yaml
---
type: project
layout: case-study
lang: it
slug: full-stack-project
permalink: /it/entries/full-stack-project/
title: "Titolo del progetto"
...
---
```

Se un contenuto non ha una traduzione in una lingua, semplicemente non compare nelle liste di quella lingua. Il pulsante di cambio lingua nell'header porta alla traduzione esatta della pagina se esiste (stesso `slug`), altrimenti alla home di quella lingua.

Per aggiungere una terza lingua: aggiungi la voce in `languages.available`, crea `data/locales/<codice>.yml`, crea le pagine `<codice>/index.html`, `<codice>/about.html`, `<codice>/work.html`, `<codice>/writing.html`, `<codice>/archive.html` copiando quelle esistenti, e aggiungi `<codice>.md` per ogni contenuto tradotto in `_entries/`.

## Aggiungere progetti e articoli

Tutto si trova in una sola cartella: `_entries/`.

- Per un progetto, copia `content-templates/project.md` dentro `_entries/`.
- Per un articolo, copia `content-templates/article.md` dentro `_entries/`.
- Rinomina la copia terminando il nome con `.md`.
- Compila i campi iniziali e scrivi il contenuto in Markdown.

Progetto:

```yaml
---
title: "Project title"
type: project
layout: case-study
lang: en
slug: project-slug
date: 2025-01-15
year: 2025
image: "/images/project.png"
role: "Full-Stack Development"
technologies: [Python, FastAPI, React]
code: "https://github.com/username/project"
demo: "https://example.com"
excerpt: "Short project summary."
---
```

La data stabilisce automaticamente la posizione nella home e nelle pagine elenco.

## Aggiungere un articolo

Crea o copia un file dentro `_entries/`:

```yaml
---
title: "Article title"
type: article
layout: article
lang: en
slug: article-slug
date: 2025-01-15
category: "Artificial Intelligence"
read_time: 6
excerpt: "Short abstract."
---
```

La home mescola automaticamente articoli e progetti in ordine cronologico. `/work/` mostra solo i progetti, `/writing/` mostra solo gli articoli e `/archive/` raggruppa gli articoli per anno.

## Anteprima locale

Richiede Ruby e Bundler:

```bash
bundle install
bundle exec jekyll serve
```

Apri `http://localhost:4000`. In alternativa puoi modificare i file direttamente su GitHub e lasciare che Actions esegua la build.

## Sincronizzare i file della repository

Jekyll non elabora file come `LICENSE` e `SECURITY.md`. Dopo aver cambiato nome, email, URL o repository in `_config.yml`, esegui:

```bash
ruby scripts/sync_repository.rb
```

Per verificare senza modificare file:

```bash
ruby scripts/sync_repository.rb --check
```

## Dominio personalizzato

Rinomina `CNAME.example` in `CNAME`, inserisci il dominio e configurarlo anche in **Settings → Pages**. Aggiorna `url` e `baseurl` in `_config.yml`.

## Prima della pubblicazione

- [ ] Sostituisci tutti i valori di esempio in `_config.yml`.
- [ ] Aggiorna `repository`, `url` e `baseurl`.
- [ ] Sostituisci foto, CV e contenuti di esempio.
- [ ] Aggiorna `robots.txt`, `SECURITY.md`, `LICENSE` e i link in `.github/`.
- [ ] Rimuovi le collezioni e pagine che non vuoi usare.
- [ ] Verifica il risultato su desktop e mobile.

## Licenza

MIT. Vedi `LICENSE`.
