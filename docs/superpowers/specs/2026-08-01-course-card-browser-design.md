# Course Card Browser Design

## Goal

Let learners open a full, ordered card group for any course category from a course-list row, beginning on the item they selected, without affecting FSRS study data.

## Confirmed interaction

- Applies to every course category.
- Tapping the Thai text itself continues to play that item’s headword audio.
- Tapping the favorite button continues to toggle the favorite only.
- Tapping any other part of a row opens the course card browser at that row’s item.
- The browser includes every item in the selected category in bundled-content order.
- It supports flip, previous/next navigation, headword audio, and complete-example audio.
- It does not show rating buttons and never writes review logs, FSRS scheduling state, or review drafts.
- The navigation back action dismisses the browser and returns to the source course list.
- The existing course toolbar “练习” remains the FSRS study session and keeps its queue limits, prerequisites, scheduling, and draft behavior.

## Architecture

Extend `ReviewSessionRoute` with a `courseBrowse(category:startContentID:)` case. Reuse `ReviewSessionView`, `ReviewSessionViewModel`, and card presentation, but give this route a dedicated initialization path that loads bundled category items directly instead of calling `StudyQueueBuilder`.

The route must have no draft source and must be recognized as a non-study mode. The view and `FlipCardView` must render navigation controls rather than rating controls for this route.

## Data and navigation

1. `UnitDetailView` holds optional `selectedBrowseItemID` alongside the existing study-session state.
2. The Thai text control remains its own tappable target and plays audio only.
3. The favorite button remains its own button target and toggles the favorite only.
4. A separate row-background/content-shape gesture invokes `courseBrowse(category:startContentID:)` only when the Thai-text or favorite action did not consume the tap.
5. The browser route loads all bundled `ContentItem`s where `item.category == category`, preserving repository order.
6. It creates browse queue entries in that same order, sets the cursor to the matching `startContentID`, then renders that item first.
7. If the category or requested ID is unavailable, it shows the route’s empty state rather than falling back to an FSRS queue.

## Browser UI behavior

- Header counter displays the current position and the full category count.
- Existing card flip and swipe behavior remains available.
- Browser mode provides previous/next controls and disables them at the first/last item.
- Browser mode must not render, call, or expose the existing rating action.
- Existing review routes retain all current continuation, rating, completion, and draft behavior.

## Audio constraints

- Main-word playback continues to call `AudioPlaybackService.play(audioID:thaiText:)` using the item’s `audioID`.
- Example playback continues to call `playSentence(audioID: "<audioID>-example", text: example)` once for the complete example.
- No new content items or audio assets are created by this feature.

## Acceptance criteria

- Every course list row opens its own category browser at the selected item when its non-Thai/non-favorite area is tapped.
- Thai text and the favorite button retain their current behavior.
- Browser mode covers all category items in source order, is not limited by the daily new-card limit, and has no FSRS side effects.
- Toolbar “练习” remains a scheduled FSRS unit study session.
- Back returns to the source course list.
- Targeted unit/navigation tests and a real-device smoke test pass.
