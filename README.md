# Terminal opacity

An Omarchy bar widget with one slider for the background opacity of every
terminal, or of one window. Terminals change live as the slider moves, and the
text stays solid. 100% is a solid background, 0% is clear.

![Two terminals at 49% opacity with the wallpaper showing through sharp](assets/opacity.png)

The background at 49%, with what is behind showing through sharp.

![The same terminals with the wallpaper blurred behind them](assets/opacity-blur.png)

The same with **Blur what shows through** on.

![Grok and OpenCode with the backgrounds they paint left solid](assets/painted-solid.png)

Programs that paint their own backgrounds keep them solid: Grok's whole
screen on the left, OpenCode's input box on the right. The other shots have
**Fade painted backgrounds too** on, which fades those with the rest.

![The Terminal opacity panel, itself frosted, open over Grok and OpenCode at 38%](assets/frosted-panel.png)

The panel: the slider, the switches, and what the slider applies to. Here
**Frost bar dropdowns** is on and set to **Match terminals**, so the panel
itself is 38% solid with blur behind it, like the terminals.

## Using it

- Click the bar icon, pick **All terminals** or one window, and drag.
- Scroll on the bar icon to nudge the focused terminal by 5.
- In the panel: Up/Down picks a target, Left/Right changes it by 5, Enter
  flips its blur.
- **Blur what shows through** turns on frosted glass behind whatever is
  picked: every terminal, or one window until it closes. It is off at first,
  so what is behind a terminal shows through sharp. If Hyprland's own blur is
  off, a **Turn on Hyprland's blur** button appears under it (see [Blur](#blur)).
- **Frosted glass** makes Hyprland's blur heavier and brighter, so what is
  behind a terminal, the bar or a menu reads as frosted glass rather than a
  dimmed smudge. While it is on, **Frost brightness** and **Blur strength**
  sliders sit under it (see [Frosted glass](#frosted-glass)). Off at first.
- **Fade painted backgrounds too** fades the solid colours that programs
  paint, such as the panels of a CLI harness. It is one choice for every
  terminal, and off at first.
- **Frost bar dropdowns** makes every bar dropdown see-through with blur
  behind it, the same glass as the terminals. While it is on, a **Dropdown
  opacity** slider sets how solid they are, or **Match terminals** has them
  follow the All terminals slider (see [Frosted dropdowns](#frosted-dropdowns)).
  Off at first.
- **Round window corners** turns on Omarchy's rounded corners for every
  window, whatever the theme. Off hands the corners back to the theme.
- **Follow the theme again** forgets the opacity saved here. It leaves the
  blur choice alone.

**All terminals** saves a default. New terminals open with it, and it survives
theme changes. One window's value is its own until that window closes.

## Blur

Hyprland blurs what shows through a see-through window whenever its blur is
on, which Omarchy's Glassy look does. The widget tells each terminal window
not to blur (`no_blur`) unless the switch is on for it. One window's choice is
always just that window, even where its opacity is shared with its process.

**Omarchy ships with Hyprland's blur off**, and the switch cannot blur anything
until it is on. While it is off and blur is wanted, the panel shows a **Turn on
Hyprland's blur** button. It runs `omarchy hyprland window transparency glassy`,
Omarchy's Glassy look, which also blurs the bar and menus and fades Nautilus a
little. The same from a terminal:

```sh
terminal-opacity glassy
```

To go back: `omarchy hyprland window transparency transparent`.

**Foot needs a new window after blur is turned on.** Foot turns Hyprland's
blur down unless its own config asks for it, and it reads that only when a
window opens. Glassy adds the setting, so Foot windows that were open before
it stay sharp whatever the switch says. Open a new one and it is blurred.

## Frosted dropdowns

Omarchy's bar dropdowns are solid in most themes. **Frost bar dropdowns** sets
their `[popups] background-alpha` in `~/.config/omarchy/shell.toml`, which
Omarchy lays over every theme and the shell rereads live, so it survives theme
changes. With Hyprland's blur on, what is behind a dropdown shows through
frosted; with it off, sharp, and the panel offers the **Turn on Hyprland's
blur** button.

The **Dropdown opacity** slider goes from 30% to 100%: below 30% Glassy stops
blurring, and fully solid leaves nothing to blur. **Its own** keeps the
slider's value. **Match terminals** has the dropdowns follow the All terminals
slider, live as it is dragged, and the theme's value when nothing is saved,
held at 30% at the least. Dragging the dropdown slider goes back to its own
value. Turning the switch off and on again brings back whichever was set.

The widget writes one line, marked `# bhj.terminal-opacity`, last in the
`[popups]` section, and leaves the rest of the file alone. Turning it off takes
that line out again, handing the dropdowns back to your own setting or the
theme.

```sh
terminal-opacity frost on      # 80% at first, then whatever was last set
terminal-opacity frost 70
terminal-opacity frost follow  # match the terminals
terminal-opacity frost off
```

## Frosted glass

Omarchy's Glassy blur is soft and dims what is behind it a little. **Frosted
glass** swaps in a heavier, brighter blur: size 10 over 3 passes, brightness
1.15, more vibrancy and a little grain. It is Hyprland's one blur, so it
changes everything Hyprland blurs: terminals, the bar, menus and frosted
dropdowns. Like them, it needs Hyprland's blur on (see [Blur](#blur)).

The switch writes `~/.local/state/omarchy/toggles/hypr/zz-bhj-terminal-opacity-glass.lua`,
which Omarchy loads after its own toggles, so it wins over Glassy's settings
and survives theme changes. Turning it off deletes the file. Either way
Hyprland reloads; if it reports a config error the file is taken out again.

```sh
terminal-opacity glass on
terminal-opacity glass brightness 130   # 50 to 200; 100 leaves it as is
terminal-opacity glass strength 60      # 0 to 100
terminal-opacity glass off
```

While it is on, two sliders sit under the switch:

- **Frost brightness**, from 50% (dimmer than what is behind) through 100%
  (as is) to 200% (brighter); 115% at first.
- **Blur strength**, from 0% (a light haze) to 100% (heavy frost); 40% at
  first. It moves Hyprland's blur size and passes together, since a large
  size over few passes turns blocky:

  | Strength | 0% | 20% | 40% | 60% | 80% | 100% |
  |---|---|---|---|---|---|---|
  | size | 2 | 6 | 10 | 14 | 18 | 22 |
  | passes | 1 | 2 | 3 | 4 | 4 | 4 |

Dragging either changes Hyprland's blur live with `hyprctl eval`, with no
reload; letting go saves it into the file. Both go away when the switch is
off, and their values are kept for the next time it is on. More passes cost
more GPU on every blurred frame.

## Round corners

**Round window corners** is Omarchy's own setting, `omarchy hyprland corners`,
from the panel: on forces rounded corners on every window, off goes back to
whatever the theme draws. `uninstall` leaves it as it is.

```sh
terminal-opacity corners on    # omarchy hyprland corners rounded
terminal-opacity corners off   # omarchy hyprland corners theme
```

## Painted backgrounds

A terminal fades only its own default background, so a colour a program
paints stays solid. The switch asks each terminal to fade those too:

| Terminal | Setting | When |
|---|---|---|
| Foot | `alpha-mode=all` | windows opened after the switch |
| Ghostty | `background-opacity-cells` | live |
| Alacritty | `transparent_background_colors` | live |
| Kitty | `transparent_background_colors`, listed colours only | live |

They fade to the same opacity as the background; only Kitty can give a colour
its own. Everything painted fades, selection and status bars included.

Foot reads this only when a window opens. Foot windows opened before the
switch last changed are marked **reopen to apply** in the panel, and the
switch says how many there are, until they are closed.

Kitty has no setting for every colour. List the ones to fade, up to seven, in
`~/.config/kitty/transparency-colors`, one per line, as `#1f2335` or
`#1f2335@0.4` for its own opacity. To find what a program paints, run it
through the widget, use it for a moment and quit:

```sh
terminal-opacity colors grok
```

Then flip the switch off and on so Kitty rereads the list.

## How each terminal is driven

| Terminal | How | Scope | Text |
|---|---|---|---|
| Foot | OSC 11 with an alpha, written to the window's pty | one window | solid |
| Ghostty | include file, then `SIGUSR2` to one process | one process | solid |
| Kitty | include file, then `SIGUSR1` to one process | one process | solid |
| Alacritty | `alacritty msg config` on its IPC socket | one process | solid |
| anything else | Hyprland's opacity for that window | one window | fades too |

A window counts as a terminal if it carries Omarchy's `terminal` tag, is one of
the four above, or its process holds a pty. That last test is what picks up
terminals nobody listed.

A terminal with no background-only control can only fade as a whole window, so
its text fades with it. The panel marks those rows "fades text too", and they
stop at 10% so the window never disappears.

Terminals with their own control are pinned to full Hyprland opacity, so
Omarchy's whole-window fade no longer dims their text.

Tested on Foot 1.28, Kitty 0.49, Ghostty 1.4 and Alacritty 0.17.

## Install on another machine

```sh
git clone https://github.com/ben-chitin/terminal-opacity ~/.config/omarchy/plugins/bhj.terminal-opacity
~/.config/omarchy/plugins/bhj.terminal-opacity/terminal-opacity install
```

That puts the widget in the bar and adds a theme-set hook that puts the saved
values back after a theme change. If the bar shows no icon, run
`omarchy restart shell`. Upgrading from version 1 removes its old
`20-terminal-transparency` hook, which no longer works.

**For blur, turn on Hyprland's blur too.** Omarchy has it off by default, and
`install` says so when it is. Use the button in the panel, or run
`terminal-opacity glassy` (see [Blur](#blur)).

The first change adds one include line to each terminal config that exists
(`foot.ini`, `ghostty/config`, `kitty.conf`, `alacritty.toml`) and writes a
`transparency*` file beside it. Ghostty's include also turns off its
"Reloaded the configuration" toast, which would otherwise show on every step.

`terminal-opacity uninstall` removes the hook, the saved state, those
includes, the dropdown frost line and the frosted glass file.

## Command line

```sh
terminal-opacity list
terminal-opacity set all 80
terminal-opacity set focused 60
terminal-opacity blur all on
terminal-opacity blur focused toggle
terminal-opacity cells on
terminal-opacity glassy
terminal-opacity frost on
terminal-opacity glass toggle
terminal-opacity glass strength 60
terminal-opacity corners toggle
terminal-opacity colors grok
terminal-opacity nudge focused -5
terminal-opacity reapply
terminal-opacity reset
```

State is in `~/.local/state/omarchy/terminal-opacity-v2.json`.

## Limits

- Ghostty, Kitty and Alacritty windows drawn by one process change together.
- Kitty windows opened before the include was added need a restart first.
- Foot hides its transparency while a window is fullscreen.
- Resetting a whole-window terminal sets it to solid; Hyprland cannot clear a
  window's opacity once set.
