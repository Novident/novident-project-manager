# Placeholders

Placeholders are little `<$…>` tokens that make a manuscript **write itself**:
when you compile, Novident replaces them with real values — page numbers, the
project title, dates, word counts, the current author…

They live in any text that goes through the compiler (title prefixes/suffixes,
headers, footers, and document body), so the same token can mean different
things depending on where it appears.

## How to read the examples

Each block shows text you could write, followed by what the compiler prints.
A few things appear over and over:

- `<$n>` is **the number**; `:scene` is a **group name**, so `<$n:scene>` keeps
  its own count independent from `<$n:chapter>`.
- When a placeholder exists in uppercase, the compiler writes the value in
  uppercase too.

## Counting chapters, scenes, and sub-steps

The simplest counter is `<$n>`. Put it in a chapter title prefix and the
compiler counts as it goes:

```
Chapter <$n> — The Awakening
Chapter <$n> — The First Path
```
becomes
```
Chapter 1 — The Awakening
Chapter 2 — The First Path
```

You are not stuck with one counter. Give each section its own **group**:

```
Part <$n:part>
  Chapter <$n:chapter>
```
becomes
```
Part 1
  Chapter 1
Part 2
  Chapter 2
```
(Group 1 of `part` is independent from group 1 of `chapter`.)

Inside a chapter you often want steps that **restart with every chapter** —
that is `<$sn>` (sub-numbering), which resets each time a parent `<$n>`
advances:

```
Chapter <$n>
  Scene <$sn>
  Scene <$sn>
Chapter <$n>
  Scene <$sn>
```
becomes
```
Chapter 1
  Scene 1
  Scene 2
Chapter 2
  Scene 1
  Scene 2
```

For numbered *lists inside* a number, `<$dn>` writes double numbers:

```
Section <$n> — <$dn>, <$dn>
```
```
Section 1 — 1.1, 1.2
```

### Spelling numbers out

Want the count written as words instead of digits? Three flavours:

```
<$w>   →  one, two, three
<$W>   →  ONE, TWO, THREE
<$t>   →  One, Two, Three
```

Same for Roman numerals:

```
<$r>   →  i, ii, iii
<$R>   →  I, II, III
```

Every counter works with groups, so `<$w:act>` keeps a word-number count that
is independent from `<$n:act>` or anything else.

### Restarting a counter

You can tell a counter to start over. Reset all of them:

```
<$rst-all>
```

Or reset just one (and optionally only one of its groups):

```
<$rst-n>          restarts every <$n>
<$rst-n:scene>    restarts only <$n:scene>
```

A typical use is a volume whose parts restart chapter numbering:

```
Volume <$R:volume>
<$rst-n:chapter>
Chapter <$n:chapter>
```

## Report your own numbers

The compiler can quote the manuscript back to you:

```
<$wc>     words        →  "187"
<$wc1000> words rounded to the nearest 1000 → "0" (until you pass 500)
<$cc>     characters   →  "1030"
<$linecount> lines     →  "42"
```

`<$wc>` and `<$cc>` report exact totals; the optional suffix rounds them to a
nicer number (`50`, `100`, `500`, `1000`, `10000`), handy for progress bars
like "20 000 / 50 000".

## Dates that never go stale

Every date token reads the **current time at compile**:

```
<$today>          →  2026-07-20
<$weekday>        →  Monday
<$day>            →  20
<$month>          →  July      (<$month:n> → 7)
<$year>           →  2026
<$hour>           →  18
<$hms>            →  18:30:00
<$minute>         →  30
<$second>         →  00
<$millisecond>    →  000
<$microsecond>    →  000000
```

## The manuscript about itself

Metadata tokens pull from your project info, so a title page can describe the
book that contains it:

```
<$projecttitle>                →  The Crystal Labyrinth
<$abbr_title>                  →  Crystal Labyrinth
<$doctitle>                    →  The Awakening
<$iscode>                      →  978-0-000-00000-0
```

Uppercase writes uppercase: `<$ABBR_TITLE>` → `CRYSTAL LABYRINTH`.

## Who wrote this

`<$author>` prints the author. With several authors, ask for a specific one by
index or ask for them all:

```
Authors: "Elena Marlowe, John Doe, Ada Lovelace"

<$author>        →  Elena Marlowe
<$lastname:2>    →  Doe
<$firstname:3>   →  Ada
<$author:all>    →  Elena Marlowe, John Doe, Ada Lovelace
<$AUTHOR:all>    →  ELENA MARLOWE, JOHN DOE, ADA LOVELACE
```

Also available: `fullname`, `forename`, `surname` and their uppercase forms.

## Pulling content in

`<$include:documentName>` pastes the text of another document into the current
one (great for repeated snippets). It is marked experimental while the rule is
finished.

Images can be inserted with `<$img>` — from a document name or a file path —
with an optional fit:

```
<$img:Kira Character Sketch>
<$img:~/Pictures/map.png>
<$img:Cover:cover>         cover · contain · fill · fitWidth · fitHeight
                           · fill-all · none · scale-down
```

## Fine print

- A `<$…>` token nobody recognizes is left alone — it compiles as-is.
- Patterns are defined on `NovidentProjectDefaults` and applied by the rule
  families under `lib/src/rule/placeholder/rules/`.
- In editor content the replacement happens during compilation
  (`LayoutCompiler` → `ContentParser`), which also honours deferring
  placeholders until the very end when asked.
