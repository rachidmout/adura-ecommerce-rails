# ADURA — Ruby on Rails e-commerce portfolio project

ADURA is a multilingual e-commerce application built with Ruby on Rails. This public repository is a portfolio snapshot of the Rails application; production credentials, commercial data and deployment configuration are deliberately excluded.

**Live website:** [adura.store](https://adura.store)

## What it demonstrates

- Product catalogue with variants, images and stock management
- Anonymous cart, guest checkout and promotional codes
- Stripe Checkout with webhook-based payment handling
- Deterministic perfume recommendation quiz
- Protected administration area for products, orders and fulfilment
- SEO pages, product redirects and sitemaps
- Background jobs and production-oriented operational tooling

## Tech stack

| Area | Technologies |
| --- | --- |
| Back end | Ruby 3.3, Ruby on Rails 8.1, Active Record |
| Database | PostgreSQL |
| Front end | Hotwire (Turbo + Stimulus), JavaScript, CSS |
| Payments | Stripe Checkout and webhooks |
| Media | Active Storage, Cloudinary-compatible storage |
| Quality | Minitest, RuboCop, Brakeman |
| Delivery | Docker, GitHub Actions |

## Run locally

### Prerequisites

- Ruby 3.3.5
- PostgreSQL 16+ (or Docker)
- Bundler

### Setup

```bash
git clone https://github.com/rachidmout/adura-ecommerce-rails.git
cd adura-ecommerce-rails
cp .env.example .env
bundle install
bin/rails db:prepare
bin/dev
```

The application will be available at [http://localhost:3000](http://localhost:3000).

To start PostgreSQL with Docker:

```bash
docker compose up -d db
bin/rails db:prepare
bin/dev
```

### Tests and checks

```bash
bin/rails test
bundle exec rubocop
bundle exec brakeman
```

## Configuration

Copy `.env.example` to `.env`. Stripe and other third-party integrations are optional for local exploration; keep real credentials out of Git.

The initial local administrator credentials are configured through `ADMIN_EMAIL` and `ADMIN_PASSWORD` in `.env.example`. Change them before sharing any local environment.

## Public repository scope

Product media and production credentials are intentionally excluded from this public snapshot. The repository is designed for reviewing the application architecture, domain modelling and delivery practices; the deployed product can be viewed at [adura.store](https://adura.store).

## Why this project matters to me

I built ADURA to work on the full life cycle of a production-oriented Rails application: domain modelling, product and order flows, third-party integrations, background jobs, deployment and troubleshooting. It is my main project for demonstrating practical full-stack development beyond isolated tutorials.

## Author

**Rachid Moutawakel** — Full-Stack Developer (Ruby on Rails)

- [LinkedIn](https://www.linkedin.com/in/rachid-moutawakel/)
- [GitHub profile](https://github.com/rachidmout)
