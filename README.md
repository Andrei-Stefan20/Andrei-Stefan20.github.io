# Quaderno Portfolio Template

A lightweight bilingual portfolio built with Jekyll and GitHub Pages.

## Quick start

1. Select **Use this template → Create a new repository**.
2. Name the repository `your-username.github.io`.
3. Update `config.yml` with your identity, contact details, URL, profiles, and appearance settings.
4. Edit `data/locales/en.yml` and the other locale files to change navigation labels and visible copy.
5. In **Settings → Pages → Source**, select **GitHub Actions**.
6. Run `ruby scripts/sync_repository.rb` after changing repository-level metadata.

## Repository structure

```text
entries/
├── projects/
│   └── project-slug/
│       ├── en.md
│       └── it.md
└── articles/
    └── article-slug/
        ├── en.md
        └── it.md

images/
├── projects/
│   └── project-slug/
└── articles/
    └── article-slug/
```

Each project or article has its own folder. Translations live together inside that folder and use the language code as the filename.

Examples:

```text
entries/projects/resnet-vit-distillation/en.md
entries/projects/resnet-vit-distillation/it.md
images/projects/resnet-vit/
```

```text
entries/articles/llm-memory/en.md
entries/articles/llm-memory/it.md
images/articles/llm-memory/
```

The public URL is controlled by the `permalink` field, so moving a Markdown file inside `entries/` does not change the published page URL.

## Main files

| Purpose | File or folder |
|---|---|
| Identity, profiles, SEO, appearance, languages | `config.yml` |
| Localized labels and About text | `data/locales/<language>.yml` |
| Projects | `entries/projects/<project-slug>/<language>.md` |
| Articles | `entries/articles/<article-slug>/<language>.md` |
| Project images | `images/projects/<project-slug>/` |
| Article images | `images/articles/<article-slug>/` |
| Project and article templates | `content-templates/` |
| Page layouts | `layouts/` |
| Reusable list components | `includes/` |
| Site styles | `css/` |
| Static tools | `tools/` |

## Adding a project

Create a folder using the project slug:

```text
entries/projects/my-project/
```

Then add one Markdown file per language:

```text
entries/projects/my-project/en.md
entries/projects/my-project/it.md
```

English example:

```yaml
---
title: "Project title"
type: project
layout: case-study
lang: en
slug: my-project
permalink: /entries/my-project/
date: 2026-01-15
year: 2026
image: "/images/projects/my-project/cover.png"
thumbnail: "/images/projects/my-project/thumbnail.png"
cover: "/images/projects/my-project/cover.png"
show_cover: true
cover_alt: "Project architecture"
thumbnail_alt: "Project preview"
role: "Full-Stack Development"
technologies: [Python, FastAPI, React]
code: "https://github.com/username/project"
demo: ""
paper: ""
excerpt: "A concise description shown on the home page and project lists."
---
```

Italian translation:

```yaml
---
title: "Titolo del progetto"
type: project
layout: case-study
lang: it
slug: my-project
permalink: /it/entries/my-project/
...
---
```

Translations must share the same `slug`.

## Adding an article

Create a folder using the article slug:

```text
entries/articles/my-article/
```

Then create the language files:

```text
entries/articles/my-article/en.md
entries/articles/my-article/it.md
```

Example:

```yaml
---
title: "Article title"
type: article
layout: article
lang: en
slug: my-article
permalink: /entries/my-article/
date: 2026-01-15
category: "Artificial Intelligence"
read_time: 6
image: "/images/articles/my-article/cover.png"
thumbnail: "/images/articles/my-article/thumbnail.png"
cover: "/images/articles/my-article/cover.png"
show_cover: true
excerpt: "A short abstract shown in lists and social previews."
---
```

## Images and covers

The image fields are optional and use automatic fallbacks:

- `thumbnail` is used in home and archive cards;
- if `thumbnail` is missing, the site uses `image`;
- if `image` is also missing, it uses `cover`;
- `cover` is used inside the project or article page;
- if `cover` is missing, the page uses `image`;
- set `show_cover: false` to keep the thumbnail while hiding the cover inside the page.

Keep assets grouped by content slug:

```text
images/projects/my-project/
images/articles/my-article/
```

## Optional project links

Project buttons are generated from these front-matter fields:

```yaml
code: "https://github.com/username/project"
demo: "https://example.com"
paper: "/files/paper.pdf"
```

A button is shown only when its value is present and not empty.

## Multi-language behavior

English is served from the root. Other languages use a language prefix such as `/it/`.

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

The language switcher finds translations by matching the shared `slug`. When no translation exists, it links to the selected language's home page.

## Automatic lists

The site discovers project and article pages recursively through Jekyll's `site.pages`, so nested files inside `entries/projects/` and `entries/articles/` are included automatically.

- the home page mixes projects and articles by date;
- `/work/` shows projects;
- `/writing/` shows articles;
- `/archive/` groups content by year;
- navigation sections are hidden when they have no content for the active language.

## Local preview

```bash
bundle install
bundle exec jekyll serve --config config.yml
```

Open `http://localhost:4000`.

To build search locally:

```bash
bundle exec jekyll build --config config.yml
npx pagefind --site _site
cd _site && python3 -m http.server 4000
```

## Repository synchronization

After changing the repository name, URL, owner, or contact details, run:

```bash
ruby scripts/sync_repository.rb
```

Check without writing changes:

```bash
ruby scripts/sync_repository.rb --check
```

## Comments

Comments use Giscus and GitHub Discussions. Enable them in `config.yml`:

```yaml
discussions:
  enabled: true
  repo: "username/username.github.io"
  repo_id: "..."
  category: "Announcements"
  category_id: "..."
```

## Analytics

Plausible is optional:

```yaml
analytics:
  plausible_domain: "yourdomain.com"
```

Leave the value empty to disable it.

## Before publishing

- replace the example values in `config.yml`;
- verify `repository`, `url`, and `baseurl`;
- replace the profile image, CV, and example content;
- add project and article assets to their matching image folders;
- test both desktop and mobile layouts;
- check every active language;
- verify the GitHub Pages workflow.

## License

MIT. See `LICENSE`.
