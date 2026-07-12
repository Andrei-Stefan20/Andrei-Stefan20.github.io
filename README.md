# Minimal Academic Portfolio

Template Jekyll minimale per portfolio accademici e professionali, ispirato all'architettura modulare di Academic Pages ma con un'interfaccia più semplice.

## Avvio rapido

1. Premi **Use this template → Create a new repository**.
2. Nomina la repository `tuo-username.github.io`.
3. Modifica `_config.yml` con identità, contatti, URL e profili.
4. Modifica `_data/interface.yml` per cambiare ogni etichetta visibile.
5. Esegui `ruby scripts/sync_repository.rb` per aggiornare licenza, sicurezza, robots e link della repository.
6. Modifica `_data/navigation.yml` per scegliere le sezioni visibili.
7. In **Settings → Pages → Source** seleziona **GitHub Actions**.

## Dove si personalizza

| Elemento | File/cartella |
|---|---|
| Nome, bio, email, social, SEO e colore | `_config.yml` |
| Ogni titolo, pulsante ed etichetta | `_data/interface.yml` |
| Menu e ordine delle pagine | `_data/navigation.yml` |
| Tutti i progetti e articoli | `_entries/*.md` |
| Pubblicazioni | `_publications/*.md` |
| Talk | `_talks/*.md` |
| Insegnamento | `_teaching/*.md` |
| Righe progetto/articolo | `_includes/work-entry.html`, `_includes/writing-entry.html` |
| Header e footer | `_includes/site-header.html`, `_includes/site-footer.html` |
| Struttura generale | `_layouts/site.html` |
| Case study e articoli | `_layouts/case-study.html`, `_layouts/article.html` |
| Stile e responsive | `css/style.css` |
| Foto, anteprime e allegati | `images/` e `files/` |

Le sezioni Publications, Talks e Teaching sono già pronte ma nascoste. Per mostrarle, rimuovi `#` dalle relative righe in `_data/navigation.yml`.

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
