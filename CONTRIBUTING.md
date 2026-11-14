# Contributing

Thank you for helping with MATE Wayland Desktop. Reports from other
hardware are the most useful thing you can give the project.

## Reporting a problem

Open an issue at
<https://github.com/mate-wayland/mate-wayland-desktop/issues> and include:

- the name of the ISO file you installed from (it contains the build date);
- the computer: make and model, graphics card, and whether it is a virtual
  machine;
- what you did, what you expected and what happened;
- for display or session problems, the files in
  `~/.local/state/mate-wayland-desktop/`.

Check the output of the commands before posting it: remove anything you do
not want to be public.

If the problem is in a program that this project takes unchanged from
Ubuntu, MATE or labwc, it is usually best reported to that project as well;
say so in the issue if you have.

Security problems are reported privately: see [SECURITY.md](SECURITY.md).

## Building

On a Debian-family Linux machine with `debootstrap`, `apt` and `sudo`:

```sh
./build.sh --packages     # first time: build the MATE packages, then the ISO
./build.sh                # afterwards: just the ISO
```

The build runs inside its own Ubuntu system directories and installs
nothing on the build machine. The ISO is written to `iso/out/`.

## Where things are

| Path | What it holds |
|---|---|
| `session/`, `labwc/`, `panel/` | The session package: start script, helpers, compositor configuration, panel layout and default settings |
| `packaging/` | How the MATE packages are rebuilt: one directory per package with `adjust.sh` and `patches/` |
| `iso/` | The ISO build: package lists, installer settings, branding, live-session files |
| `lib/` | Shared build functions |
| `artwork/`, `wallpapers/`, `icons/` | Logo, wallpaper and the icon theme |
| `CUSTOMISATIONS.md` | Every difference from stock Ubuntu and MATE, and why |

## Sending a change

- Open a pull request against `main`. Keep one change per pull request and
  say how you tested it.
- A change to how the system differs from Ubuntu or MATE also adds or
  updates its line in `CUSTOMISATIONS.md`.
- Fixes to MATE, labwc or other upstream programs belong upstream first;
  the project carries a patch only until the fix is released there.
- Contributions are accepted under the licence of the file they change:
  GPL-3.0 for the project's own files, the upstream licence for patches to
  upstream programs.

Accepted changes are integrated by the maintainers and appear in this
repository with you as the author.
