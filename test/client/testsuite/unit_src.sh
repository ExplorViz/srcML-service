#!/bin/bash

# test framework
source $(dirname "$0")/framework_test.sh


define nestedfile <<- 'STDOUT'
	<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
	<unit xmlns="http://www.srcML.org/srcML/src" revision="REVISION">

	<unit xmlns:cpp="http://www.srcML.org/srcML/cpp" revision="REVISION" language="C++" filename="sub/a.cpp" hash="1a2c5d67e6f651ae10b7673c53e8c502c97316d6">
	<expr_stmt><expr><name>a</name></expr>;</expr_stmt>
	</unit>

	<unit xmlns:cpp="http://www.srcML.org/srcML/cpp" revision="REVISION" language="C++" filename="sub/b.cpp" hash="aecf18b52d520ab280119febd8ff6c803135ddfc">
	<expr_stmt><expr><name>b</name></expr>;</expr_stmt>
	</unit>

	</unit>
  STDOUT

define nestedfilesrc <<- 'STDOUT'
	<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
	<src:unit xmlns:src="http://www.srcML.org/srcML/src">

	<src:unit xmlns:cpp="http://www.srcML.org/srcML/cpp" revision="REVISION" language="C++" filename="sub/a.cpp" hash="1a2c5d67e6f651ae10b7673c53e8c502c97316d6">
	<src:expr_stmt><src:expr><src:name>a</src:name></src:expr>;</src:expr_stmt>
	</src:unit>

	<src:unit xmlns:cpp="http://www.srcML.org/srcML/cpp" revision="REVISION" language="C++" filename="sub/b.cpp" hash="aecf18b52d520ab280119febd8ff6c803135ddfc">
	<src:expr_stmt><src:expr><src:name>b</src:name></src:expr>;</src:expr_stmt>
	</src:unit>

	</src:unit>
  STDOUT

xmlcheck "$nestedfile"
xmlcheck "$nestedfilesrc"

# Deprecated warning message
define deprecated_warning <<- 'STDERR'
	WARNING srcml: use of option --units or -n is deprecated
STDERR

# test
srcml2src --units <<< "$nestedfile"
checkv2 "2" "$deprecated_warning"

srcml2src --units <<< "$nestedfilesrc"
checkv2 "2" "$deprecated_warning"

srcml2src -U "1" <<< "$nestedfile"
checkv2 $'\na;\n'

srcml2src --unit "1" <<< "$nestedfile"
checkv2 $'\na;\n'

srcml2src --unit="1" <<< "$nestedfile"
checkv2 $'\na;\n'

srcml2src -U "2" <<< "$nestedfile"
checkv2 $'\nb;\n'

srcml2src --unit "2" <<< "$nestedfile"
checkv2 $'\nb;\n'

srcml2src --unit="2" <<< "$nestedfile"
checkv2 $'\nb;\n'
