# Hide polite-particle glosses in example translations

## Goal

Keep Thai sentence-final polite particles out of the Chinese translation shown for an example sentence, while continuing to show those particles and their meanings in the word-segment breakdown.

For example, the sentence `เมื่อคืน นอนหลับดีไหมครับ` should display the Chinese example meaning as `昨晚睡得好吗`, rather than appending the gloss for `ครับ`.

## Scope

- Applies only to the displayed `exampleMeaning` for review-card examples.
- Applies when a recognized polite/utterance-final particle occupies the final Thai segment of the example sentence.
- Leaves the Thai sentence itself unchanged.
- Leaves the segment breakdown unchanged, including its gloss for the final particle.
- Does not alter persisted content data or the source value of `exampleMeaning`.

## Design

Add a presentation-layer normalization step at the point where an example meaning is produced or displayed. It will:

1. Inspect the example's final parsed Thai segment.
2. Recognize supported sentence-final polite particles, initially including `ครับ`, `ค่ะ`, and `คะ`.
3. Remove only that final segment's generated Chinese gloss from the displayed example meaning.
4. Preserve all remaining Chinese wording and punctuation.
5. Fall back to the original `exampleMeaning` if no supported final particle or matching terminal gloss is found.

The segmentation/word-breakdown model remains the source for displaying the particle's standalone meaning, so users can still learn it as vocabulary without seeing an unnatural phrase such as “礼貌语气词” in a fluent Chinese sentence translation.

## Error handling

Normalization must be conservative: if the segment list is unavailable, malformed, or the terminal gloss cannot be identified confidently, the app shows the unmodified example meaning. It must never delete non-final lexical content.

## Testing

Add focused tests for:

- A male polite final particle: `ครับ` is omitted from the displayed Chinese example meaning.
- Female/question final particles: `ค่ะ` and `คะ` are omitted.
- A normal final word is not removed.
- Segment-breakdown content still includes the polite particle gloss.
- Missing or non-matching data returns the original example meaning.

## Non-goals

- Rewriting Chinese example translations generally.
- Removing polite-particle glosses from word-segment breakdowns.
- Editing existing content files or regeneration pipelines.
