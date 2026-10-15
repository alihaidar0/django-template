# API conventions (defaults)

Short defaults for a project's HTTP API. They keep the contract (`openapi/schema.yaml`)
consistent from the first endpoint; a project may change any of them, but should decide once and
apply it everywhere. Rules that depend on the project (money and currency formats, identifiers,
authentication, domain naming) are **not** here: each project adds its own to this file.

## Versioning

Version in the path: `/api/v1/...`. A breaking change gets a new version (`/api/v2/...`) next to
the old one (see `docs/api-workflow.md`). The `SCHEMA_PATH_PREFIX` setting already keeps the
version out of operation ids and tags.

## One error body

Use the same body for every error, so a client has a single error parser. Recommended shape:
RFC 9457 problem details (`application/problem+json`), which obsoletes RFC 7807:

```json
{
  "type": "https://example.com/problems/validation-error",
  "title": "Invalid input",
  "status": 400,
  "detail": "One or more fields are invalid.",
  "errors": { "email": ["Enter a valid email address."] }
}
```

The template does **not** ship this handler: it is a convention the project implements before a client
relies on it. Implement it once in a DRF exception handler (`REST_FRAMEWORK["EXCEPTION_HANDLER"]`) and describe
it in the schema, so generated clients know the type. Validation errors keep field names as keys
under `errors`.

## Pagination

Every list endpoint is paginated: the same class everywhere (`DEFAULT_PAGINATION_CLASS` and
`PAGE_SIZE` in `REST_FRAMEWORK`), the same response envelope, and a documented maximum page size.
Prefer cursor pagination for large or fast-changing lists, page-number pagination for small, stable ones.

## Timestamps

UTC, ISO 8601, with an explicit offset: `2026-01-31T14:05:09Z`. Keep `USE_TZ = True`; a client
converts to the user's time zone for display only. Dates without a time are `YYYY-MM-DD`.

## Also

- Field and query-parameter names are `snake_case`.
- Use HTTP status codes for the outcome (`201` created, `204` no content, `400` invalid, `401`/`403`
  not authenticated/allowed, `404` not found, `409` conflict) and keep them in the schema.
- An empty list is `200` with an empty `results`, never `404`.
