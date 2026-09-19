# File Share

A simple file-sharing handler for creating, replacing, downloading, listing, and
deleting files and directories.

The handler provides both an HTTP API and a small HTML interface for browsing
shared files.

> [src](/src/handler/file-sharing.sh)

## Web interface

The browser interface is available under `/web/`.

- `/`: home
- `/web/`: browse the shared directory
- `/web/path/to/file`: download a file
- `/web/path/to/directory/`: browse a directory

Directories are required to end with `/`. When browsing a directory without the
trailing slash, the handler redirects to the canonical path.

The directory browser provides forms for uploading files and creating
directories, as well as controls for deleting files and empty directories.

## API

The API is available under `/api/`.

| Method    | Resource  | Description                                          |
|:---------:|:----------|:-----------------------------------------------------|
| `HEAD`    | file      | Return file headers without its contents             |
| `GET`     | file      | Download a file                                      |
| `GET`     | directory | List directory contents as plain text                |
| `POST`    | file      | Create a file                                        |
| `POST`    | directory | Create a directory                                   |
| `PUT`     | file      | Replace an existing file                             |
| `DELETE`  | file      | Delete a file                                        |
| `DELETE`  | directory | Delete an empty directory                            |

Directories must end with `/` when accessed through the API.

## Configuration

| Variable      | Default             | Description                            |
|:-------------:|:-------------------:|:---------------------------------------|
| `SHARE_ROOT`  | `./data/file-share` | Directory containing shared data       |

## Example

**Create a Directory**:

```sh
time curl -siX POST http://localhost:8080/api/example/
```

```
HTTP/1.1 201 Created
Server: snailHTTP/0.1.0
Content-Length: 0
Connection: close


real	0m0.065s
user	0m0.008s
sys	0m0.004s
```

**Upload**:

Generate a 128 MiB file and upload it:

```sh
dd if=/dev/urandom of=/tmp/random.bin bs=1M count=128 2>/dev/null
time curl -siX POST http://localhost:8080/api/random.bin \
    --data-binary @/tmp/random.bin
```

```
HTTP/1.1 201 Created
Server: snailHTTP/0.1.0
Content-Length: 0
Connection: close


real	0m49.128s
user	0m0.046s
sys	0m0.072s
```

**Download**:

```sh
time curl -sX GET \
  -D /dev/stderr \
  http://localhost:8080/api/random.bin \
  > /tmp/random-copy.bin
cmp /tmp/random{,-copy}.bin -s; echo $?
```

```
HTTP/1.1 200 OK
Server: snailHTTP/0.1.0
Content-Type: application/octet-stream
Content-Length: 134217728
Connection: close


real	0m0.118s
user	0m0.009s
sys	0m0.054s
0
```

**Delete**:

```sh
curl -siX DELETE http://localhost:8080/api/random.bin
```

```
HTTP/1.1 204 No Content
Server: snailHTTP/0.1.0
Connection: close


real	0m0.069s
user	0m0.005s
sys	0m0.005s
```

