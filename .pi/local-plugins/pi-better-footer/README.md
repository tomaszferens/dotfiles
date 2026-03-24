# pi-better-footer

A local fork of [`mcowger/pi-vitals`](https://github.com/mcowger/pi-vitals).

This package lives in:

- `~/.pi/local-plugins/pi-better-footer`

And is loaded from global pi settings via:

- `~/.pi/agent/settings.json`
- package entry: `../local-plugins/pi-better-footer`

## Why this exists

We want our own copy of the footer extension so we can change it freely without depending on the upstream `pi-vitals` package.

## Pi extension notes

Per pi's extension docs:

- auto-discovery only covers `~/.pi/agent/extensions/*` and `.pi/extensions/*`
- arbitrary folders like `local-plugins/` must be wired in through `settings.json`
- local directories can be loaded as pi packages via the `packages` array

This package uses the documented local-package approach.

## Reloading

After editing the extension, run:

```bash
/reload
```

Or reload just the footer config:

```bash
/footer reload
```

## Configuration

Footer configuration stays in:

```bash
~/.pi/agent/powerline.json
```

## Commands

- `/footer reload`
- `/footer debug`

## Upstream

Original project:

- <https://github.com/mcowger/pi-vitals>
