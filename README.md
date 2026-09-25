# Uncollected

Restores the "Collected" / "Not Collected" filters in the Collections journal (Mounts, Pets, Toys, and Appearances) for World of Warcraft Forever.

Forever's Collections journal hides/modifies the filter checkboxes available in Retail, removing the option to show uncollected things. This addon restores those filters, and enables the display of uncollected items by default. When you own zero mounts/pets/toys, those tabs are hidden, so this addon also makes all tabs always visible even if you own none of each, allowing you to browse all the mounts/pets in the game.

While there is a toys tab in Forever's Collections journal, it normally only shows if you have a toy collected. However, there are seemingly no toys in the game yet, so the tab is empty for now regardless of filters. It's unclear if the toys tab is intended to be in the game, or if its just incomplete in beta, but if any are added, they'll show as uncollected like the other tabs do.

- Forces the `onlyShowCollectedItemsInJournal` CVar off, which causes all collections tabs to be available even if you don't own a pet/mount/toy, and partially restores some filters Forever's own filter override skips creating entirely.
- Removes the mount Type filter (Ground/Flying/Aquatic/Dragonriding/Ride Along), since Forever only has ground mounts and that submenu is inherited unmodified from retail's mount code.

## Status

Actively developed against the Forever beta client. Interface code is subject to change between beta builds.
