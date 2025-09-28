# sad

this is a rewrite of my [original](https://github.com/MarieEckert/sad) sad
parser and format. the goal is to make parsing and the resulting datastructures
less terrible and adjust the syntax to be a little less wordy and more
consistent.

## primary syntax differences

* `{$begin-section} <name>` -> `{$section} <name>` (backwards compatible)
* `{$color <color>}` removed
* `{$reset}` now resets the last applied style
* `{$reset-all}` resets all styles
* `{$sub-head}`
    * deprecated
        * headers now derive their importance from the
          depth of the section which they are found in.
    * only one per section, can not be in a section if a regular `{$head}`
      switch was already encountered.
* `{$head}`
    * headers now derive their importance from the
      depth of the section which they are found in.
    * only one `{$head}` or `{$sub-head}` switch may appear in a section.

## what the parsed data looks like

a parsed sa document is contained inside an instance of the `TDocument` record.
this record contains a map of the metadata, the title and a pointer to the root
section of the document.

switches recognized by the parser do not appear inside the parsed data,
non-recognized switches will still appear. if that behaviour is not wanted and
an error should be emitted if an unrecognized switch appears, define
`OnlyStandardSwitches` at compilation time.

### sections

the root section is of the record type `TSection` like every other section and
contains is subsections in the field `children`. the text inside of a root
section is stored in blocks (array of `TTextBlock`). a new textblock is opened
everytime a style changes.

### text blocks

a textblock (`TTextBlock`) represents a block of text associated with its active
set of styles (array of `TStyle`). The actual text is stored in an array of
strings which was initially split at every space and trimmed of whitespace,
except for linebreaks.

### styles

active styles are represented using the `TStyle` record which stores the kind
of the style (`TStyleKind`) which may be either one of:

* Head
* SubHead
* Custom

and the arguments, if any, for that style in a string array.
