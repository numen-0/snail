# Static

A static-file handler for serving files from a directory.

It supports `GET` and `HEAD` requests, automatic `index.html` resolution, basic
*MIME* type detection, `ETag` caching, and custom `404` pages.

> [src](/src/handler/static.sh)

## Configuration

| Variable      | Default                  | Description                       |
|:-------------:|:------------------------:|:----------------------------------|
| `STATIC_ROOT` | `./data/static`          | Directory containing the files to serve |
| `STATIC_404`  | `./data/static/404.html` | Custom page served for `404 Not Found` responses |

## Routing

The requested URL is resolved relative to `STATIC_ROOT`.

A trailing `/` automatically resolves to `index.html`:

```text
GET /
    -> ./page/index.html

GET /about/
    -> ./page/about/index.html

GET /style.css
    -> ./page/style.css
```

Query parameters are ignored when resolving the file:

```text
GET /style.css?v=123
    -> ./page/style.css
```

> Paths containing `..` are rejected with `400 Bad Request`.

## API

### `GET`

Returns the requested file.

For example:

```sh
curl http://localhost:8080/index.html
```

Binary files can be downloaded directly:

```sh
curl -o image.png http://localhost:8080/image.png
```

### `HEAD`

Returns the same response headers as `GET` without the response body:

```sh
curl -I http://localhost:8080/index.html
```

### `404 Not Found`

If the requested file does not exist, the handler serves `STATIC_404` when
configured and the file exists.

Otherwise it returns the default `404 Not Found` response.

## Caching

Responses include an `ETag` generated from the served file.

Clients can use `If-None-Match` to validate their cached copy:

```sh
curl -i \
    -H 'If-None-Match: "..."' \
    http://localhost:8080/index.html
```

If the `ETag` matches, the handler returns:

```http
HTTP/1.1 304 Not Modified
```

## MIME Types

The handler determines the `Content-Type` from the file extension.

For example:

```text
.html  -> text/html
.css   -> text/css
.js    -> application/javascript
.png   -> image/png
.jpg   -> image/jpeg
```

> Unknown extensions fall back to `application/octet-stream`

