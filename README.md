# Snail

Snail is a tiny static *HTTP* server written in *POSIX* shell.

It provides the low-level pieces needed to build small *HTTP* servers and
request handlers without pulling in a larger framework. The implementation is
intentionally small, simple, and easy to understand.

Snail also includes a few handlers built on top of the library. They serve as
examples of what can be built with it, while being useful enough to run in
production.

## Server Features

- `HTTP/1.1`
- `GET` and `HEAD` requests
- Basic *MIME* type detection

## Requirements

- Unix sistem
- `nc`

## Local development

Copy the example environment file:

```sh
cp .env.example .env
```

Then edit `.env` and change the variables to your needs.

### Watcher

Run Snail with the development watcher:

```sh
sh watch.sh
```

#### BusyBox

Snail expects `nc` to support both multiple connections (`-k`) and executing a
custom handler for each connection (`-e`). One way to get an `nc` implementation
with these features is through *BusyBox*.

If *BusyBox* is installed, it can expose its `nc` implementation:

```sh
ln -sv "$(which busybox)" /usr/bin/nc

nc -v
```

> **Note**:
> Make sure `/usr/bin/nc` (or the choosen path) is included in `PATH`.

### Docker Compose

Alternatively, run Snail with Docker Compose:

```sh
docker compose up --build
```

The project directory is mounted into the container, so changes are picked up
automatically by the watcher.

## License

All the repo falls under the [MIT License](/LICENSE).

