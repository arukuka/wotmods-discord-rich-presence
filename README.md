# Discord Rich Presence for World of Tanks

![cover image](./lfs/cover.png)

This mod makes World of Tnaks enabling Discord Rich Presence.

## 1. Feature

### 1.1. Display activity in some contexts

Following contexts are supported.

|context|description|
|-|-|
|`in_lobby`|player is in garage|
|`in_queue`|player is in matching queue|
|`arena_waiting`|player is awaiting other players|
|`arena_prebattle`|player is awaiting start of battle|
|`arena_battle`|player is in battle|

### 1.2. Customizable

We can customize text of activity.  
After installed, settings file are available in  
`<WoT install dir>\mods\configs\arukuka.discord_rich_presence\<your client lang>.json`

Following variables are supported in each context.

|variable|context|description|
|-|-|-|
|${vehicleName}|all contexts|long name of vehicle selected (e.g., Object 277)|
|${vehicleShortName}|all contexts|short name of vehicle selected (e.g., Obj. 277)|
|${arenaName}|`arena_*`|localized map name (e.g., Karelia, Malinovka, Prokhorovka)|
|${gameplayName}|`arena_*`|localized game play type (e.g., Standard Battle, Encounter)|
|${arenaGuiName}|`arena_*`|localized game type (e.g., Random Battle, Advance)|
|${waiting_message}|`arena_waiting`|localized client message when awaiting players|

#### 1.2.1. Example

![customization example](./lfs/customization_example.png)
