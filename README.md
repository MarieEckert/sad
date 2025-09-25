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

