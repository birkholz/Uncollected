# Uncollected

Restores the "Collected" / "Not Collected" filters in the Collections journal (Mounts, Pets, Toys, and Appearances) for World of Warcraft Forever.

Forever's Collections journal hides or modifies the filter checkboxes available in Retail, removing the option to show uncollected things. This addon restores the filters, and enables the display of uncollected items by default.

- Forces the `onlyShowCollectedItemsInJournal` CVar off, which causes all collections tabs to be available even if you don't own a pet/mount/toy, and partially restores some filters Forever's own filter override skips creating entirely.
- Removes the mount Type filter (Ground/Flying/Aquatic/Dragonriding/Ride Along), since Camelot only has ground mounts and that submenu is inherited unmodified from retail's mount code.

## Status

Actively developed against the Forever beta client. Interface code is subject to change between beta builds.
