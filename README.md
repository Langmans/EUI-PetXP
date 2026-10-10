# EUI-PetXP

A hunter pet experience bar for EllesmereUI, built like the Action Bars XP bar
(dark background, 1px border, centred text in the Action Bars font, tooltip on
hover). Fill colour is the hunter class colour.

- Shows only while the pet has experience (`GetPetExperience()` max above 0),
  so it stays hidden without a pet or with a warlock demon.
- Text: `Pet <level> - <pct>%`. The tooltip adds the raw numbers, what is left,
  and a note when the pet has reached the hunter's level (it then gains no XP).
- Position, width and height belong to EllesmereUI unlock mode: the element is
  "Pet XP Bar" in the Action Bars group. Its Anchor To and Width Match tools can
  attach it to the pet unit frame.
- `/petxp bar [on|off]` switches the standalone bar (toggles without an
  argument). Switched off, it also has no mover in unlock mode. The DataBars
  block below is not affected.
- Saved in `EUIPetXPDB` (account-wide): `enabled`, `pos`, `width`, `height`.

## DataBars block

With EllesmereUI DataBars loaded, the addon also adds a **Pet XP Bar** block
type to the DataBars "Add Block" picker, next to XP / Reputation Bar. It looks
like that block (label `Pet <pct>% to level <n>` over a thin bar in the hunter
colour, tooltip with the numbers) and collapses out of the bar when there is no
pet XP to show.

DataBars has no public API for this. `DataBarBlock.lua` reaches its namespace
through `EllesmereUI._ModuleNS.EllesmereUIDataBars` and adds entries to
`BLOCK_TYPES`, `BLOCK_DEFAULTS` and `BlockFactories`. Every table and helper is
checked first, so a DataBars update that changes them makes the block disappear
from the picker rather than raise errors. The block has no settings of its own
yet (no type-specific rows in the DataBars options page).

## Files

- `Core.lua`: settings (`ns.Get`, `ns.Cfg`) and the pet's experience (`ns.PetXP`).
- `Click.lua`: the secure left-click overlay that opens the pet page of the
  character window; shared by the bar and the block.
- `Bar.lua`: the standalone bar and its unlock-mode element.
- `Commands.lua`: `/petxp`.
- `DataBarBlock.lua`: the DataBars block.

## Install

Junction this folder into the client's `Interface\AddOns`:

```
New-Item -ItemType Junction -Path "<WoW>\_classic_beta_\Interface\AddOns\EUI-PetXP" -Target "<this folder>"
```
