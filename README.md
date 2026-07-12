# Simple Template

## Quick start

1. Press **Use this template → Create a new repository**.
2. Name the repository `your-username.github.io`.
3. Edit `config.yml` with identity, contacts, URL, and profiles.
4. Edit `data/locales/en.yml` (and `data/locales/it.yml`) to change every visible label, the navigation, and the "About" text.
5. Run `ruby scripts/sync_repository.rb` to update the license, security policy, robots, and repository links.
6. In `data/locales/<language>.yml`, inside `navigation.main`, choose which sections to show.
7. In **Settings → Pages → Source** select **GitHub Actions**.

## Where to customize

| Element | File/folder |
|---|---|
| Name, email, socials, SEO, color, and active languages | `config.yml` |
| Labels, menu, and "About" text for each language | `data/locales/en.yml`, `data/locales/it.yml` |
| All projects and articles | `entries/*.md` |
| Project/article list rows | `includes/work-entry.html`, `includes/writing-entry.html` |
| Header and footer | `includes/site-header.html`, `includes/site-footer.html` |
| Overall structure | `layouts/site.html` |
| Case studies and articles | `layouts/case-study.html`, `layouts/article.html` |
| Style and responsiveness | `css/style.css` |
| Photos, previews, and attachments | `images/` and `files/` |

## Multi-language

The site supports multiple languages with separate URLs: English stays at the root (`/`, `/work/`, etc.) while other languages live under a subfolder (e.g. `/it/`, `/it/work/`). The default language and the available ones are configured in `config.yml`:

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

- **Labels and fixed text**: one file per language in `data/locales/<code>.yml` (navigation, "About" text, button labels, etc.).
- **Section pages**: the default language uses the root pages (`index.html`, `work.html`, `writing.html`, `archive.html`, `about.html`). Every other language has its own pages in a `<code>/` folder (e.g. `it/index.html`) with the same Liquid content but `lang: <code>` and `permalink: /<code>/...` in the front matter.
- **Projects and articles**: every file in `entries/` has a `lang` field (e.g. `lang: en`, `lang: it`) and a `slug` shared between translations of the same content. A translation in a non-default language is named `file-name.<code>.md` and has an explicit `permalink`, e.g.:

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

If a piece of content has no translation in a given language, it simply doesn't appear in that language's lists. The language switch button in the header links to the exact translation of the page if it exists (same `slug`), otherwise to that language's home page.

To add a third language: add the entry to `languages.available`, create `data/locales/<code>.yml`, create the pages `<code>/index.html`, `<code>/about.html`, `<code>/work.html`, `<code>/writing.html`, `<code>/archive.html` by copying the existing ones, and add a `<code>.md` file for every translated piece of content in `entries/`.

## Adding projects and articles

Everything lives in a single folder: `entries/`.

- For a project, copy `content-templates/project.md` into `entries/`.
- For an article, copy `content-templates/article.md` into `entries/`.
- Rename the copy, ending the name with `.md`.
- Fill in the initial fields and write the content in Markdown.
- `entries/` is not a Jekyll collection: every file is a regular page, so `permalink` must always be set explicitly.

Project:

```yaml
---
title: "Project title"
type: project
layout: case-study
lang: en
slug: project-slug
permalink: /entries/project-slug/
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

The `date` field automatically sets the position on the home page and list pages.

### Editor tool

`tools/write.html` is a standalone page (not part of the built site) that generates these files for you: pick type and language, fill in the fields, write the body with a markdown toolbar, then download the ready-to-use `.md` file and drop it into `entries/`. Open it directly in a browser, no build step required.

## Adding an article

Create or copy a file into `entries/`:

```yaml
---
title: "Article title"
type: article
layout: article
lang: en
slug: article-slug
permalink: /entries/article-slug/
date: 2025-01-15
category: "Artificial Intelligence"
read_time: 6
excerpt: "Short abstract."
---
```

The home page automatically mixes articles and projects in chronological order. `/work/` shows only the projects, `/writing/` shows only the articles, and `/archive/` groups the articles by year.

## Local preview

Requires Ruby and Bundler:

```bash
bundle install
bundle exec jekyll serve --config config.yml
```

Open `http://localhost:4000`. Alternatively, edit files directly on GitHub and let Actions run the build.

## Syncing repository files

Jekyll doesn't process files like `LICENSE` and `SECURITY.md`. After changing the name, email, URL, or repository in `config.yml`, run:

```bash
ruby scripts/sync_repository.rb
```

To check without modifying files:

```bash
ruby scripts/sync_repository.rb --check
```

## Custom domain

Rename `CNAME.example` to `CNAME`, enter the domain, and configure it in **Settings → Pages** too. Update `url` and `baseurl` in `config.yml`.

## Before publishing

- [ ] Replace all example values in `config.yml`.
- [ ] Update `repository`, `url`, and `baseurl`.
- [ ] Replace the photo, CV, and example content.
- [ ] Update `robots.txt`, `SECURITY.md`, `LICENSE`, and the links in `.github/`.
- [ ] Remove the collections and pages you don't want to use.
- [ ] Check the result on desktop and mobile.

## License

MIT. See `LICENSE`.
