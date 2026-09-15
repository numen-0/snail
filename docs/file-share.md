# File Share

A simple file-sharing handler for creating, replacing, downloading, listing, and
deleting files and directories.

> [src](/src/handler/file-sharing.sh)

## API

- `HEAD` requests
- `GET` file download or directory listing
- `POST` file and directory creation
- `PUT` file replacement
- `DELETE` files and empty directories

## Configuration

| Variable      | Default           | Description                              |
|:-------------:|:-----------------:|:-----------------------------------------|
| `SHARE_ROOT`  | `./files`         | Directory containing shared data         |

## Example

**Upload**:

Generate a 128 MiB file and upload it:

```sh
dd if=/dev/urandom of=/tmp/random.bin bs=1M count=128 2>/dev/null
time curl -siX POST http://localhost:8080/random.bin \
    --data-binary @/tmp/random.bin
```

```
HTTP/1.1 201 Created
Server: snailHTTP/0.1.0
Content-Length: 0
Connection: close


real	0m47.041s
user	0m0.034s
sys	0m0.078s
```

**Download**:

```sh
time curl -sX GET \
  -D /dev/stderr \
  http://localhost:8080/random.bin \
  > /tmp/random-copy.bin
cmp /tmp/random{,-copy}.bin -s; echo $?
```

```
HTTP/1.1 200 OK
Server: snailHTTP/0.1.0
Content-Type: application/octet-stream
Content-Length: 134217728
Connection: close


real	0m0.099s
user	0m0.005s
sys	0m0.048s
0
```

