/*
  srcMLTranslatorOutput.hpp

  Copyright (C) 2003-2013  SDML (www.srcML.org)

  This file is part of the srcML Toolkit.

  The srcML Toolkit is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  The srcML Toolkit is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with the srcML Toolkit; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

/*
  XML output
*/

#ifndef SRCMLTRANSLATOROUTPUT_HPP
#define SRCMLTRANSLATOROUTPUT_HPP

#include <iostream>
#include "antlr/Token.hpp"
#include <antlr/TokenStream.hpp>
#include "StreamMLParser.hpp"
#include "TokenStream.hpp"
#include "Options.hpp"
#include "srcMLException.hpp"
#include "srcMLOutput.hpp"
#include <libxml/xmlwriter.h>

#include <string>

class srcMLTranslatorOutput : public srcMLOutput {

public:
    // constructor
    srcMLTranslatorOutput(TokenStream* ints,
                          const char* srcml_filename,
                          const char* language,
                          const char* encoding,
                          OPTION_TYPE& option,
                          const char* uri[],
                          int tabsize,
                          xmlBuffer* output_buffer = 0,
                          xmlTextWriterPtr writer = 0,
                          std::string * suri = 0
        );

    void setMacroList(std::vector<std::string> list);

    static bool checkEncoding(const char* encoding);

    // same srcml file can be generated from multiple input token streams
    void setTokenStream(TokenStream& ints);

    // start a unit element with the passed metadata
    void startUnit(const char* unit_language,
                   const char* unit_directory, const char* unit_filename, const char* unit_version, bool outer);

    // consume the entire tokenstream with output of srcml
    void consume(const char* language, const char* unit_directory, const char* unit_filename, const char* unit_version = "");

    // destructor
    ~srcMLTranslatorOutput();

private:

    int consume_next();

    inline const char* type2name(int token_type) const;

    inline const char* token2name(const antlr::RefToken& token) const;

    void outputToken(const antlr::RefToken& token);

    void outputNamespaces(xmlTextWriterPtr xout, const OPTION_TYPE& options, int depth, bool outer);

    std::vector<std::string> user_macro_list;

    // List of element names
    static const char* const ElementNames[];
    static int ElementPrefix[];

public:

    // handler for optional literal tokens
    void processOptional(const antlr::RefToken& token, const char* attr_name, const char* attr_value);

    // token handlers
    void processAccess(const antlr::RefToken& token);
    void processToken(const antlr::RefToken& token);
    void processTag(const antlr::RefToken& token);
    void processBlockCommentStart(const antlr::RefToken& token);
    void processJavadocCommentStart(const antlr::RefToken& token);
    void processDoxygenCommentStart(const antlr::RefToken& token);
    void processLineDoxygenCommentStart(const antlr::RefToken& token);
    void processLineCommentStart(const antlr::RefToken& token);
    void processEndBlockToken(const antlr::RefToken& token);
    void processEndLineToken(const antlr::RefToken& token);
#if DEBUG
    void processMarker(const antlr::RefToken& token);
#endif
    void processString(const antlr::RefToken& token);
    void processChar(const antlr::RefToken& token);
    void processLiteral(const antlr::RefToken& token);
    void processBoolean(const antlr::RefToken& token);
    void processInterface(const antlr::RefToken& token);
    void processEscape(const antlr::RefToken& token);

    // method pointer for token processing dispatch
    typedef void (srcMLTranslatorOutput::*PROCESS_PTR)(const antlr::RefToken & );

private:
    // table of method pointers for token processing dispatch
    static char process_table[];
    static srcMLTranslatorOutput::PROCESS_PTR num2process[];
};

#endif
