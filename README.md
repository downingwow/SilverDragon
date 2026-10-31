# SilverDragon-CoA — Rare Scanner and Sighting History

> **[⬇ Download v1.0.1-CoA](https://github.com/uncle-bone/SilverDragon/releases/download/v1.0.1-CoA/SilverDragon-v1.0.1-CoA.zip)**


SilverDragon-CoA helps you notice rare creatures and remember where you encountered them in Conquest Reborn. It adapts SilverDragon's rare detection and alerts to Ascension's legacy 3.3.5a client.

## Features

- Detects supported rares through available nameplates, group targets, combat-log and cache information.
- Provides rare alerts and click-target support when the client permits it.
- Stores per-rare, per-zone sighting history in `SilverDragon2DB`.
- Displays historical world-map pins with tooltips without requiring HandyNotes.
- Supports optional HandyNotes integration for minimap pins and existing Cartographer integration.
- Includes configurable world pins and a HandyNotes minimap preference.
- v1.0.1-CoA adds optional ElvUI alert styling and recognition of standard and ElvUI named nameplate roots, with periodic name-text rediscovery.

Default Blizzard UI and DragonUI retain their existing presentation. ElvUI styling is optional and applied outside combat. Detection depends on information visible to the game client: this is not a guaranteed long-range scanner or a live server spawn feed. A historical map pin does not mean the rare is currently alive.

## Installation and settings

Download the ZIP from [Releases](https://github.com/uncle-bone/SilverDragon/releases). Copy `SilverDragon` directly into `Interface/AddOns`. Retain that exact folder name. Back up `SilverDragon2DB` before upgrading so your history is preserved.

Use `/silverdragon` to open the configuration. Optional map integrations require their respective addons. This release has not been verified in game.

Original SilverDragon by **Kemayo**, based on upstream v2.3.4-9-gfaa9d93, with the CoA map-history and compatibility adaptations maintained here.

## Compatibility and support

Target: Ascension Conquest of Azeroth / Conquest Reborn, legacy WoW 3.3.5a (Interface 30300). Source and package checks do not establish live realm compatibility. Report the addon version, UI addons, and full Lua error when filing an issue. Preserve your WTF SavedVariables when updating.

Maintainer: **Uncle Bone** · [GitHub support](https://github.com/uncle-bone). This is a community-maintained adaptation. Original authors retain their credits; bundled license and third-party attribution notices remain applicable.
