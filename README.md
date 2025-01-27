# LDC Speech Label Toolkit

Code for manipulating text based speech labels, including transcripts.

# Examples

Consider this file, called `hamlet.tsv`:

    file    beg end text
    hamlet.wav  1.1 2.2 to be
    hamlet.wav  3.3 4.4 or not to be

This is a plain text, tab delimited (TSV), four column file, with a header
and two transcribed segments.  In general, this library reads and writes tabular
data like this.  A wide variety of input formats can be parsed, but not necessarily used as output formats.

Consider another file, called `lincoln.tsv`

    file    beg end text
    lincoln.wav 80.0 81.0 four score
    lincoln.wav 82.0 87.0 and seven years ago

The command

    bin/combine.rb hamlet.tsv lincoln.tsv > hamlin.tsv

would produce a file `hamlin.tsv` like this:

    file    beg end text
    hamlet.wav  1.1 2.2 to be
    hamlet.wav  3.3 4.4 or not to be
    lincoln.wav 80.0 81.0 four score
    lincoln.wav 82.0 87.0 and seven years ago

This file represents two different transcripts, but can they can be manipulated
together, which reduces the number of files users have to deal with.

# Concatenation and Conversion

The `combine.rb` script is similar to the `cat` command in that it concatenates its arguments, but it's also format sensitive.  The file `hamlin.tsv` is essentially a concatenation of two transcripts, but the header only appears once.  The script parses and converts its input, so you might do

    bin/combine.rb foo.json > foo.tsv

to convert some other format to TSV.  But conversion is always to TSV, not anything else.  The command

    bin/combine.rb hamlin.tsv > hamlin.json

just produces an identical TSV, not a json file.  The file extension is ignored by `combine.rb`, unlike, for example, `sox`.  The general purpose of `combine.rb` is to combine multiple transcripts into a consolidated file to simplify further processing.  The output is logically the following:

    <header>
    <transcript1>
    <transcript2>
    ...

where the ordering of the transcripts is based on the sorted order of the argument filenames, not the filenames inside the transcripts.  So these commands:

    bin/combine.rb hamlet.tsv lincoln.tsv
    bin/combine.rb lincoln.tsv hamlet.tsv
    bin/combine.rb *.tsv

would produce identical output (assuming only two inputs).  This produces consistent output without sorting the transcript segments themselves which might be undesirable.  Finally, the inputs can be different formats, but they must be consistent, where consistency here means having the same fields.  For example, combining TSVs that have a different number of columns will fail, even if they might seem compatible.  This is a safeguard against combining transcripts that are truly incompatible by accident; the user must take extra steps to create consistency.  See section ...

