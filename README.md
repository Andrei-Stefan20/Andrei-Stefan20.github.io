# Quaderno Portfolio Template

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

The tools are static HTML pages: open `tools/write.html` to create content in `entries/` and `tools/configure.html` to edit `config.yml`. Choose the repository folder when prompted; no local server or Node.js is required.

### Configuration tool

The tools require the local server because a browser page cannot safely write files inside a GitHub repository by itself.

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

## Search

`/archive/` includes a built-in search box (via [Pagefind](https://pagefind.app)) and, when articles have different `category` values, a row of topic pills above it — click one to search by that topic. Pagefind indexes the site after every build; the GitHub Actions workflow (`.github/workflows/pages.yml`) already runs it for you. To test search locally:

```bash
bundle exec jekyll build --config config.yml
npx pagefind --site _site
cd _site && python3 -m http.server 4000
```

Navigation automatically hides "Projects" if there are no projects, and "Writing"/"Archive" if there are no articles (checked per language), so you never link to an empty section.

## Comments

Article and project pages can show [giscus](https://giscus.app) comments, backed by GitHub Discussions. Off by default. To enable:

1. Make sure the repository is public and has Discussions enabled.
2. Install the [giscus app](https://github.com/apps/giscus) on the repository and get your config values from [giscus.app](https://giscus.app).
3. In `config.yml`, set:

```yaml
discussions:
  enabled: true
  repo: "username/username.github.io"
  repo_id: "..."
  category: "Announcements"
  category_id: "..."
```

## Analytics

To add [Plausible Analytics](https://plausible.io), sign up and set your domain in `config.yml`:

```yaml
analytics:
  plausible_domain: "yourdomain.com"
```

Leave it blank to skip analytics entirely (nothing is loaded).

## SEO

- `hreflang` alternate tags are generated automatically for every language, so search engines know translated pages are equivalent.
- The social preview image (`og:image`) uses each entry's own `image` field, falling back to `logo` in `config.yml` when a page has none. Leave `image` out of an entry's front matter entirely (don't set it to `""`) if it has no picture.
- The favicon is `images/favicon.svg` — replace it with your own mark; it already adapts to light/dark browser themes.

## Before publishing

- [ ] Replace all example values in `config.yml`.
- [ ] Update `repository`, `url`, and `baseurl`.
- [ ] Replace the photo, CV, and example content.
- [ ] Update `robots.txt`, `SECURITY.md`, `LICENSE`, and the links in `.github/`.
- [ ] Remove the collections and pages you don't want to use.
- [ ] Replace `images/favicon.svg` with your own mark (optional).
- [ ] Set up comments and/or analytics if you want them (both optional, off by default).
- [ ] Check the result on desktop and mobile.

## License

MIT. See `LICENSE`.
