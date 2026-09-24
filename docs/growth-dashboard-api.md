# API ADURA Growth Dashboard

Cette API est exclusivement en lecture seule et destinée à un outil serveur à
serveur, tel qu’un Custom GPT ADURA Growth Analyst.

## Endpoint et authentification

`GET /api/v1/growth/dashboard`

Configurez une valeur forte dans `ADURA_GROWTH_API_TOKEN`, puis transmettez-la
dans l’en-tête `Authorization: Bearer <token>`. L’API renvoie `401` pour un
jeton absent, mal formé ou incorrect et ne journalise jamais sa valeur.

```bash
curl --fail-with-body \
  -H "Authorization: Bearer $ADURA_GROWTH_API_TOKEN" \
  "https://adura.store/api/v1/growth/dashboard?period=7d"
```

Les seules périodes autorisées sont `today`, `7d` (valeur par défaut) et
`30d`. Une autre valeur renvoie `400 {"error":"invalid_period"}`.

## Réponse

La réponse contient `meta`, `business`, `ga4`, `funnel`, `products`,
`traffic_sources`, `landing_pages` et `insights`.

- `business` est la source officielle : agrégats issus de la base ADURA.
- `ga4` est comportemental et dépend du consentement Analytics. Son revenu ne
  doit jamais être interprété comme le revenu comptable officiel.
- Le statut `ga4_status: "stale"` et `ga4_fallback: true` signalent l’emploi de
  la dernière réponse GA4 valide après une indisponibilité récupérable.
- `ga4_advanced_status: "partial"` signale qu'un sous-rapport avancé est
  indisponible, sans masquer les autres blocs compatibles.

Aucune information cliente, commande individuelle, donnée Stripe, adresse,
IP, cookie ou secret n’est incluse.

## Cache et limites

L’API réutilise exactement le cache du dashboard admin : 15 minutes pour
`today`, 1 heure pour `7d`, 3 heures pour `30d`, avec un dernier résultat GA4
valide conservé 24 heures. Elle ne met pas de CORS permissif : une Action GPT
effectue un appel serveur à serveur, donc aucun navigateur n’en a besoin.

L’application ne possède pas actuellement Rack::Attack ou une limite dédiée.
Avant de distribuer le token à plusieurs consommateurs, appliquez une limite
réseau ou applicative par token/IP (par exemple 60 requêtes par heure).

Le schéma OpenAPI complet est dans `docs/openapi/growth-dashboard.yaml`.
