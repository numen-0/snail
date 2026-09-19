# ETCD

A simple filesystem-backed key-value store with transactional identifiers.

The handler provides an HTTP API for creating, replacing, reading, and deleting
values. Keys are represented as paths inside the store, allowing hierarchical
namespaces to be created naturally.

Each mutating operation receives a monotonically increasing transaction
identifier. Transaction identifiers are allocated before the mutation is
performed, so a failed mutation may consume an identifier. Identifiers are never
reused.

> [src](/src/handler/etcd.sh)

## API

The API is available under `/v1/kv/`.

| Method   | Path           | Description                                      |
|:--------:|:---------------|:-------------------------------------------------|
| `HEAD`   | `/v1/kv/<key>` | Return key headers without its contents          |
| `GET`    | `/v1/kv/<key>` | Read a value                                     |
| `PUT`    | `/v1/kv/<key>` | Create or replace a value                        |
| `DELETE` | `/v1/kv/<key>` | Delete a value                                   |

Keys must begin with `/` and cannot contain `..` path components.

Values are sent as the request body and require a valid `Content-Length` header.

### PUT

Create or replace a value:

```sh
curl -siX PUT http://localhost:8080/v1/kv/example \
    --data "hello"
```

```
HTTP/1.1 200 OK
Server: snailHTTP/0.1.0
Content-Length: 16
Connection: close

1
/example
hello
```

### GET

Read an existing value:

```sh
curl -siX GET http://localhost:8080/v1/kv/example
```

```
HTTP/1.1 200 OK
Server: snailHTTP/0.1.0
Content-Length: 16
Connection: close

1
/example
hello
```

> `HEAD` uses the same lookup as `GET` but does not return the response body.

### DELETE

Delete an existing value:

```sh
curl -siX DELETE http://localhost:8080/v1/kv/example
```

```
HTTP/1.1 200 OK
Server: snailHTTP/0.1.0
Content-Length: 10
Connection: close

2
/example
```

> **Note**:
>
> Empty parent directories are removed after a key is deleted. This allows a
> previously nested key path to later be used as a value:
>
> ```
> PUT /v1/kv/foo/bar
> DELETE /v1/kv/foo/bar
> PUT /v1/kv/foo        -> 200 Ok
> ```
>
> Leaving empty directories behind is considered a storage leak and is treated
> as an implementation error.

## Keys and namespaces

Keys map directly to paths below the store's data directory.

For example:

```
/v1/kv/config/service-x/port
```

is stored as:

```
data/config/service-x/port
```

A key cannot simultaneously be a value and a prefix for other keys.

For example, these two keys cannot coexist:

```
/foo
/foo/bar
```

If `/foo` is already a value, creating `/foo/bar` returns `409 Conflict`.

Likewise, if `/foo` is a directory containing child keys, creating `/foo`
returns `409 Conflict`.

Missing parent directories are created automatically when a new nested key is
written.

## Transactions

The store maintains a single global transaction identifier in the
`.transaction` file.

Mutating operations acquire the store lock and allocate the next transaction
identifier before changing the value.

Transaction identifiers are monotonically increasing and are never reused.

A failed mutation may therefore leave a gap in the sequence:

```
1
2
4
5
```

This is intentional. Burning an identifier is preferable to ever reusing a
transaction identifier for a different mutation.

The transaction identifier represents the store's mutation sequence; it is not
a per-key revision and does not provide historical versions of values.

## Concurrency

Mutations and reads are serialized using a filesystem lock implemented with
`mkdir`.

Only one request can access the store's state while the lock is held.

PUT operations write the request body to a temporary file and then atomically
replace the target using `mv`. This prevents a partially written value from
becoming the stored value.

## Configuration

| Variable    | Default        | Description                                   |
|:-----------:|:---------------|:----------------------------------------------|
| `ETCD_ROOT` | `./data/etcd`  | Directory containing the store                |
| `ETCD_TMP`  | `/tmp/etcd`    | Directory used for temporary files            |

The store uses the following files and directories below `ETCD_ROOT`:

```
data/           key-value data
.lock           store lock
.transaction    global transaction identifier
```

