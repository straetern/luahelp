# Interactive manual search for Lua

The [Lua Reference Manual](https://www.lua.org/manual/) is impressive in the sense that it fits on a single web page including the complete Lua syntax in BNF form at the end. But while learning the language I found myself constantly switching back and forth between the terminal program and the browser. This got a bit tedious especially when I had to check for version changes of specific functions of which there are quite a few.

To make my development more fluent, I wrote this help function to be used inside the interactive interpreter and to allow me to search for changes between versions more easily. To speed up and simplify the search, the web manual is not searched directly, but the 'make' subcommand must be used to create a lua module from the web manual containing a table which represents the structure of the web manual (using the HTML heading levels). A separate module can be produced for each version of the language, making them available in the help function (via the help_config.lua file).

The interactive help can be started in 2 ways: either directly using "lua help.lua <words>", or inside the interpreter using "help = require('help')"; in the latter case, the user can choose his own name for the help function (here it is just 'help').

The function is used like this: help(word1, word2, ..) or shorter: help'word1 word2 ..'
With no arguments, a usage description is returned.
In the second form, space in a word can be given using a hyphen. If more than one word is given, they are only matched in the same sentence.
Sections with matches are listed with their titles highlighted in cyan and the following partial text has the matches highlighted in red. Each section title is preceded by a count and followed by the manual part ('main','basic' or 'lib', meaning the language itself or the library) and the version number (eg. '52' = 5.2). 

At the help prompt, one can then either:
  - press Return to scroll down to further matched sections,
  - input words to do another search,
  - input the count number to view the complete text of the numbered section,
  - input 'v' to show loaded manual versions: the default version and, if other versions are loaded, the alternate version,
  - input 'v <word>' to search the alternate version instead of the default,
  - input 'q' or 'quit' to return to the interpreter or command line.

The parsing of the web manual makes a number of assumptions specific to the type of Html used in the Lua manual, it could probably not be used for other Html text. I made one short test with another human language version of the manual which worked, but mainly this was tested with the English version and also Lua versions 5.1 and 5.2.

The code uses a coroutine to feed text matches into the pager, I think this was an elegant solution and the first time for me with coroutines.

The last update of this code was 2015, I did not have this under version control, so I'm just adding the files here.
  
I want to thank the Lua project for creating the beautiful simple language with its flowing functional style, I've certainly had a lot of fun with it!
 
