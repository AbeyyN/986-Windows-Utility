# 986 Custom Resolution

`986 Custom Resolution` is an advanced v0.7 display tweak. It must preserve the permanent 986 Never-Lock rule.

## Goals

- expose current adapter/mode information;
- apply driver-exposed existing modes safely;
- support true custom modes through GPU-vendor APIs when the hardware/driver supports them;
- test before keeping a mode;
- automatically revert an unconfirmed trial;
- restore the exact previous display mode/topology on Undo.

## Provider model

- Windows existing modes: DisplayConfig / normal driver-exposed modes.
- AMD: ADLX custom-resolution provider.
- NVIDIA: NVAPI custom-display provider.
- Intel: IGCL / supported Intel custom-mode path.

A provider is a capability, not a guarantee. A laptop internal panel or driver may reject true custom modes.

## Permanent safety rules

1. No raw EDID override hack.
2. No graphics-driver patching.
3. No HKLM display override used to force unsupported modes.
4. No watchdog or scheduled resolution enforcement.
5. After a successful Keep, the user may change resolution manually and 986 does not re-apply it.
6. Custom mode Apply remains disabled until the selected provider has a validated trial/revert path.
7. Unsupported displays report `UNSUPPORTED` / provider-not-ready rather than being forced.

## Trial flow

`Detect current -> snapshot exact mode/topology -> provider capability check -> trial mode -> confirmation -> Keep OR automatic revert`

The current alpha capability layer deliberately returns `CanApply=false` for true custom modes. This is intentional until vendor bindings and hardware rollback tests are complete.
