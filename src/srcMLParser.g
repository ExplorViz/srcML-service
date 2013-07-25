/*
  srcMLParser.g

  Copyright (C) 2004-2012  SDML (www.sdml.info)

  This file is part of the srcML translator.

  The srcML translator is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  The srcML translator is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with the srcML translator; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  Comments:

  This is an ANTLR grammar file for the main part of the srcML translator.
  It is a mixture of ANTLR code with C++ code mixed in for the actions.

  The grammar is for the C++ language.  It is unlike typical C++ parsers for many
  reasons:
  
  - ANTLR uses this code to generate a recursive-descent LL(k) parser.  This
  parser starts at the leftmost token and tries to match the tokens to C++
  source code.

  - Additional classes are used to implement an event-driven parser.  Input
  to the parser is a stream of tokens from the lexer.  Output from this parser
  is a new stream of tokens.  The parser user calls nextToken repeatedly to
  process all of the tokens.

  - The parser is designed to be used interactively.  When the nextToken is
  called a minimal number of input tokens are read to generate an output token.
  This makes the parser very responsive and able to issue start statement
  tokens before the end of the statement is reached.

  - The parser insert additional tokens into the input stream corresponding to
  start and end tags.

  Matching:

  - The parser does not attempt to detect invalid C++ code.  It is designed to
  match well-formed C++ code.  It assumes that the input C++ code is valid.

  - Whitespace and comments are handled in StreamMLParser.  They are diverted
  from the input token stream and inserted into the output token stream.  There
  is some processing to match these skipped tokens with the generated tokens
  from the parser.

  - There is no symbol table.  I repeat:  There is no symbol table.  No
  grammar rules are based on the type of an identifier.

  - Keywords are used to identify statements.  They are not used for types.
  Type keywords are in tokens just like other identifiers.

  Implementation:

  - The state of the current parsing is stored in modes.  The modes use flags
  to remember what state the parsing was in during the previous parse.

  - Element start tokens are generated using the method startElement.  The
  starting elements are stored in a stack in the current mode.

  - Element end tokens are generated automatically when a mode ends.  The stack
  of start tokens is popped of and ended automatically.

  - Do not end an element explicitly.  End the mode instead.

  Helpers:

  - The class StreamParser provides stream processing.  The class StreamMLParser
  provides markup language stream processing.  These are template classes which
  use this parser as a template parameter base.

  - The class TokenParser provides the virtual table for methods in StreamParser
  that are called in this parser.

  - Obviously this needs to be untangled but is not as easy as it should be.

  - Additional methods for the parser are declared in class Mode.  These methods
  only provide general support for the parser.  They do not, repeat, do not, contain
  token specific processing.

  Terminology:

  The use of C++ terminology is sometimes contradictory.  This is especially true
  for declarations and definitions, since a definition can also serve as a
  declaration.  The following rules are used:

  declaration - stating that something exists:

      function declaration:  int f();
      class declaration:     class A;
      struct declaration:    struct A;
      union declaration:     union A;
      method declaration:    virtual int f(); // in class

  definition - defining the layout or interface

      function definition:  int f() {}
      class definition:     class A { int a; }
      struct definition:    struct A { int a; }
      union definition:     union A { int a; }
      method definition:    int A::f() {} // in or out of class

  C vs. C++

  Additional keywords in C++ may be identifiers in C.  This is handled in the
  lexer which has symbols for all C++ (and C) keywords, but only will find them in
  the input if in C++ mode.  They are matched as NAME in C mode.
*/

header {
}

// Included in the generated srcMLParser.hpp file after antlr includes
header "post_include_hpp" {

#include <iostream>
#include <iomanip>
#include <stack>
#include "Mode.hpp"
#include "Options.hpp"

// Macros to introduce trace statements
#define ENTRY_DEBUG //RuleDepth rd(this); fprintf(stderr, "TRACE: %d %d %d %5s%*s %s (%d)\n", inputState->guessing, LA(1), ruledepth, (LA(1) != 11 ? LT(1)->getText().c_str() : "\\n"), ruledepth, "", __FUNCTION__, __LINE__);
#define CATCH_DEBUG //marker();

#define assertMode(m)

enum DECLTYPE { NONE, VARIABLE, FUNCTION, CONSTRUCTOR, DESTRUCTOR, SINGLE_MACRO, NULLOPERATOR, DELEGATE_FUNCTION, ENUM_DECL, GLOBAL_ATTRIBUTE, PROPERTY_ACCESSOR, PROPERTY_ACCESSOR_DECL };
enum CALLTYPE { NOCALL, CALL, MACRO };

// position in output stream
struct TokenPosition {

    TokenPosition()
        : token(0), sp(0) {}

    TokenPosition(antlr::RefToken* p_token, int* p_sp)
        : token(p_token), sp(p_sp) {}

    // sets a particular token in the output token stream
    void setType(int type) {

        // set the inner name token to type
        (*token)->setType(type);

        // set this position in the element stack to type
        *sp = type;
    }

    ~TokenPosition() {
    }

    antlr::RefToken* token;
    int* sp;
};

}

// Included in the generated srcMLParser.cpp file after antlr includes
header "post_include_cpp" {

    class CompleteElement {

     public:
     CompleteElement()
        : oldsize(masterthis->size())
     {}

     ~CompleteElement() {
         int n = masterthis->size() - oldsize;
         for (int i = 0; i < n; ++i) {
           masterthis->endCurrentMode();
         }
     }

     public:
       static srcMLParser* masterthis;

     private:
       const int oldsize;
    };

    class RuleDepth {

     public:
     RuleDepth(srcMLParser* t) : pparser(t) { ++pparser->ruledepth; }
     ~RuleDepth() { --pparser->ruledepth; }

     private:
       srcMLParser* pparser;
    };

    srcMLParser* CompleteElement::masterthis;

srcMLParser::srcMLParser(antlr::TokenStream& lexer, int lang, int parser_options)
   : antlr::LLkParser(lexer,1), Mode(this, lang), cpp_zeromode(false), skipelse(false), cppifcount(0), parseoptions(parser_options), ifcount(0), ruledepth(0), notdestructor(false)

{
    CompleteElement::masterthis = this;

    // root, single mode
    if (isoption(parseoptions, OPTION_EXPRESSION))
        // root, single mode to allows for an expression without a statement
        startNewMode(MODE_TOP | MODE_STATEMENT | MODE_EXPRESSION | MODE_EXPECT);
    else
       // root, single mode that allows statements to be nested
       startNewMode(MODE_TOP | MODE_NEST | MODE_STATEMENT);
}

// ends all currently open modes
void srcMLParser::endAllModes() {

     // expression mode has an extra mode
     if (isoption(parseoptions, OPTION_EXPRESSION))
        endCurrentMode();

     // should only be one mode
     if (size() > 1 && isoption(parseoptions, OPTION_DEBUG))
        emptyElement(SERROR_MODE);

    // end all modes except the last
    while (size() > 1) {
        endCurrentMode();
    }

    // flush any skipped characters
    flushSkip();

    // end the very last mode which forms the entire unit
    if (size() == 1)
        endLastMode();
}

}

options {
	language="Cpp";
    namespaceAntlr="antlr";
    namespaceStd="std";
}

class srcMLParser extends Parser;

options {
    classHeaderSuffix="public Mode";
	k=1;
    importVocab=KeywordCPPLexer;
    defaultErrorHandler=false;
    noConstructors=true;

    // values arrived at through experimentation
    codeGenBitsetTestThreshold=4;
    codeGenMakeSwitchThreshold=5;
}

tokens {
    // entire source file
    SUNIT;

    // First token used for boundary
    START_ELEMENT_TOKEN;

    // No output at all.  Only a placeholder
    SNOP;

    // literal types
    SSTRING;        // string marked by double quotes
    SCHAR;          // string or char marked by single quotes
    SLITERAL;       // literal number, constant
    SBOOLEAN;       // boolean literal, i.e., true, false

    // operators
    SOPERATOR;

    // type modifiers
    SMODIFIER;

    // internal statement elements used in multiple statements
    SNAME;
    SONAME;
    SCNAME;
    STYPE;
	SCONDITION;
	SBLOCK;
    SINDEX;

    // statements
	STYPEDEF;
	SENUM;
	SASM;
	SMACRO_CALL;

	SIF_STATEMENT;
	STHEN;
	SELSE;

    SWHILE_STATEMENT;
    SLOCK_STATEMENT;
    SFIXED_STATEMENT;
	SDO_STATEMENT;

	SFOR_STATEMENT;
	SFOREACH_STATEMENT;
    SFOR_GROUP;
	SFOR_INITIALIZATION;
	SFOR_CONDITION;
	SFOR_INCREMENT;

	SEXPRESSION_STATEMENT;
	SEXPRESSION;
	SFUNCTION_CALL;

	SDECLARATION_STATEMENT;
	SDECLARATION;
	SDECLARATION_INITIALIZATION;
	SDECLARATION_RANGE;

	SGOTO_STATEMENT;
	SCONTINUE_STATEMENT;
	SBREAK_STATEMENT;
	SLABEL_STATEMENT;

	SSWITCH;
	SCASE;
	SDEFAULT;

    // functions
    SFUNCTION_DEFINITION;
	SFUNCTION_DECLARATION;
	SFUNCTION_SPECIFIER;
	SRETURN_STATEMENT;
	SPARAMETER_LIST;
	SPARAMETER;
	SKRPARAMETER_LIST;
	SKRPARAMETER;
	SARGUMENT_LIST;
	SARGUMENT;

    // class, struct, union
	SCLASS;
	SCLASS_DECLARATION;
	SSTRUCT;
	SSTRUCT_DECLARATION;
	SUNION;
	SUNION_DECLARATION;
	SDERIVATION_LIST;
	SPUBLIC_ACCESS;
	SPUBLIC_ACCESS_DEFAULT;
	SPRIVATE_ACCESS;
	SPRIVATE_ACCESS_DEFAULT;
	SPROTECTED_ACCESS;
    SMEMBER_INITIALIZATION_LIST;
	SCONSTRUCTOR_DEFINITION;
	SCONSTRUCTOR_DECLARATION;
	SDESTRUCTOR_DEFINITION;
	SDESTRUCTOR_DECLARATION;
	SFRIEND;
	SCLASS_SPECIFIER;

    // extern definition
    SEXTERN;

    // namespaces
	SNAMESPACE;
	SUSING_DIRECTIVE;

    // exception handling
	STRY_BLOCK;
	SCATCH_BLOCK;
	SFINALLY_BLOCK;
	STHROW_STATEMENT;
	STHROW_SPECIFIER;
	STHROW_SPECIFIER_JAVA;

	STEMPLATE;
    STEMPLATE_ARGUMENT;
    STEMPLATE_ARGUMENT_LIST;
    STEMPLATE_PARAMETER;
    STEMPLATE_PARAMETER_LIST;

    // cpp internal elements
	SCPP_DIRECTIVE;
    SCPP_FILENAME;

    // cpp directives
	SCPP_ERROR;
	SCPP_PRAGMA;
	SCPP_INCLUDE;
	SCPP_DEFINE;
	SCPP_UNDEF;
	SCPP_LINE;
	SCPP_IF;
	SCPP_IFDEF;
	SCPP_IFNDEF;
	SCPP_THEN;
	SCPP_ELSE;
	SCPP_ELIF;

    // C# cpp directive
    SCPP_REGION;
    SCPP_ENDREGION;

    // This HAS to mark the end of the CPP directives
	SCPP_ENDIF;

    SMARKER;
    SERROR_PARSE;
    SERROR_MODE;

    // Java elements
    SIMPLEMENTS;
    SEXTENDS;
    SIMPORT;
    SPACKAGE;
    SINTERFACE;

    // C++0x elements
    SAUTO;

    // C#
    SCHECKED_STATEMENT;
    SUNCHECKED_STATEMENT;
    SATTRIBUTE;
    STARGET;
    SUNSAFE_STATEMENT;

    // misc
    SEMPTY;  // empty statement

    SLINQ;
    SFROM;
    SWHERE;
    SSELECT;
    SLET;
    SORDERBY;
    SJOIN;
    SGROUP;
    SIN;
    SON;
    SEQUALS;
    SBY;
    SINTO;

    // Last token used for boundary
    END_ELEMENT_TOKEN;
}

/*
  Included inside of generated class srcMLCPPParser.hpp
*/
{
public:

friend class CompleteElement;

bool cpp_zeromode;
bool skipelse;
int cppifcount;
bool isdestructor;
int parseoptions;
std::string namestack[2];
int ifcount;
int ruledepth;
bool qmark;
bool notdestructor;

~srcMLParser() {}

srcMLParser(antlr::TokenStream& lexer, int lang = LANGUAGE_CXX, int options = 0);

struct cppmodeitem {
        cppmodeitem(int current_size)
            : statesize(1, current_size), isclosed(false), skipelse(false)
        {}

        cppmodeitem()
        {}

        std::vector<int> statesize;
        bool isclosed;
        bool skipelse;
};

std::stack<cppmodeitem, std::list<cppmodeitem> > cppmode;

void startUnit() {

   startElement(SUNIT);
   emptyElement(SUNIT);
}

// sets to the current token in the output token stream
void setTokenPosition(TokenPosition& tp) {
        tp.token = CurrentToken();
        tp.sp = &(currentState().callstack.top());
}

public:

void endAllModes();

}


/*
  start

  Called by nextToken for the smallest amount of parsing to produce a token.
  Extra tokens are buffered in the stream parser.  Any token here can start
  an element or cause the end of an element.

  Whitespace tokens are handled elsewhere and are automagically included
  in the output stream.

  Order of evaluation is important.
*/
start[] { ruledepth = 0; ENTRY_DEBUG } :

        COMMENT_TEXT |

        // end of file
        eof |

        // end of line
        line_continuation | EOL | LINECOMMENT_START |

        comma |

        { !inTransparentMode(MODE_INTERNAL_END_PAREN) || inPrevMode(MODE_CONDITION) }? rparen[false] |

        // characters with special actions that usually end currently open elements
        { !inTransparentMode(MODE_INTERNAL_END_CURLY) }? block_end |

        // switch cases @test switch
        { !inMode(MODE_DERIVED) && !inMode(MODE_INIT) && (!inMode(MODE_EXPRESSION) || inTransparentMode(MODE_DETECT_COLON)) }? 
        colon |

        terminate |

        // don't confuse with expression block
        { inTransparentMode(MODE_CONDITION) ||
            (!inMode(MODE_EXPRESSION) && !inMode(MODE_EXPRESSION_BLOCK | MODE_EXPECT)) }? lcurly | 

        // process template operator correctly @test template
        { inTransparentMode(MODE_TEMPLATE_PARAMETER_LIST) }? tempope |

        // special default() call for C#
        { LA(1) == DEFAULT && inLanguage(LANGUAGE_CSHARP) && inTransparentMode(MODE_EXPRESSION) }? (DEFAULT LPAREN)=> expression_part_default |

        // context-free grammar statements
        { inMode(MODE_NEST | MODE_STATEMENT) && !inMode(MODE_FUNCTION_TAIL) }? cfg |

        // statements without a context free grammar
        // last chance to match to a syntactical structure
        { inMode(MODE_NEST | MODE_STATEMENT) && !inMode(MODE_FUNCTION_TAIL) }? statements_non_cfg |

        // in the middle of a statement
        statement_part
;
exception
catch[...] {

        CATCH_DEBUG

        // need to consume the token. If we got here because
        // of an error with EOF token, then call EOF directly
        if (LA(1) == 1)
            eof();
        else
            consume();
}

/*
  context-free grammar statements
*/
cfg[] { ENTRY_DEBUG } :

        // conditional statements
        if_statement | else_statement | switch_statement | switch_case | switch_default |

        // iterative statements
        while_statement | for_statement | do_statement | foreach_statement |

        // jump statements
        return_statement | break_statement | continue_statement | goto_statement |

        // template declarations - both functions and classes
        template_declaration |

        // exception statements
        try_statement | catch_statement | finally_statement | throw_statement |

        // namespace statements
        namespace_definition | { inLanguage(LANGUAGE_CSHARP) }? (USING LPAREN)=> using_statement | namespace_directive |

        typedef_statement |

        // java import - keyword only detected for Java
        import_statement |

        // java package - keyword only detected for Java
        package_statement |

        // C#
        checked_statement | /* { inLanguage(LANGUAGE_CSHARP) }? attribute | */

        unchecked_statement | lock_statement | fixed_statement | /* property_method | */ unsafe_statement |

        // assembly block
        asm_declaration
;

/*
  statements non cfg

  Top-level items that must be matched by context.

  Basically we have an identifier and we don't know yet whether it starts an expression
  function definition, function declaration, or even a label.

  Important to keep semantic checks, e.g., (constructor)=>, in place.  Most of these rules
  can start with a name which leaves it ambiguous which to choose.
*/
statements_non_cfg[] { int token = 0; int place = 0; int secondtoken = 0; int fla = 0;
        int type_count = 0; DECLTYPE decl_type = NONE; CALLTYPE type = NOCALL; ENTRY_DEBUG } :

        // don't ask
        (yield_return_statement)=> yield_return_statement |

        // don't ask
        (yield_break_statement)=> yield_break_statement |

        // class forms for class declarations/definitions as opposed to part of a declaration types
        // must be before checking access_specifier_region
        (class_struct_union_check[token /* token after header */, place])=> class_struct_union[token, place] |

        // class forms sections
        // must be after class_struct_union_check
        { inLanguage(LANGUAGE_CXX_ONLY) }?
        access_specifier_region |

        // check for declaration of some kind (variable, function, constructor, destructor
        { perform_noncfg_check(decl_type, secondtoken, fla, type_count) && decl_type == FUNCTION }?
        function[fla, type_count] |

        { decl_type == GLOBAL_ATTRIBUTE }?
        attribute |

        { decl_type == PROPERTY_ACCESSOR }?
        property_method |

        { decl_type == PROPERTY_ACCESSOR_DECL }?
        property_method_decl |

        // "~" which looked like destructor, but isn't
        { decl_type == NONE }?
        expression_statement_process
        expression_process
        sole_destop |

        // standalone macro
        { decl_type == SINGLE_MACRO }?
        macro_call |

        // standalone macro
        { decl_type == DELEGATE_FUNCTION }?
        delegate_anonymous |

        // variable declaration
        { decl_type == VARIABLE }?
        variable_declaration_statement[type_count] |

        // constructor
        { decl_type == CONSTRUCTOR && fla != TERMINATE }?
        constructor_definition |

        { decl_type == CONSTRUCTOR && fla == TERMINATE }?
        constructor_declaration |

        // destructor
        { decl_type == DESTRUCTOR && fla != TERMINATE }?
        destructor_definition |

        // destructor declaration restrained so that it can only occur within a class
        {(inTransparentMode(MODE_CLASS) && !inTransparentMode(MODE_FUNCTION_TAIL)) && decl_type == DESTRUCTOR && fla == TERMINATE }?
        destructor_declaration |

        // labels to goto
        { secondtoken == COLON }? label_statement |

        // extern block as opposed to enum as part of declaration
        { decl_type == NONE && LA(1) != NEW }?
        extern_definition |

        // enum definition as opposed to part of type or declaration
        { decl_type == ENUM_DECL }?
        enum_definition |

        // call
        { inLanguage(LANGUAGE_C_FAMILY) && perform_call_check(type, secondtoken) && type == MACRO }?
        macro_call |

        expression_statement[type]
;


look_past[int skiptoken] returns [int token] {
    
    int place = mark();
    inputState->guessing++;

    while (LA(1) != antlr::Token::EOF_TYPE && LA(1) == skiptoken)
        consume();

    token = LA(1);

    inputState->guessing--;
    rewind(place);
}:;

look_past_multiple[int skiptoken1, int skiptoken2, int skiptoken3, int skiptoken4] returns [int token] {
    
    int place = mark();
    inputState->guessing++;

    while (LA(1) != antlr::Token::EOF_TYPE && (LA(1) == skiptoken1 || LA(1) == skiptoken2 || LA(1) == skiptoken3 || (inLanguage(LANGUAGE_CSHARP && LA(1) == skiptoken4))))
        consume();

    token = LA(1);

    inputState->guessing--;
    rewind(place);
}:;

// functions
function[int token, int type_count] { ENTRY_DEBUG } :
		{
            // function definitions have a "nested" block statement
            startNewMode(MODE_STATEMENT);

            if (token != LCURLY)
                startElement(SFUNCTION_DECLARATION);
            else
                // start the function definition element
                startElement(SFUNCTION_DEFINITION);
        }
        function_header[type_count]
;

// functions
property_method[] { ENTRY_DEBUG } :
		{
            // function definitions have a "nested" block statement
            startNewMode(MODE_STATEMENT);

            // start the function definition element
            startElement(SFUNCTION_DEFINITION);
        }
        ({ inLanguage(LANGUAGE_CSHARP) }? attribute)* property_method_names
;

// functions
property_method_decl[] { ENTRY_DEBUG } :
		{
            // function definitions have a "nested" block statement
            startNewMode(MODE_STATEMENT);

            // start the function definition element
            startElement(SFUNCTION_DECLARATION);
        }
        ({ inLanguage(LANGUAGE_CSHARP) }? attribute)* property_method_names
;

// functions
property_method_names[] { CompleteElement element; ENTRY_DEBUG } :
		{
            startNewMode(MODE_LOCAL);

            startElement(SNAME);
        }
        (GET | SET | ADD | REMOVE)
;

perform_call_check[CALLTYPE& type, int secondtoken] returns [bool iscall] {

    iscall = true;

    type = NOCALL;

    int start = mark();
    inputState->guessing++;

    int postnametoken = 0;
    int argumenttoken = 0;
    int postcalltoken = 0;
    try {
        call_check(postnametoken, argumenttoken, postcalltoken);

        guessing_endGuessing();

        // call syntax succeeded
        type = CALL;

        // call syntax succeeded, however post call token is not legitimate
        if (inLanguage(LANGUAGE_C_FAMILY) && (_tokenSet_1.member(postcalltoken) || postcalltoken == NAME 
            || (!inLanguage(LANGUAGE_CSHARP) && postcalltoken == LCURLY)
            || postcalltoken == EXTERN || postcalltoken == STRUCT || postcalltoken == UNION || postcalltoken == CLASS
            || (!inLanguage(LANGUAGE_CSHARP) && postcalltoken == RCURLY)
            || postcalltoken == 1 /* EOF ? */
            || postcalltoken == TEMPLATE || postcalltoken == PUBLIC || postcalltoken == PRIVATE
            || postcalltoken == PROTECTED
            || postcalltoken == STATIC))

            type = MACRO;

    } catch (...) {

        type = NOCALL;

        if (inLanguage(LANGUAGE_C_FAMILY) && argumenttoken != 0 && postcalltoken == 0) {

            guessing_endGuessing();

            type = MACRO;
        }

        // single macro call followed by statement_cfg
        else if (inLanguage(LANGUAGE_C_FAMILY) && secondtoken != -1
                 && (_tokenSet_1.member(secondtoken) || secondtoken == LCURLY || secondtoken == 1 /* EOF */
                     || secondtoken == PUBLIC || secondtoken == PRIVATE || secondtoken == PROTECTED))

            type = MACRO;
    }

    inputState->guessing--;
    rewind(start);
ENTRY_DEBUG } :
;

call_check[int& postnametoken, int& argumenttoken, int& postcalltoken] { ENTRY_DEBUG } :

        // detect name, which may be name of macro or even an expression
        function_identifier

        // record token after the function identifier for future use if this
        // fails
        markend[postnametoken]

       (
        { inLanguage(LANGUAGE_C_FAMILY) }?
        // check for proper form of argument list
        call_check_paren_pair[argumenttoken]

        guessing_endGuessing

        // record token after argument list to differentiate between call and macro
        markend[postcalltoken] |

        LPAREN
       )
;

call_check_paren_pair[int& argumenttoken, int depth = 0] { bool name = false; ENTRY_DEBUG } :

        LPAREN

        // record token after the start of the argument list
        markend[argumenttoken]

        ( options { greedy = true; } : 

            // recursive nested parentheses
            call_check_paren_pair[argumenttoken, depth + 1] set_bool[name, false] | 

            // special case for something that looks like a declaration
            { !name || (depth > 0) }?
            identifier set_bool[name, true] |

            // special case for something that looks like a declaration
            delegate_anonymous | 

            (LAMBDA (LCURLY | LPAREN)) =>
            lambda_anonymous | 

//            { inLanguage(LANGUAGE_CSHARP) }?
//            DEFAULT |

            // found two names in a row, so this is not an expression
            // cause this to fail by next matching END_ELEMENT_TOKEN
            { name && (depth == 0) }?
            identifier guessing_endGuessing END_ELEMENT_TOKEN |

            // forbid parentheses (handled recursively) and cfg tokens
            { !_tokenSet_1.member(LA(1)) }? ~(LPAREN | RPAREN | TERMINATE) set_bool[name, false]
        )* 

        RPAREN
;

markend[int& token] { token = LA(1); } :
;

/* Statements CFG */

/*
  while statement, or while part of do statement
*/
while_statement[] { ENTRY_DEBUG } :
        {
            // statement with nested statement (after condition)
            startNewMode(MODE_STATEMENT | MODE_NEST);

            // start the while element
            startElement(SWHILE_STATEMENT);

            // expect a condition to follow the keyword
            startNewMode(MODE_CONDITION | MODE_EXPECT);
        }      
        WHILE 
;

/*
 do while statement
*/
do_statement[] { ENTRY_DEBUG } : 
        {
            // statement with nested statement (after condition)
            // set to top mode so that end of block will
            // not end statement itself
            startNewMode(MODE_STATEMENT | MODE_TOP | MODE_DO_STATEMENT);

            // start of do statement
            startElement(SDO_STATEMENT);

            // mode to nest while part of do while statement
            startNewMode(MODE_NEST | MODE_STATEMENT);
        }
        DO
;

/*
  while part of do statement
*/
do_while[] { ENTRY_DEBUG } :
        {
            // mode for do statement is in top mode so that
            // end of the block will not end the statement
            clearMode(MODE_TOP);

            // expect a condition to follow
            startNewMode(MODE_CONDITION | MODE_EXPECT);
        }
        WHILE 
;

/*
  start of for statement
*/
for_statement[] { ENTRY_DEBUG } :
        {
            // statement with nested statement after the for group
            startNewMode(MODE_STATEMENT | MODE_NEST);

            // start the for statement
            startElement(SFOR_STATEMENT);
        }
        FOR
        {
            // statement with nested statement after the for group
            startNewMode(MODE_EXPECT | MODE_FOR_GROUP);
        }
;

/*
  start of foreach statement (C#)
*/
foreach_statement[] { ENTRY_DEBUG } :
        {
            // statement with nested statement after the for group
            startNewMode(MODE_STATEMENT | MODE_NEST);

            // start the for statement
            startElement(SFOREACH_STATEMENT);
        }
        FOREACH
        {
            // statement with nested statement after the for group
            startNewMode(MODE_EXPECT | MODE_FOR_GROUP);
        }
;

/*
  start of for group, i.e., initialization, test, increment
*/
for_group[] { ENTRY_DEBUG } :
        {
            // start the for group mode that will end at the next matching
            // parentheses
            replaceMode(MODE_FOR_GROUP, MODE_TOP | MODE_FOR_INITIALIZATION | MODE_IGNORE_TERMINATE |
                        MODE_INTERNAL_END_PAREN | MODE_LIST);

            // start the for heading group element
            startElement(SFOR_GROUP);
        }
        LPAREN
;

/*
  for parameter list initialization
*/
for_initialization_action[] { ENTRY_DEBUG } :
        {
            assertMode(MODE_FOR_INITIALIZATION | MODE_EXPECT);

            // setup next stage for condition in the for group mode
            replaceMode(MODE_FOR_INITIALIZATION, MODE_FOR_CONDITION);

            // setup a mode for initialization that will end with a ";"
            startNewMode(MODE_EXPRESSION | MODE_EXPECT | MODE_STATEMENT | MODE_LIST);

            startElement(SFOR_INITIALIZATION);
        }
    ;

for_initialization[] { int type_count = 0; int fla = 0; int secondtoken = 0; DECLTYPE decl_type = NONE; ENTRY_DEBUG } :
        for_initialization_action
        (
            // explicitly check for a variable declaration since it can easily
            // be confused with an expression
            { perform_noncfg_check(decl_type, secondtoken, fla, type_count) && decl_type == VARIABLE }?
            for_initialization_variable_declaration[type_count] |
            
            // explicitly check for non-terminate so that a large switch statement
            // isn't needed
            expression
        )
;

/*
  Statement for the declaration of a variable or group of variables
  in a for initialization
*/
for_initialization_variable_declaration[int type_count] { ENTRY_DEBUG } :
        {
            // start a new mode for the expression which will end
            // inside of the terminate
            startNewMode(MODE_LIST);

            startElement(SDECLARATION);
        }
        variable_declaration[type_count]
;


/*
  for parameter list condition
*/
for_condition_action[] { ENTRY_DEBUG } :
        {
            assertMode(MODE_FOR_CONDITION | MODE_EXPECT);

            // setup next stage for condition
            replaceMode(MODE_FOR_CONDITION, MODE_FOR_INCREMENT | MODE_INTERNAL_END_PAREN | MODE_LIST);

            // setup a mode for initialization that will end with a ";"
            startNewMode(MODE_EXPRESSION | MODE_EXPECT | MODE_STATEMENT | MODE_LIST );

            startElement(SFOR_CONDITION);
        }
    ;

for_condition[] { ENTRY_DEBUG } :
        for_condition_action

        // non-empty condition
        expression
;

/*
  increment in for parameter list
*/
for_increment[] { ENTRY_DEBUG } :
        { 
            assertMode(MODE_EXPECT | MODE_FOR_INCREMENT);

            clearMode(MODE_EXPECT | MODE_FOR_INCREMENT);

            // setup a mode for initialization that will end with a ";"
            startNewMode(MODE_FOR_INCREMENT | MODE_EXPRESSION | MODE_EXPECT | MODE_STATEMENT | MODE_LIST);

            if (LA(1) == RPAREN)
                // empty increment issued as single element
                emptyElement(SFOR_INCREMENT);
            else
                startElement(SFOR_INCREMENT);
        }
        expression
;

/*
 start of if statement

 if statement is first processed here.  Then prepare for a condition.  The end of the
 condition will setup for the then part of the statement.  The end of the then looks
 ahead for an else.  If so, it ends the then part.  If not, it ends the entire statement.*/
if_statement[] { ENTRY_DEBUG } :
        {
            // statement with nested statement
            // detection of else
            startNewMode(MODE_STATEMENT | MODE_NEST | MODE_IF);

            ++ifcount;

            // start the if statement
            startElement(SIF_STATEMENT);

            // expect a condition
            // start THEN after condition
            startNewMode(MODE_EXPECT | MODE_CONDITION);
        }
        IF
;

/*
 else part of if statement

 else is detected on its own, and as part of termination (semicolon or
 end of a block
*/
else_statement[] { ENTRY_DEBUG } :
        {
            // treat as a statement with a nested statement
            startNewMode(MODE_STATEMENT | MODE_NEST | MODE_ELSE);

            // start the else part of the if statement
            startElement(SELSE);
        }
        ELSE
;

/*
 start of switch statement
*/
switch_statement[] { ENTRY_DEBUG } :
        {
            // statement with nested block
            startNewMode(MODE_STATEMENT | MODE_NEST);

            // start the switch statement
            startElement(SSWITCH);

            // expect a condition to follow
            startNewMode(MODE_CONDITION | MODE_EXPECT);
        }
        SWITCH 
;

/*
 actions to perform before starting a section

 There are no grammar rules to match.
*/
section_entry_action_first[] :
        {
            // start a new section inside the block with nested statements
            startNewMode(MODE_TOP_SECTION | MODE_TOP | MODE_NEST | MODE_STATEMENT);
        }
;

/*
 actions to perform before starting a section

 There are no grammar rules to match.
*/
section_entry_action[] :
        {
            // end any statements inside the section
            endDownToMode(MODE_TOP);

            // flush any whitespace tokens since sections should
            // end at the last possible place
            flushSkip();

            // end the section inside the block
            endDownOverMode(MODE_TOP_SECTION);
        }
        section_entry_action_first
;

/*
 Yes, case isn't really a statement, but it is treated as one
*/
switch_case[] { ENTRY_DEBUG } :
        // start a new section
        section_entry_action
        {
            // start of case element
            startElement(SCASE);

            // expect an expression ended by a colon
            startNewMode(MODE_EXPRESSION | MODE_EXPECT | MODE_DETECT_COLON);
        }
        CASE 
;

switch_default[] { ENTRY_DEBUG } :
        // start a new section
        section_entry_action
        {
            // start of case element
            startElement(SDEFAULT);

            // filler mode ended by the colon
            startNewMode(MODE_STATEMENT);
        }
        DEFAULT
;

/*
  start of return statement
*/
import_statement[] { ENTRY_DEBUG } :
        {
            // statement with a possible expression
            startNewMode(MODE_STATEMENT | MODE_VARIABLE_NAME | MODE_EXPECT);

            // start the return statement
            startElement(SIMPORT);
        }
        IMPORT
;

/*
  start of package statement
*/
package_statement[] { ENTRY_DEBUG } :
        {
            // statement with a possible expression
            startNewMode(MODE_STATEMENT | MODE_VARIABLE_NAME | MODE_EXPECT);

            // start the return statement
            startElement(SPACKAGE);
        }
        PACKAGE
;

/*
  start of return statement
*/
return_statement[] { ENTRY_DEBUG } :
        {
            // statement with a possible expression
            startNewMode(MODE_STATEMENT | MODE_EXPRESSION | MODE_EXPECT);

            // start the return statement
            startElement(SRETURN_STATEMENT);
        }
        RETURN
;

yield_specifier[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_LOCAL);

            // start the function specifier
            startElement(SFUNCTION_SPECIFIER);
        }
        YIELD
;

yield_return_statement[] { ENTRY_DEBUG } :
        {
            // statement with a possible expression
            startNewMode(MODE_STATEMENT | MODE_EXPRESSION | MODE_EXPECT);

            // start the return statement
            startElement(SRETURN_STATEMENT);
        }
        yield_specifier RETURN
;

/*
  start of break statement
*/
break_statement[] { ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_STATEMENT);

            // start the break statement
            startElement(SBREAK_STATEMENT);
        }
        BREAK
;

yield_break_statement[] { ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_STATEMENT);

            // start the break statement
            startElement(SBREAK_STATEMENT);
        }
        yield_specifier BREAK
;

/*
  start of continue statement
*/
continue_statement[] { ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_STATEMENT);

            // start the continue statement
            startElement(SCONTINUE_STATEMENT);
        }
        CONTINUE
;

/*
  start of goto statement
*/
goto_statement[] { ENTRY_DEBUG } :
        {
            // statement with an expected label name
            // label name is a subset of variable names
            startNewMode(MODE_STATEMENT | MODE_VARIABLE_NAME);

            // start the goto statement
            startElement(SGOTO_STATEMENT);
        }
        GOTO
;

/*
  Complete assembly declaration statement
*/
asm_declaration[] { ENTRY_DEBUG } : 
        {
            // statement
            startNewMode(MODE_STATEMENT);

            // start the asm statement
            startElement(SASM);
        }
        ASM
        (balanced_parentheses | ~(LCURLY | RCURLY | TERMINATE))*
;

/*
 Examples:
   namespace {}
   namespace name {}
   namespace name1 = name2;

 Past name handled as expression
*/
extern_definition[] { ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_STATEMENT | MODE_EXTERN);

            // start the namespace definition
            startElement(SEXTERN);
        }
        EXTERN
;

/*
  Name of extern section
*/
extern_name[] { ENTRY_DEBUG } :
        string_literal
        {
            // nest a block inside the namespace
            setMode(MODE_NEST | MODE_STATEMENT);
        }
;

/*
 Examples:
   namespace {}
   namespace name {}
   namespace name1 = name2;

 Past name handled as expression
*/
namespace_definition[] { ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_STATEMENT | MODE_NAMESPACE | MODE_VARIABLE_NAME);

            // start the namespace definition
            startElement(SNAMESPACE);
        }
        NAMESPACE
;

namespace_alias[] { ENTRY_DEBUG } :

        EQUAL 
        {
            // expect a label name
            // label name is a subset of variable names
            setMode(MODE_VARIABLE_NAME);
        }
;

namespace_block[] { ENTRY_DEBUG } :
        {
            // nest a block inside the namespace
            setMode(MODE_NEST | MODE_STATEMENT);
        }
        lcurly 
;

/*
  start of namespace using directive
*/
namespace_directive[] { ENTRY_DEBUG } :
        {
            // statement with an expected namespace name after the keywords
            startNewMode(MODE_LIST | MODE_VARIABLE_NAME | MODE_INIT | MODE_EXPECT | MODE_STATEMENT);
            //startNewMode(MODE_STATEMENT | MODE_FUNCTION_NAME);

            // start the using directive
            startElement(SUSING_DIRECTIVE);
        }
        USING
;

/* Declarations Definitions CFG */

/*
  class structures and unions
*/
class_struct_union[int token, int place] { ENTRY_DEBUG } :

        { token == LCURLY && place == INTERFACE }?
        interface_definition |

        { token == LCURLY && place == CLASS }?
        class_definition |

        { token == LCURLY && place == STRUCT }?
        struct_union_definition[SSTRUCT] |

        { token == LCURLY && place == UNION }?
        struct_union_definition[SUNION] |

        { place == CLASS }?
        class_declaration |

        { place == STRUCT }?
        struct_declaration |

        { place == UNION }?
        union_declaration
;

/*
  class structures and unions
*/
class_struct_union_check[int& finaltoken, int& othertoken] { finaltoken = 0; othertoken = 0; ENTRY_DEBUG } :

        ({ inLanguage(LANGUAGE_CSHARP) }? attribute)* (specifier)* markend[othertoken] (CLASS | STRUCT | UNION | INTERFACE) class_header check_end[finaltoken]
;

check_end[int& token] { token = LA(1); ENTRY_DEBUG } :
        LCURLY | TERMINATE | COLON | COMMA | RPAREN
;

/*
*/
class_declaration[] { ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_STATEMENT);

            // start the class definition
            startElement(SCLASS_DECLARATION);
        }
        ({ inLanguage(LANGUAGE_CSHARP) }? attribute)* (specifier)* CLASS class_header
;

/*
*/
class_preprocessing[int token] { ENTRY_DEBUG } :
        {
            bool intypedef = inMode(MODE_TYPEDEF);

            if (intypedef)
                startElement(STYPE);

            // statement
            startNewMode(MODE_STATEMENT | MODE_BLOCK | MODE_NEST | MODE_CLASS | MODE_DECL);

            // start the class definition
            startElement(token);

            // java classes end at the end of the block
            if (intypedef || inLanguage(LANGUAGE_JAVA_FAMILY) || inLanguage(LANGUAGE_CSHARP)) {
                setMode(MODE_END_AT_BLOCK);
            }
        }
;

class_definition[] { ENTRY_DEBUG } :
        class_preprocessing[SCLASS]

        ({ inLanguage(LANGUAGE_CSHARP) }? attribute)* (specifier)* CLASS (class_header lcurly | lcurly) 
        {
            if (inLanguage(LANGUAGE_CXX_ONLY))
                class_default_access_action(SPRIVATE_ACCESS_DEFAULT);
        }
;

enum_class_definition[] { ENTRY_DEBUG } :
        class_preprocessing[SENUM]

        ({ inLanguage(LANGUAGE_CSHARP) }? attribute)* (specifier)* ENUM (class_header lcurly | lcurly) 
        {
            if (inLanguage(LANGUAGE_CXX_ONLY))
                class_default_access_action(SPRIVATE_ACCESS_DEFAULT);
        }
;

anonymous_class_definition[] { ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_STATEMENT | MODE_BLOCK | MODE_NEST | MODE_CLASS | MODE_END_AT_BLOCK);

            // start the class definition
            startElement(SCLASS);

        }

        // first name in an anonymous class definition is the class it extends
        // or the interface that it implements
        anonymous_class_super 

        // argument list
        {
            // start a new mode that will end after the argument list
            startNewMode(MODE_ARGUMENT | MODE_LIST);
        }
        call_argument_list
;

anonymous_class_super[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_LOCAL);

            // start the super name of an anonymous class
            startElement(SDERIVATION_LIST);
        }
        complex_name[true]
;

interface_definition[] { ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_STATEMENT | MODE_BLOCK | MODE_NEST | MODE_CLASS);

            // start the interface definition
            startElement(SINTERFACE);

            // java interfaces end at the end of the block
            setMode(MODE_END_AT_BLOCK); 
        }
        ({ inLanguage(LANGUAGE_CSHARP) }? attribute)* (specifier)* INTERFACE class_header lcurly
;

/*
*/
struct_declaration[] { ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_STATEMENT);

            // start the class definition
            startElement(SSTRUCT_DECLARATION);
        }
        ({ inLanguage(LANGUAGE_CSHARP) }? attribute)* (specifier)* STRUCT class_header
;

struct_union_definition[int element_token] { ENTRY_DEBUG } :
        class_preprocessing[element_token]

        ({ inLanguage(LANGUAGE_CSHARP) }? attribute)* (specifier)* (STRUCT | UNION) (class_header lcurly | lcurly)
        {
           if (inLanguage(LANGUAGE_CXX_ONLY))
               class_default_access_action(SPUBLIC_ACCESS_DEFAULT);
        }
;

/*
*/
union_declaration[] { ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_STATEMENT);

            // start the class definition
            startElement(SUNION_DECLARATION);
        }
        ({ inLanguage(LANGUAGE_CSHARP) }? attribute)* (specifier)* UNION class_header
;

/*
   Classes and structs in C++ have a default private/public section.  This handles it.
*/
class_default_access_action[int access_token] { ENTRY_DEBUG } :
        {
            if (inLanguage(LANGUAGE_CXX_ONLY) && (SkipBufferSize() > 0 ||
                !(LA(1) == PUBLIC || LA(1) == PRIVATE || LA(1) == PROTECTED))) {

                // setup block section
                section_entry_action_first();

                // start private element
                if (LA(1) == RCURLY && SkipBufferSize() == 0)
                    // empty element for empty (no ws even) block
                    emptyElement(access_token);
                else {
                    // start private element before whitespace
                    startNoSkipElement(access_token);
                    setMode(MODE_ACCESS_REGION);
                }

            /* Have to setup an empty section for anonymouse structs, not sure why */
            } else if (inLanguage(LANGUAGE_C)) {
                section_entry_action_first();
            }
        }
;

/*
 header (part before block) of class (or struct or union)
*/
class_header[] { ENTRY_DEBUG } :

        /*
          TODO
          
          This shouldn't be needed, but uncommenting the predicate causes Java
          to mess up with template parameters, but not C++ ???
        */
        { inLanguage(LANGUAGE_C_FAMILY) }?
        (macro_call_check class_header_base LCURLY)=>
           macro_call class_header_base |

        class_header_base
;

/*
 header (part before block) of class (or struct or union)
*/
class_header_base[] { bool insuper = false; ENTRY_DEBUG } :

        complex_name[true] (

            { inLanguage(LANGUAGE_C_FAMILY) }?
            (options { greedy = true; } : derived)* (generic_constraint)* | 

            { inLanguage(LANGUAGE_JAVA_FAMILY) }?
            (options { greedy = true; } : super_list_java { insuper = true; } extends_list)* 
                ( { if (!insuper) { insuper = true; super_list_java(); } } implements_list)*
                {
                    if (insuper)
                        endCurrentMode();
                }
       )
;

/*
  Each instance of an access specifier defines a region in the class
*/
access_specifier_region[] { ENTRY_DEBUG } : 
        section_entry_action
        {
            // mark access regions to detect statements that only occur in them
            setMode(MODE_ACCESS_REGION);
        }
        (
            {
                // start of case element
                startElement(SPUBLIC_ACCESS);
            }
            PUBLIC |
            {
                // start of case element
                startElement(SPRIVATE_ACCESS);
            }
            PRIVATE |
            {
                // start of case element
                startElement(SPROTECTED_ACCESS);
            }
            PROTECTED
        )
        { }
        COLON
;

/*
  left curly brace

  Marks the start of a block.  End of the block is handled in right curly brace
*/
lcurly[] { ENTRY_DEBUG } :
        {
            // special end for conditions
            if (inTransparentMode(MODE_CONDITION)) {
                endDownToMode(MODE_CONDITION);
                endCurrentMode(MODE_CONDITION);
            }
           
            if (inMode(MODE_IF)) {

                // then part of the if statement (after the condition)
                startNewMode(MODE_STATEMENT | MODE_NEST | MODE_THEN);

                // start the then element
                startNoSkipElement(STHEN);
            }

            // special end for constructor member initialization list
            if (inMode(MODE_LIST | MODE_CALL)) {
                // flush any whitespace tokens since sections should
                // end at the last possible place
                flushSkip();

                endCurrentMode(MODE_LIST | MODE_CALL);
            }
        }
        lcurly_base
        {
            // alter the modes set in lcurly_base
            setMode(MODE_TOP | MODE_NEST | MODE_STATEMENT | MODE_LIST);
        }
;

/*
  left curly brace

  Marks the start of a block.  End of the block is handled in right curly brace
*/
lcurly_base[] { ENTRY_DEBUG } :
        {  
            // need to pass on class mode to detect constructors for Java
            bool inclassmode = inLanguage(LANGUAGE_JAVA_FAMILY) && inMode(MODE_CLASS);

            startNewMode(MODE_BLOCK);

            if (inclassmode)
                setMode(MODE_CLASS);

            startElement(SBLOCK);

        }
        LCURLY
;

/*
  Marks the end of a block.  Also indicates the end of some open elements.
*/
block_end[] { ENTRY_DEBUG } :
        // handling of if with then block followed by else
        // handle the block, however scope of then completion stops at if
        rcurly
        { 
            if (inMode(MODE_ANONYMOUS)) {

                endCurrentMode(MODE_ANONYMOUS);
                return;
            }

            // end all statements this statement is nested in
            // special case when ending then of if statement

            // end down to either a block or top section, or to an if, whichever is reached first
            endDownToFirstMode(MODE_BLOCK | MODE_TOP | MODE_IF | MODE_ELSE | MODE_TRY | MODE_ANONYMOUS);

            bool endstatement = inMode(MODE_END_AT_BLOCK);
            bool anonymous_class = inMode(MODE_CLASS) && inMode(MODE_END_AT_BLOCK);

            // some statements end with the block
            if (inMode(MODE_END_AT_BLOCK)) {
                endCurrentMode(MODE_LOCAL);

                if (inTransparentMode(MODE_TEMPLATE))
                    endCurrentMode(MODE_LOCAL);
            }

            // looking for a terminate (';').  may have some whitespace before it
            consumeSkippedTokens();

            // some statements end with the block if there is no terminate
            if (inMode(MODE_END_AT_BLOCK_NO_TERMINATE) && LA(1) != TERMINATE) {
                endstatement = true;
                endCurrentMode(MODE_LOCAL);
            }

            if (inTransparentMode(MODE_ENUM) && inLanguage(LANGUAGE_CSHARP)) {

                endCurrentMode(MODE_LOCAL);
            }

            if (!(anonymous_class))
                if (!(inMode(MODE_CLASS) || inTransparentMode(MODE_ENUM)) || (inMode(MODE_CLASS) || inTransparentMode(MODE_ENUM)) && endstatement)
                else_handling();

            // if we are in a declaration (as part of a class/struct/union definition)
            // then we needed to markup the (abbreviated) variable declaration
            if (inMode(MODE_DECL) && LA(1) != TERMINATE)
                short_variable_declaration();

            // end of block may lead to adjustment of cpp modes
            cppmode_adjust();
        }

;

/*
  right curly brace

  Not used directly, but called by block_end
*/
rcurly[] { ENTRY_DEBUG } :
        {
            // end any elements inside of the block
            endDownToMode(MODE_TOP);

            // flush any whitespace tokens since sections should
            // end at the last possible place
            flushSkip();

            // end any sections inside the mode
            endDownOverMode(MODE_TOP_SECTION);
        }
        RCURLY
        {
            // end the current mode for the block
            // don't end more than one since they may be nested
            endCurrentMode(MODE_TOP);
        }
;

/*
  End any open expressions, match, then close any open elements
*/
terminate[] { ENTRY_DEBUG } :

        {
            if (inMode(MODE_IGNORE_TERMINATE)) {

                if (inMode(MODE_FOR_INITIALIZATION | MODE_EXPECT))
                    for_initialization_action();
                else
                    for_condition_action();
            }
        }
        terminate_pre
        terminate_token
        terminate_post
;

terminate_token[] { CompleteElement element; ENTRY_DEBUG } :
        {
            if (inMode(MODE_NEST | MODE_STATEMENT) && !inMode(MODE_DECL) && !inMode(MODE_IF)) {

                startNewMode(MODE_LOCAL);

                startElement(SEMPTY);
            }
        }
        TERMINATE
    ;

terminate_pre[] { ENTRY_DEBUG } :
        {
            // end any elements inside of the statement
            if (!inMode(MODE_TOP | MODE_NEST | MODE_STATEMENT))
                endDownToFirstMode(MODE_STATEMENT | MODE_EXPRESSION_BLOCK |
                                   MODE_INTERNAL_END_CURLY | MODE_INTERNAL_END_PAREN);
        }
;

terminate_post[] { ENTRY_DEBUG } :
        {
            // end all statements this statement is nested in
            // special case when ending then of if statement
            if (!isoption(parseoptions, OPTION_EXPRESSION) &&
                 (!inMode(MODE_EXPRESSION_BLOCK) || inMode(MODE_EXPECT)) &&
                !inMode(MODE_INTERNAL_END_CURLY) && !inMode(MODE_INTERNAL_END_PAREN)) {

                // end down to either a block or top section, or to an if or else
                endDownToFirstMode(MODE_TOP | MODE_IF | MODE_ELSE);
            }
        }
        else_handling
;

/*
  Handle possible endings of else statements.

  Called from all places that end a statement, and could possibly end the else that the target statement was in.
  I.e., terminate ';', end of a statement block, etc.

  If in an if-statement, relatively straightforward.  Note that we could be ending with multiple else's.

  Special case:  else with no matching if.  This occurs with a) a single else, or more likely with b) an
  else in a preprocessor #if .. #else ... #endif construct (actually, very common).
*/
else_handling[] { ENTRY_DEBUG } :
        {
                // record the current size of the top of the cppmode stack to detect
                // any #else or #endif in the consumeSkippedTokens
                // see below
                unsigned int cppmode_size = !cppmode.empty() ? cppmode.top().statesize.size() : 0;

                // move to the next non-skipped token
                consumeSkippedTokens();

                // catch and finally statements are nested inside of a try, if at that level
                // so if no CATCH or FINALLY, then end now
                bool intry = inMode(MODE_TRY);
                bool restoftry = LA(1) == CATCH || LA(1) == FINALLY;
                if (intry && !restoftry) {
                    endCurrentMode(MODE_TRY);
                    endDownToMode(MODE_TOP);
                }

                // handle parts of if
                if (inTransparentMode(MODE_IF) && !(intry && restoftry)) {

                    // find out if the next token is an else
                    bool nestedelse = LA(1) == ELSE;

                    if (!nestedelse) {

                        endDownToMode(MODE_TOP);

                    // when an ELSE is next and already in an else, must end properly (not needed for then)
                    } else if (nestedelse && inMode(MODE_ELSE)) {

                        while (inMode(MODE_ELSE)) {

                            // end the else
                            endCurrentMode(MODE_ELSE);

                            // move to the next non-skipped token
                            consumeSkippedTokens();

                            /*
                              TODO:  Can we only do this if we detect a cpp change?

                              This would occur EVEN if we have an ifcount of 2.
                             */
                            // we have an extra else that is rogue
                            // it either is a single else statement, or part of an #ifdef ... #else ... #endif
                            if (LA(1) == ELSE && ifcount == 1)
                                break;

                            // ending an else means ending an if
                            if (inMode(MODE_IF)) {
                                endCurrentModeSafely(MODE_IF);
                                --ifcount;
                            }
                        }  

                        // following ELSE indicates end of outer then
                        endCurrentModeSafely(MODE_THEN);
                    }

                } else if (inTransparentMode(MODE_ELSE)) {

                    // have an else, but are not in an if.  Could be a fragment,
                    // or could be due to an #ifdef ... #else ... #endif
                    endCurrentModeSafely(MODE_ELSE);
                }

            // update the state size in cppmode if changed from using consumeSkippedTokens
            if (!cppmode.empty() && cppmode_size != cppmode.top().statesize.size()) {

                cppmode.top().statesize.back() = size();

                // remove any finished ones
                if (cppmode.top().isclosed)    {
                        cppmode_cleanup();
                }
            }
        }
;

/*
  Handling when mid-statement
*/
statement_part[] { int type_count; int fla = 0; int secondtoken = 0; DECLTYPE decl_type = NONE; CALLTYPE type = NOCALL; ENTRY_DEBUG } :
        { inMode(MODE_EAT_TYPE) }?
            type_identifier
            update_typecount |

        /*
          MODE_FUNCTION_TAIL
        */

        // throw list at end of function header
        { (inLanguage(LANGUAGE_OO)) && inMode(MODE_FUNCTION_TAIL) }?
             throw_list |

        // function specifier at end of function header
        { inLanguage(LANGUAGE_CXX_FAMILY) && inMode(MODE_FUNCTION_TAIL) }?
             function_specifier |

        // K&R function parameters
        { inLanguage(LANGUAGE_C_FAMILY) && inMode(MODE_FUNCTION_TAIL) && 
          perform_noncfg_check(decl_type, secondtoken, fla, type_count) && decl_type == VARIABLE }?
            kr_parameter |

        /*
          MODE_EXPRESSION
        */

        // block right after argument list, e.g., throws list in Java
        { inTransparentMode(MODE_END_LIST_AT_BLOCK) }?
        { endDownToMode(MODE_LIST); endCurrentMode(MODE_LIST); }
            lcurly | 

        // expression block or expressions
        // must check before expression
        { inMode(MODE_EXPRESSION_BLOCK | MODE_EXPECT) }?
             pure_expression_block |

        // start of argument for return or throw statement
        { inMode(MODE_EXPRESSION | MODE_EXPECT) &&
            inLanguage(LANGUAGE_C_FAMILY) && perform_call_check(type, secondtoken) && type == MACRO }?
        macro_call |

        { inMode(MODE_EXPRESSION | MODE_EXPECT) }?
        expression[type] |

        // already in an expression, and run into a keyword
        // so stop the expression, and markup the keyword statement
        { inMode(MODE_EXPRESSION) }?
             terminate_pre
             terminate_post
             cfg |

        // already in an expression
        { inMode(MODE_EXPRESSION) }?
             expression_part_plus_linq |

        // call list in member initialization list
        { inMode(MODE_CALL | MODE_LIST) }?
             call |

        /*
          MODE_VARIABLE_NAME
        */

        // special case for type modifiers
        { inMode(MODE_VARIABLE_NAME | MODE_INIT) }?
             multops |

        { inMode(MODE_VARIABLE_NAME | MODE_INIT) }?
             tripledotop |

        // start of argument for return or throw statement
        { inMode(MODE_VARIABLE_NAME | MODE_INIT) }?
             variable_declaration_nameinit |

        // variable name
        { inMode(MODE_VARIABLE_NAME) }?
             variable_identifier |

        // function identifier
        { inMode(MODE_FUNCTION_NAME) }?
             function_header[0] |

        // function identifier
        { inMode(MODE_FUNCTION_PARAMETER) }?
             parameter_list |

        // start of argument for return or throw statement
        { inMode(MODE_INIT | MODE_EXPECT) && inTransparentMode(MODE_TEMPLATE) }?
             parameter_declaration_initialization |

        // start of argument for return or throw statement
        { inMode(MODE_INIT | MODE_EXPECT) }?
             variable_declaration_initialization |

        // start of argument for return or throw statement
        { inMode(MODE_INIT | MODE_EXPECT) && (inLanguage(LANGUAGE_CXX) || inLanguage(LANGUAGE_JAVA)) }?
             variable_declaration_range |

        // in an argument list expecting an argument
        { inMode(MODE_ARGUMENT | MODE_LIST) }?
             argument |

        // start of condition for if/while/switch
        { inMode(MODE_PARAMETER | MODE_EXPECT) }?
             parameter |

        /*
          Check for MODE_FOR_CONDITION before template stuff, since it can conflict
        */

        // inside of for group expecting initialization
        { inMode(MODE_FOR_GROUP | MODE_EXPECT) }?
            for_group |

        // inside of for group expecting initialization
        { inMode(MODE_FOR_INITIALIZATION | MODE_EXPECT) }?
            for_initialization |

        // inside of for group expecting initialization
        { inMode(MODE_FOR_CONDITION | MODE_EXPECT) }?
            for_condition |

        // inside of for group expecting initialization
        { inMode(MODE_FOR_INCREMENT | MODE_EXPECT) }?
            for_increment |

        { inTransparentMode(MODE_TEMPLATE) && inMode(MODE_LIST | MODE_EXPECT) }?
             template_param_list |

        // expecting a template parameter
        { inTransparentMode(MODE_TEMPLATE) && inMode(MODE_LIST) }?
             template_param |

        // expecting a template parameter
        { inLanguage(LANGUAGE_CXX_FAMILY) && inMode(MODE_DERIVED) && inMode(MODE_EXPECT) }?
             derived |

        // start of condition for if/while/switch
        { inMode(MODE_CONDITION | MODE_EXPECT) }?
             condition |

        // while part of do statement
        { inMode(MODE_DO_STATEMENT) }?
             do_while |

        { inMode(MODE_NAMESPACE) }?
        namespace_alias |

        { inMode(MODE_NAMESPACE) }?
        namespace_block |

        // string literal of extern
        { inMode(MODE_EXTERN) }?
             extern_name |

        // sometimes end up here, as when for group ends early, or with for-each
        rparen |

        // seem to end up here for colon in ternary operator
        colon_marked
;

lparen_marked[] { CompleteElement element; ENTRY_DEBUG } :
        {
            incParen();

            if (isoption(parseoptions, OPTION_OPERATOR)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the modifier
                startElement(SOPERATOR);
            }
        }
        LPAREN  
;

comma[] { ENTRY_DEBUG }:
        {
            // comma ends the current item in a list
            // or ends the current expression
            if (!inTransparentMode(MODE_PARSE_EOL) && (inTransparentMode(MODE_LIST) || inTransparentMode(MODE_NEST | MODE_STATEMENT))) {

                // might want to check for !inMode(MODE_INTERNAL_END_CURLY)
                endDownToFirstMode(MODE_LIST | MODE_STATEMENT);
            }

            // comma in a variable initialization end init of current variable
            if (inMode(MODE_IN_INIT)) {
                endCurrentMode(MODE_IN_INIT);
            }
        }
        comma_marked
;

comma_marked[] { CompleteElement element; ENTRY_DEBUG }:
        {
            if (isoption(parseoptions, OPTION_OPERATOR) && !inMode(MODE_PARAMETER) && !inMode(MODE_ARGUMENT)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the modifier
                startElement(SOPERATOR);
            }
        }
        COMMA
;

colon_marked[] { CompleteElement element; ENTRY_DEBUG } :
        {
            if (isoption(parseoptions, OPTION_OPERATOR)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the modifier
                startElement(SOPERATOR);
            }
        }
        COLON
;

colon[] { ENTRY_DEBUG } :
        {
            if (inTransparentMode(MODE_TOP_SECTION))
                // colon ends the current item in a list
                endDownToMode(MODE_TOP_SECTION);
        }
        COLON
;

/*
  Condition contained in if/while/switch.

  Triggered by mode MODE_CONDITION | MODE_EXPECT and left parentheses.
  Starts condition mode and prepares to handle embedded expression.
  End of the element is handled in condition_rparen.
*/
condition[] { ENTRY_DEBUG } :
        {
            assertMode(MODE_CONDITION | MODE_EXPECT);

            // start element condition outside of the left parentheses
            startElement(SCONDITION); 

            // mark the condition mode as the one to stop at a right parentheses
            // non-empty conditions contain an expression
            setMode(MODE_LIST | MODE_EXPRESSION | MODE_EXPECT);
        }
        LPAREN
;

/* Function */

function_pointer_name_grammar[] { ENTRY_DEBUG } :
        LPAREN function_pointer_name_base RPAREN
;

function_pointer_name_base[] { ENTRY_DEBUG bool flag = false; } :

        // special case for function pointer names that don't have '*'
        (complex_name[true] RPAREN)=>
            complex_name[true] |

        // special name prefix of namespace or class
        identifier (template_argument_list)* DCOLON function_pointer_name_base |

        // typical function pointer name
        MULTOPS (complex_name[true])*

        // optional array declaration
        (variable_identifier_array_grammar_sub[flag])*
;

/*
  Everything except the ";" of a function declaration or the block of a
  function definition
*/
function_header[int type_count] { ENTRY_DEBUG } : 

        // no return value functions:  casting operator method and main
        { type_count == 0 }? function_identifier
        { replaceMode(MODE_FUNCTION_NAME, MODE_FUNCTION_PARAMETER | MODE_FUNCTION_TAIL); } |

        function_type[type_count]
;

/*
Guessing mode only
*/
function_tail[] { ENTRY_DEBUG } :
        // at most only one throwlist expected.  0-many is more efficient
        (options { greedy = true; } :

            /* order is important */

            { inLanguage(LANGUAGE_CXX_FAMILY) }?
            function_specifier |

            { inLanguage(LANGUAGE_CXX_FAMILY) }?
            TRY | 

            { inLanguage(LANGUAGE_OO) }?
            complete_throw_list |

            // K&R 
            { inLanguage(LANGUAGE_C) }? (

            // FIXME:  Must be integrated into other C-based languages
            // FIXME:  Wrong markup
            ( macro_call )=> macro_call | 
            { look_past(NAME) == LCURLY }? NAME |
              parameter (MULTOPS | NAME | COMMA)* TERMINATE
            )
        )*
;

perform_noncfg_check[DECLTYPE& type, int& token, int& fla, int& type_count, bool inparam = false] returns [bool isdecl] {

    isdecl = true;

    type = NONE;

    int start = mark();
    inputState->guessing++;

    bool sawenum;
    int posin = 0;

    try {
        noncfg_check(token, fla, type_count, type, inparam, sawenum, posin);

    } catch (...) {

        if (type == VARIABLE && type_count == 0)
            type_count = 1;

//        if (type == NONE && first == DELEGATE)
//            type = DELEGATE_FUNCTION;
    }

    // may just have an expression 
    if (type == VARIABLE && posin)
        type_count = posin - 1;

    if (type == 0 && sawenum)
        type = ENUM_DECL;

    // may just have a single macro (no parens possibly) before a statement
    if (type == 0 && type_count == 0 && _tokenSet_1.member(LA(1)))
        type = SINGLE_MACRO;

    // may just have an expression 
    if (type == DESTRUCTOR && !inLanguage(LANGUAGE_CXX_FAMILY))
        type = NULLOPERATOR;

    // false constructor for java
//    if (inLanguage(LANGUAGE_JAVA_FAMILY) && type == CONSTRUCTOR && fla != LCURLY)
//        type = NONE;

    inputState->guessing--;
    rewind(start);
} :
;

/*
  Figures out if we have a declaration, either variable or function.

  This is pretty complicated as it has to figure out whether it is a declaration or not,
  and whether it is a function or a variable declaration.
*/
noncfg_check[int& token,      /* second token, after name (always returned) */
             int& fla,        /* for a function, TERMINATE or LCURLY, 0 for a variable */
             int& type_count, /* number of tokens in type (not including name) */
             DECLTYPE& type,
             bool inparam,     /* are we in a parameter */
             bool& sawenum,
             int& posin
        ] { sawenum = false; token = 0; fla = 0; type_count = 0; int specifier_count = 0; isdestructor = false;
        type = NONE; bool foundpure = false; bool isoperatorfunction = false; bool isconstructor = false; bool saveisdestructor = false; bool endbracket = false; bool modifieroperator = false; bool sawoperator = false; int attributecount = 0; posin = 0; qmark = false; bool global = false; bool typeisvoid = false; int real_type_count = 0; ENTRY_DEBUG } :

        // main pattern for variable declarations, and most function declaration/definitions.
        // trick is to look for function declarations/definitions, and along the way record
        // if a declaration

        // int -> NONE
        // int f -> VARIABLE
        // int f(); -> FUNCTION
        // int f() {} -> FUNCTION

        /*
          Process all the parts of a potential type.  Keep track of total
          parts, specifier parts, and second token
        */
        (DELEGATE (LPAREN | LCURLY))=>
            DELEGATE set_type[type, DELEGATE_FUNCTION] |
        (
        ({ inLanguage(LANGUAGE_JAVA_FAMILY) || inLanguage(LANGUAGE_CSHARP) || (type_count == 0) || LA(1) != LBRACKET }?

            set_bool[qmark, (qmark || (LA(1) == QMARK)) && inLanguage(LANGUAGE_CSHARP)]
        
            set_bool[typeisvoid, typeisvoid || (LA(1) == NAME && LT(1)->getText() == "void")]

            set_int[posin, LA(1) == IN ? posin = type_count : posin]

            set_bool[sawoperator, sawoperator || LA(1) == OPERATOR]

            // was their a bracket on the end?  Need to know for Java
            set_bool[endbracket, inLanguage(LANGUAGE_JAVA_FAMILY) && LA(1) == LBRACKET]

            // record any type modifiers that are also operators
            // this is for disambiguation of destructor declarations from expressions involving
            // the ~ operator
            set_bool[modifieroperator, modifieroperator || LA(1) == REFOPS || LA(1) == MULTOPS || LA(1) == QMARK]

            set_bool[sawenum, sawenum || LA(1) == ENUM]
            (
                specifier set_int[specifier_count, specifier_count + 1] |

                { type_count == attributecount && inLanguage(LANGUAGE_CSHARP) }?
                (attribute)=>
                global = attribute set_int[attributecount, attributecount + 1] 
                set_type[type, GLOBAL_ATTRIBUTE, global]
                throw_exception[global] |

                { type_count == attributecount && inLanguage(LANGUAGE_CSHARP) }?
                property_method_names
                set_type[type, PROPERTY_ACCESSOR, true]
                /* throw_exception[true] */ |

                { inLanguage(LANGUAGE_JAVA_FAMILY) }?
                (template_argument_list)=>
                template_argument_list set_int[specifier_count, specifier_count + 1] |

                // typical type name
//                { LA(1) != ASYNC }?
                complex_name[true, true] set_bool[foundpure]
                    set_bool[isoperatorfunction, inLanguage(LANGUAGE_CXX_FAMILY) && (isoperatorfunction ||
                             (namestack[0] == "operator" && type_count == specifier_count))] |

                // special function name
                MAIN set_bool[isoperatorfunction, type_count == 0] |

                { inLanguage(LANGUAGE_CSHARP) }?
                (LBRACKET (COMMA)* RBRACKET)=>
                LBRACKET (COMMA)* RBRACKET |

                // type parts that can occur before other type parts (excluding specifiers)
                pure_lead_type_identifier_no_specifiers set_bool[foundpure] |

                // type parts that must only occur after other type parts (excluding specifiers)
                non_lead_type_identifier throw_exception[!foundpure]
            )

            // another type part
            set_int[type_count, type_count + 1]

            // record second (before we parse it) for label detection
            set_int[token, LA(1), type_count == 1]
        )*

        // special case for property attributes as names, e.g., get, set, etc.
        throw_exception[type == PROPERTY_ACCESSOR && (type_count == attributecount + 1) && LA(1) == LCURLY]
        set_type[type, PROPERTY_ACCESSOR_DECL, type == PROPERTY_ACCESSOR]
        throw_exception[type == PROPERTY_ACCESSOR_DECL && (type_count == attributecount + 1) && LA(1) == TERMINATE]
        set_type[type, NONE, type == PROPERTY_ACCESSOR_DECL]

        set_int[real_type_count, type_count]

        // special case for ternary operator on its own
        throw_exception[LA(1) == COLON && qmark]

        // adjust specifier tokens to account for keyword async used as name (only for C#)
        set_int[specifier_count, token == ASYNC ? specifier_count - 1 : specifier_count]

        // adjust type tokens to eliminate for last left bracket (only for Java)
        set_int[type_count, endbracket ? type_count - 1 : type_count]

        // have a sequence of type tokens, last one is function/variable name
        // (except for function pointer, which is handled later)
        set_int[type_count, type_count > 1 ? type_count - 1 : 0]

        set_bool[isoperatorfunction, isoperatorfunction || isdestructor]

        // special case for what looks like a destructor declaration
        throw_exception[isdestructor && (modifieroperator || (type_count - specifier_count - attributecount) > 1 || ((type_count - specifier_count - attributecount) == 1 && !typeisvoid))]

        /*
          We have a declaration (at this point a variable) if we have:
          
            - At least one non-specifier in the type
            - There is nothing in the type (what was the name is the type)
              and it is part of a parameter list
        */
        set_type[type, VARIABLE, ((type_count - specifier_count > 0) ||
                                 (inparam && (LA(1) == RPAREN || LA(1) == COMMA || LA(1) == LBRACKET || 
                                              ((inLanguage(LANGUAGE_CXX) || inLanguage(LANGUAGE_C)) && LA(1) == EQUAL))))]

        // need to see if we possibly have a constructor/destructor name, with no type
        set_bool[isconstructor,

                 // operator methods may not have non-specifier types also
                 !sawoperator &&

                 // entire type is specifiers
                 (type_count == (specifier_count + attributecount)) &&

                 (
                    // inside of a C++ class definition
                    inMode(MODE_ACCESS_REGION) ||

                    // right inside the block of a Java or C# class
                    (inPrevMode(MODE_CLASS) && (inLanguage(LANGUAGE_JAVA_FAMILY) || inLanguage(LANGUAGE_CSHARP))) ||

                    // by itself, but has specifiers so is not a call
                    (specifier_count > 0 && (inLanguage(LANGUAGE_JAVA_FAMILY) || inLanguage(LANGUAGE_CSHARP))) ||

                    // outside of a class definition in C++, but with properly prefixed name
                    (inLanguage(LANGUAGE_CXX_FAMILY) && namestack[0] != "" && namestack[1] != "" && namestack[0] == namestack[1])
                )
        ]

        // need to see if we possibly have a constructor/destructor name, with no type
        set_bool[isoperatorfunction, isoperatorfunction || isconstructor]

        // detecting a destructor name uses a data member, since it is detected in during the
        // name detection.  If the parameters use this method, it is reentrant, so cache it
        set_bool[saveisdestructor, isdestructor]

        // we have a declaration, so do we have a function?
        (
            // check for function pointer, which must have a non-specifier part of the type
            { inLanguage(LANGUAGE_C_FAMILY) && real_type_count > 0 }?
            (function_pointer_name_grammar eat_optional_macro_call LPAREN)=>
            function_pointer_name_grammar
        
            // what was assumed to be the name of the function is actually part of the type
            set_int[type_count, type_count + 1]

            function_rest[fla] |

            // POF (Plain Old Function)
            // need at least one non-specifier in the type (not including the name)
            { (type_count - specifier_count > 0) || isoperatorfunction }?
            function_rest[fla]
        )

        // since we got this far, we have a function
        set_type[type, FUNCTION]

        // however, we could have a destructor
        set_type[type, DESTRUCTOR, saveisdestructor]

        // could also have a constructor
        set_type[type, CONSTRUCTOR, !saveisdestructor && isconstructor]
)
;

//monitor { std::cerr << namestack[0] << " " << namestack[1] << std::endl; } :;

//other[bool flag] { std::cerr << flag << std::endl; } :;

throw_exception[bool cond = true] { if (cond) throw antlr::RecognitionException(); } :;

set_type[DECLTYPE& name, DECLTYPE value, bool result = true] { if (result) name = value; } :;

trace[const char*s ] { std::cerr << s << std::endl; } :;
trace_int[int s] { std::cerr << "HERE " << s << std::endl; } :;

//traceLA { std::cerr << "LA(1) is " << LA(1) << " " << LT(1)->getText() << std::endl; } :;

marker[] { CompleteElement element; startNewMode(MODE_LOCAL); startElement(SMARKER); } :;

set_int[int& name, int value, bool result = true] { if (result) name = value; } :;

set_bool[bool& variable, bool value = true] { variable = value; } :;

/*
message[const char* s] { std::cerr << s << std::endl; ENTRY_DEBUG } :;

message_int[const char* s, int n]  { std::cerr << s << n << std::endl; ENTRY_DEBUG } :;
*/

function_rest[int& fla] { ENTRY_DEBUG } :

        eat_optional_macro_call

        parameter_list function_tail check_end[fla]
;

/*
  Type of a function.  Includes specifiers
*/
function_type[int type_count] { ENTRY_DEBUG } :
        {
            // start a mode for the type that will end in this grammar rule
            startNewMode(MODE_EAT_TYPE);

            setTypeCount(type_count);

            // type element begins
            startElement(STYPE);
        }
        lead_type_identifier
        update_typecount
;

update_typecount[] {} :
        {
            decTypeCount();

            if (getTypeCount() <= 0) {
                endCurrentMode(MODE_LOCAL);
                setMode(MODE_FUNCTION_NAME); 
            } 
        }
;

update_var_typecount[] {} :
        {
            decTypeCount();

            if (getTypeCount() <= 0) {
                endCurrentMode(MODE_LOCAL);
                setMode(MODE_VARIABLE_NAME | MODE_INIT); 
            } 
        }
;

/*
  Type of a function.  Includes specifiers
*/
function_type_check[int& type_count] { type_count = 1; ENTRY_DEBUG } :

        lead_type_identifier
        ( { inLanguage(LANGUAGE_JAVA_FAMILY) || LA(1) != LBRACKET }? type_identifier_count[type_count])*
;

type_identifier_count[int& type_count] { ++type_count; ENTRY_DEBUG } :

        // overloaded parentheses operator
        { LA(1) == OPERATOR }?
        overloaded_operator |

        type_identifier | MAIN
;

deduct[int& type_count] { --type_count; } :;

eat_type[int count] { if (count <= 0) return; ENTRY_DEBUG } :

        type_identifier
        eat_type[count - 1]
;

/*
  throw list for a function
*/
throw_list[] { ENTRY_DEBUG } :
        {
            // start a new mode that will end after the argument list
            startNewMode(MODE_ARGUMENT | MODE_LIST | MODE_EXPECT);

            startElement(STHROW_SPECIFIER);
        }
        THROW LPAREN |
        {
            // start a new mode that will end after the argument list
            startNewMode(MODE_ARGUMENT | MODE_LIST | MODE_EXPECT | MODE_END_LIST_AT_BLOCK);

            startElement(STHROW_SPECIFIER_JAVA);
        }
        THROWS
        {
//            endCurrentMode(MODE_LIST | MODE_EXPECT);
        }
;  

/*
  throw list for a function
*/
complete_throw_list[] { bool flag = false; ENTRY_DEBUG } :
        THROW paren_pair | THROWS ( options { greedy = true; } : complex_name_java[true, flag] | COMMA)*
;

/*
   type identifier

*/
pure_lead_type_identifier[] { ENTRY_DEBUG } :

        auto_keyword |

        // specifiers that occur in a type
        (specifier)=>
        specifier |

        { inLanguage(LANGUAGE_CSHARP) }?
        (LBRACKET (COMMA)* RBRACKET)=>
        LBRACKET (COMMA)* RBRACKET | 

        { inLanguage(LANGUAGE_CSHARP) }? attribute |

        pure_lead_type_identifier_no_specifiers
;

pure_lead_type_identifier_no_specifiers[] { ENTRY_DEBUG } :

        // class/struct/union before a name in a type, e.g., class A f();
        CLASS | STRUCT | UNION |

        // enum use in a type
        { inLanguage(LANGUAGE_C_FAMILY) && !inLanguage(LANGUAGE_CSHARP) }?
        (ENUM variable_identifier (variable_identifier | multops | tripledotop | INLINE))=> ENUM |

        // entire enum definition
        { inLanguage(LANGUAGE_C_FAMILY) && !inLanguage(LANGUAGE_CSHARP) }?
        enum_definition_whole
;

/*
   type identifier

*/
lead_type_identifier[] { ENTRY_DEBUG } :

//        specifier |

//        (macro_call_paren identifier)=> macro_call |

        // typical type name
        { LA(1) != ASYNC }?
        complex_name[true, true] |

        pure_lead_type_identifier
;

type_identifier[] { ENTRY_DEBUG } :

        // any identifier that can appear first can appear later
        lead_type_identifier |

        non_lead_type_identifier
;

non_lead_type_identifier[] { bool iscomplex = false; ENTRY_DEBUG } :

        tripledotop |

        { inLanguage(LANGUAGE_C_FAMILY) }? multops |

        { inLanguage(LANGUAGE_JAVA_FAMILY) && look_past(LBRACKET) == RBRACKET }?
        variable_identifier_array_grammar_sub[iscomplex]
;

/*
  A set of balanced parentheses
*/
balanced_parentheses[] :
        LCURLY
        (balanced_parentheses | ~(LCURLY | RCURLY))*
        RCURLY
;

/*
   Name of a function
*/
function_identifier[] { ENTRY_DEBUG } :

        // typical name
        complex_name[true] |

        function_identifier_main |

        { inLanguage(LANGUAGE_CSHARP) }?
        function_identifier_default |

        // function pointer identifier with name marked separately
        function_pointer_name_grammar eat_optional_macro_call
;

qmark_marked[] { CompleteElement element; ENTRY_DEBUG } :
        // special cases for main
        {
            // end all started elements in this rule
            startNewMode(MODE_LOCAL);

            // start of the name element
            startElement(SNAME);
        }
        QMARK
;

function_identifier_default[] { CompleteElement element; ENTRY_DEBUG } :
        // special cases for main
        {
            // end all started elements in this rule
            startNewMode(MODE_LOCAL);

            // start of the name element
            startElement(SNAME);
        }
        // main program
        DEFAULT
;

function_identifier_main[] { CompleteElement element; ENTRY_DEBUG } :
        // special cases for main
        {
            // end all started elements in this rule
            startNewMode(MODE_LOCAL);

            // start of the name element
            startElement(SNAME);
        }
        // main program
        MAIN
;

/*
  overloaded operator name
*/
overloaded_operator[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // end all started elements in this rule
            startNewMode(MODE_LOCAL);

            // start of the name element
            startElement(SNAME);
        }
        OPERATOR
        (
            // special case for 'operator()'
            { LA(1) == LPAREN }? LPAREN RPAREN |

            // general operator name case is anything from 'operator', operators, or names
            (options { greedy = true; } : ~(LPAREN))*
        )
;

linq_expression[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SLINQ);
        }
        (options { greedy = true; } : linq_from | linq_where | linq_select | linq_let | linq_group | linq_join | linq_orderby)+
    ;

linq_from[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SFROM);
        }
        FROM linq_full_expression (options { greedy = true; } : linq_in)*
    ;

linq_in[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SIN);
        }
        IN linq_full_expression
    ;

linq_where[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SWHERE);
        }
        WHERE linq_full_expression
    ;

linq_select[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SSELECT);
        }
        SELECT linq_full_expression
    ;

linq_let[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SLET);
        }
        LET linq_full_expression
    ;

linq_group[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SGROUP);
        }
        GROUP linq_full_expression
        (options { greedy = true; } : linq_by)*
        (options { greedy = true; } : linq_into)*
    ;

linq_by[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SBY);
        }
        BY linq_full_expression
    ;

linq_into[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SINTO);
        }
        INTO linq_full_expression
    ;

linq_join[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SJOIN);
        }
        JOIN linq_full_expression 
        (options { greedy = true; } : linq_in)* 
        (options { greedy = true; } : linq_on)* 
        (options { greedy = true; } : linq_equals)* 
        (options { greedy = true; } : linq_into)* 
    ;

linq_on[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SON);
        }
        ON linq_full_expression
    ;

linq_equals[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SEQUALS);
        }
        EQUALS linq_full_expression
    ;

linq_orderby[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SORDERBY);
        }
        ORDERBY linq_full_expression 

        (options { greedy = true; } : linq_ascending | linq_descending | )
        
        (options { greedy = true; } : COMMA linq_full_expression (linq_ascending | linq_descending| ))*
    ;

linq_ascending[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SNAME);
        }
        ASCENDING
    ;

linq_descending[] { CompleteElement element; ENTRY_DEBUG }:
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(SNAME);
        }
        DESCENDING
    ;

variable_identifier_array_grammar_sub[bool& iscomplex] { CompleteElement element; ENTRY_DEBUG } :
        {
            // start a mode to end at right bracket with expressions inside
            if (inLanguage(LANGUAGE_CSHARP))
                startNewMode(MODE_LOCAL | MODE_TOP | MODE_LIST | MODE_END_AT_COMMA);
            else
                startNewMode(MODE_LOCAL | MODE_TOP | MODE_LIST);

            startElement(SINDEX);
        }
        LBRACKET

        variable_identifier_array_grammar_sub_contents

        RBRACKET
        {
            iscomplex = true;
        }
;


variable_identifier_array_grammar_sub_contents{ CompleteElement element; ENTRY_DEBUG } :
        { !inLanguage(LANGUAGE_CSHARP) }? full_expression |

        { inLanguage(LANGUAGE_CSHARP) }? ({ LA(1) != RBRACKET }? (COMMA | full_expression) )*
;


attribute[] returns [bool global = false] { CompleteElement element; ENTRY_DEBUG } :
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_TOP | MODE_LIST | MODE_EXPRESSION | MODE_EXPECT);

            startElement(SATTRIBUTE);
        }
        LBRACKET

        ((attribute_target COLON)=>
        (global = attribute_target COLON) | )

        full_expression

        RBRACKET
;

attribute_target[] returns [bool global = false] { CompleteElement element; ENTRY_DEBUG } :
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_LOCAL);

            startElement(STARGET);
        }
        (RETURN | EVENT |
            set_bool[global, LA(1) != RETURN && LA(1) != EVENT && (LT(1)->getText() == "module" || LT(1)->getText() == "assembly")] identifier
            )
;

/*
  Full, complete expression matched all at once (no stream).
  Colon matches range(?) for bits.
*/
full_expression[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_TOP | MODE_EXPECT | MODE_EXPRESSION);
        }
        (options { greedy = true; } :

        // commas as in a list
        {inTransparentMode(MODE_END_ONLY_AT_RPAREN) || !inTransparentMode(MODE_END_AT_COMMA)}?
        comma |

        // right parentheses, unless we are in a pair of parentheses in an expression 
        { !inTransparentMode(MODE_INTERNAL_END_PAREN) }? rparen[false] |

        // argument mode (as part of call)
        { inMode(MODE_ARGUMENT) }? argument |

        // expression with right parentheses if a previous match is in one
        { LA(1) != RPAREN || inTransparentMode(MODE_INTERNAL_END_PAREN) }? expression |

        COLON)*
;

linq_full_expression[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // start a mode to end at right bracket with expressions inside
            startNewMode(MODE_TOP | MODE_EXPECT | MODE_EXPRESSION);
        }
        (options { greedy = true; } :

        // commas as in a list
        comma |

        // right parentheses, unless we are in a pair of parentheses in an expression 
        { !inTransparentMode(MODE_INTERNAL_END_PAREN) }? rparen[false] |

        // argument mode (as part of call)
        { inMode(MODE_ARGUMENT) }? argument |

        // expression with right parentheses if a previous match is in one
        { LA(1) != ASCENDING && LA(1) != DESCENDING && LA(1) != ON && LA(1) != BY && LA(1) != FROM && LA(1) != SELECT && LA(1) != LET && LA(1) != WHERE && LA(1) != ORDERBY && LA(1) != GROUP && LA(1) != JOIN && LA(1) != IN && LA(1) != EQUALS && LA(1) != INTO && (LA(1) != RPAREN || inTransparentMode(MODE_INTERNAL_END_PAREN)) }? expression_setup_linq |

        COLON)*
;

/*
   A variable name in an expression.  Includes array names, but not
   function calls
*/
variable_identifier[] { ENTRY_DEBUG } :

        complex_name[true, true]
;

/*
  Name including template argument list
*/
simple_name_optional_template[bool marked] { CompleteElement element; TokenPosition tp; ENTRY_DEBUG } :
        {
            if (marked) {
                // local mode that is automatically ended by leaving this function
                startNewMode(MODE_LOCAL);

                // start outer name
                startElement(SCNAME);

                // record the name token so we can replace it if necessary
                setTokenPosition(tp);
            }
        }
        mark_namestack identifier[marked] (
            { inLanguage(LANGUAGE_CXX_FAMILY) || inLanguage(LANGUAGE_JAVA_FAMILY) }?
            (template_argument_list)=>
                template_argument_list |

            {
               // if we marked it as a complex name and it isn't, fix
               if (marked)
                   // set the token to NOP
                   tp.setType(SNOP);
            }
       )
;

/*
  Basic single token names

  preprocessor tokens that can also be used as identifiers
*/
identifier[bool marked = false] { CompleteElement element; ENTRY_DEBUG } :
        {
            if (marked) {
                // local mode that is automatically ended by leaving this function
                startNewMode(MODE_LOCAL);

                if(LT(1)->getText() != "const")
                    startElement(SNAME);
                else
                    startElement(SFUNCTION_SPECIFIER);

            }
        }
        (
            NAME | INCLUDE | DEFINE | ELIF | ENDIF | ERRORPREC | IFDEF | IFNDEF | LINE | PRAGMA | UNDEF |
            SUPER | CHECKED | UNCHECKED | REGION | ENDREGION | GET | SET | ADD | REMOVE | ASYNC | YIELD |

            // C# linq
            FROM | WHERE | SELECT | LET | ORDERBY | ASCENDING | DESCENDING | GROUP | BY | JOIN | ON | EQUALS | INTO | THIS |

            { inLanguage(LANGUAGE_CSHARP) }? UNION
        )
;

/*
  identifier name marked with name element
*/
complex_name[bool marked = true, bool index = false] { CompleteElement element; TokenPosition tp; bool iscomplex_name = false; ENTRY_DEBUG } :
        complex_name_inner[marked, index]
        (options { greedy = true; } : { index }? variable_identifier_array_grammar_sub[iscomplex_name])*
;

complex_name_inner[bool marked = true, bool index = false] { CompleteElement element; TokenPosition tp; bool iscomplex_name = false; ENTRY_DEBUG } :
        {
            if (marked) {
                // There is a problem detecting complex names from
                // complex names of operator methods in namespaces or
                // classes for implicit casting, e.g., A::operator String // () {}.
                // Detecting before here means lookahead on all A::B::... names
                // causing a slowdown of almost 20%.  Solution (hack) is to start all complex
                // names as operator methods, then replace by NOP if not.

                // local mode that is automatically ended by leaving this function
                startNewMode(MODE_LOCAL);

                // start outer name
                startElement(SONAME);

                // start inner name
                startElement(SCNAME);

                // record the name token so we can replace it if necessary
                setTokenPosition(tp);
            }
        }
        (
        { inLanguage(LANGUAGE_JAVA_FAMILY) }?
        complex_name_java[marked, iscomplex_name] |

        { inLanguage(LANGUAGE_CSHARP) }?
        complex_name_csharp[marked, iscomplex_name] |

        { inLanguage(LANGUAGE_C) }?
        complex_name_c[marked, iscomplex_name] |

        { !inLanguage(LANGUAGE_JAVA_FAMILY) && !inLanguage(LANGUAGE_C) && !inLanguage(LANGUAGE_CSHARP) }?
        complex_name_cpp[marked, iscomplex_name]
        )
        (options { greedy = true; } : { index && !inTransparentMode(MODE_EAT_TYPE) }? variable_identifier_array_grammar_sub[iscomplex_name])*
        {
            // if we marked it as a complex name and it isn't, fix
            if (marked && !iscomplex_name)
                // set the token to NOP
                tp.setType(SNOP);
        }
;

/*
  identifier name marked with name element
*/
complex_name_cpp[bool marked, bool& iscomplex_name] { namestack[0] = ""; namestack[1] = ""; bool founddestop = false; ENTRY_DEBUG } :

        (dcolon { iscomplex_name = true; })*
        (DESTOP set_bool[isdestructor] {
            founddestop = true;
        })*
        (simple_name_optional_template[marked] | mark_namestack overloaded_operator)
        ({ !inTransparentMode(MODE_EXPRESSION) }? multops)*
        name_tail[iscomplex_name, marked]
        { if (founddestop) iscomplex_name = true; }
;

/*
  identifier name marked with name element
*/
complex_name_csharp[bool marked, bool& iscomplex_name] { namestack[0] = ""; namestack[1] = ""; bool founddestop = false; ENTRY_DEBUG } :

        (dcolon { iscomplex_name = true; })*
        (DESTOP set_bool[isdestructor] {
            founddestop = true;
        })*
        (simple_name_optional_template[marked] | mark_namestack overloaded_operator)
        ({ !inTransparentMode(MODE_EXPRESSION) }? multops)*
        name_tail_csharp[iscomplex_name, marked]
        { if (founddestop) iscomplex_name = true; }
;

/*
  Identifier markup for C
*/
complex_name_c[bool marked, bool& iscomplex_name] { ENTRY_DEBUG } :
        
        identifier[marked]
        ( options { greedy = true; } : 
            period { iscomplex_name = true; }
            identifier[marked]
        )*
;

/*
  Identifier markup for Java
*/
complex_name_java[bool marked, bool& iscomplex_name] { ENTRY_DEBUG } :

        template_argument_list |
        simple_name_optional_template[marked]
        (options { greedy = true; } : (period { iscomplex_name = true; } simple_name_optional_template[marked]))*
;

/*
  sequences of "::" and names
*/
name_tail[bool& iscomplex, bool marked] { ENTRY_DEBUG } :

        // "a::" will cause an exception to be thrown
        ( options { greedy = true; } : 
            (dcolon { iscomplex = true; } | period { iscomplex = true; })
            ( options { greedy = true; } : dcolon)*
            (DESTOP set_bool[isdestructor])*
            (multops)*
            (simple_name_optional_template[marked] | mark_namestack overloaded_operator | function_identifier_main)
            ({ look_past_multiple(MULTOPS, REFOPS, RVALUEREF, QMARK) == DCOLON }? multops)*
        )*

        { notdestructor = LA(1) == DESTOP; }
;
exception
catch[antlr::RecognitionException] {
}

name_tail_csharp[bool& iscomplex, bool marked] { ENTRY_DEBUG } :

        // "a::" will cause an exception to be thrown
        ( options { greedy = true; } : 
            (dcolon { iscomplex = true; } | period { iscomplex = true; })
            ( options { greedy = true; } : dcolon)*
            (multops)*
            (DESTOP set_bool[isdestructor])*
            (simple_name_optional_template[marked] | mark_namestack overloaded_operator | function_identifier_main)
            (multops)*
        )*
;
exception
catch[antlr::RecognitionException] {
}

/* end of new identifiers */

/*
  Specifier for a function
*/
function_specifier[] { CompleteElement element; ENTRY_DEBUG } :
        generic_constraint |

        {
            // statement
            startNewMode(MODE_LOCAL);

            // start the function specifier
            startElement(SFUNCTION_SPECIFIER);
        }
        ({ LA(1) != ASYNC }? specifier |

        // pure virtual specifier
        EQUAL literal |

        simple_name_optional_template[false])
;

specifier[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_LOCAL);

            // start the function specifier
            startElement(SFUNCTION_SPECIFIER);
        }
        (
            // access
            PUBLIC | PRIVATE | PROTECTED |

            // C++
            FINAL | STATIC | ABSTRACT | FRIEND | { inLanguage(LANGUAGE_CSHARP) }? NEW | 

            // C# & Java
            INTERNAL | SEALED | OVERRIDE | REF | OUT | IMPLICIT | EXPLICIT | UNSAFE | READONLY | VOLATILE | DELEGATE | PARTIAL | EVENT | ASYNC | VIRTUAL | EXTERN | INLINE | IN | PARAMS
        )
;

auto_keyword[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // local mode that is automatically ended by leaving this function
            startNewMode(MODE_LOCAL);

            startElement(SNAME);
        }
        AUTO
;

// constructor definition
constructor_declaration[] { ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_STATEMENT);

            // start the constructor declaration
            startElement(SCONSTRUCTOR_DECLARATION);
        }
        constructor_header
;              

// constructor definition
constructor_definition[] { ENTRY_DEBUG } :
        {
            // statement with nested block
            startNewMode(MODE_STATEMENT | MODE_NEST);

            // start the construction definition
            startElement(SCONSTRUCTOR_DEFINITION);
        }
        constructor_header

        ({ inLanguage(LANGUAGE_CXX_FAMILY) }? try_statement)*

        ({ inLanguage(LANGUAGE_CXX_FAMILY) }? member_initialization_list)*
;

// constructor definition
constructor_header[] { ENTRY_DEBUG } :

        (options { greedy = true; } : 

            { inLanguage(LANGUAGE_CSHARP) }? attribute |

            specifier |

            { inLanguage(LANGUAGE_JAVA_FAMILY) }? template_argument_list
        )*

        complex_name[true]

        parameter_list
        {
            setMode(MODE_FUNCTION_TAIL);
        }
;

// member initialization list of constructor
member_initialization_list[] { ENTRY_DEBUG } :
        {
            // handle member initialization list as a list of calls
            startNewMode(MODE_LIST | MODE_CALL);

            startElement(SMEMBER_INITIALIZATION_LIST);
        }
        COLON
;

mark_namestack[] { namestack[1] = namestack[0]; namestack[0] = LT(1)->getText(); } :;

identifier_stack[std::string s[]] { s[1] = s[0]; s[0] = LT(1)->getText(); ENTRY_DEBUG } :
        identifier[true]
;

// destructor definition
destructor_definition[] { ENTRY_DEBUG } :
        {
            // statement with nested block
            startNewMode(MODE_STATEMENT | MODE_NEST);

            // start the destructor definition
            startElement(SDESTRUCTOR_DEFINITION);
        }
        destructor_header
;

// destructor declaration
destructor_declaration[] { ENTRY_DEBUG } :
        {
            // just a statement
            startNewMode(MODE_STATEMENT);

            // start the destructor declaration
            startElement(SDESTRUCTOR_DECLARATION);
        }
        destructor_header
;              


// destructor header
destructor_header[] { ENTRY_DEBUG } :

        (options { greedy = true; } : 

            { inLanguage(LANGUAGE_CSHARP) }? attribute |

            specifier |

        { LT(1)->getText() == "void" }? identifier[true]

    )*

        complex_name[true]

        parameter_list
        {
            setMode(MODE_FUNCTION_TAIL);
        }
;              

/*
  call  function call, macro, etc.
*/
call[] { ENTRY_DEBUG } :
        {
            // start a new mode that will end after the argument list
            startNewMode(MODE_ARGUMENT | MODE_LIST);

            // start the function call element
            startElement(SFUNCTION_CALL);
        }
        function_identifier 

        call_argument_list
;

/*
 Argument list for a call, e.g., to a function
*/
call_argument_list[] { ENTRY_DEBUG } :
        {
            // list of parameters
            setMode(MODE_EXPECT | MODE_LIST | MODE_INTERNAL_END_PAREN | MODE_END_ONLY_AT_RPAREN);

            // start the argument list
            startElement(SARGUMENT_LIST);
        }
        LPAREN
;

/*
  call

  function call, macro, etc.
*/

macro_call_check[] { ENTRY_DEBUG } :
        NAME optional_paren_pair
;

eat_optional_macro_call[] {

    bool success = false;

    // find out if we have a macro call
    int start = mark();
    inputState->guessing++;

    try {
        // check for the name
        match(NAME);

        // handle the parentheses
        paren_pair();

        success = true;

    } catch (...) {
    }

    inputState->guessing--;
    rewind(start);

    // when successfull, eat the macro
    if (success)
        macro_call();

    ENTRY_DEBUG
    } :;

macro_call[] { ENTRY_DEBUG } :
        macro_call_inner
        {
            if (inMode(MODE_THEN) && LA(1) == ELSE)
                endCurrentMode(MODE_THEN);
        }
    ;

macro_call_inner[] { CompleteElement element; bool first = true; ENTRY_DEBUG } :

        {
            // start a mode for the macro that will end after the argument list
            startNewMode(MODE_STATEMENT | MODE_TOP);

            // start the macro call element
            startElement(SMACRO_CALL);
        }
        identifier[true]
        (options { greedy = true; } : { first }?
        {
            // start a mode for the macro argument list
            startNewMode(MODE_LIST | MODE_TOP);

            // start the argument list
            startElement(SARGUMENT_LIST);
        }
        LPAREN

        macro_call_contents

        {
            // end anything started inside of the macro argument list
            endDownToMode(MODE_LIST | MODE_TOP);
        }
        RPAREN
        {
            // end the macro argument list
            endCurrentMode(MODE_LIST | MODE_TOP);
        } set_bool[first, false] )*
;
exception
catch[antlr::RecognitionException] {

        // no end found to macro
        if (isoption(parseoptions, OPTION_DEBUG))
            emptyElement(SERROR_PARSE);
}

macro_call_contents[] { 

            ENTRY_DEBUG

            CompleteElement element;

            int parencount = 0;
            bool start = true;
            while (LA(1) != 1 /* EOF? */ && !(parencount == 0 && LA(1) == RPAREN)) {

                if (LA(1) == LPAREN)
                    ++parencount;

                if (LA(1) == RPAREN)
                    --parencount;

                if (inputState->guessing == 0 && start) {
                       // argument with nested expression
                       startNewMode(MODE_ARGUMENT);

                       // start of the try statement
                       startElement(SARGUMENT);

                       start = false;
                }

                if (inputState->guessing == 0 && LA(1) == COMMA && parencount == 0) {
                    endCurrentMode();
                    start = true;
                }
                consume();
            }

        } :;

try_statement[] { ENTRY_DEBUG } :
        {
            // treat try block as nested block statement
            startNewMode(MODE_STATEMENT | MODE_NEST | MODE_TRY);

            // start of the try statement
            startElement(STRY_BLOCK);
        }
        TRY
;

checked_statement[] { ENTRY_DEBUG } :
        {
            // treat try block as nested block statement
            startNewMode(MODE_STATEMENT | MODE_NEST);

            // start of the try statement
            startElement(SCHECKED_STATEMENT);
        }
        CHECKED
;

unsafe_statement[] { ENTRY_DEBUG } :
        {
            // treat try block as nested block statement
            startNewMode(MODE_STATEMENT | MODE_NEST);

            // start of the try statement
            startElement(SUNSAFE_STATEMENT);
        }
        UNSAFE
;

using_statement[] { int type_count = 0; int secondtoken = 0; int fla = 0; DECLTYPE decl_type = NONE; ENTRY_DEBUG } :
        {
            // treat try block as nested block statement
            startNewMode(MODE_STATEMENT | MODE_NEST);

            // start of the try statement
            startElement(SUSING_DIRECTIVE);

            // expect a condition to follow the keyword
            startNewMode(MODE_TOP | MODE_LIST | MODE_EXPECT | MODE_INTERNAL_END_PAREN);
        }
        USING LPAREN
        (
            // explicitly check for a variable declaration since it can easily
            // be confused with an expression
            { perform_noncfg_check(decl_type, secondtoken, fla, type_count) && decl_type == VARIABLE }?
            for_initialization_variable_declaration[type_count] |
            
            {
                // use a new mode without the expect so we don't nest expression parts
                startNewMode(MODE_EXPRESSION);

                // start the expression element
                startElement(SEXPRESSION);
            }
            // explicitly check for non-terminate so that a large switch statement
            // isn't needed
            expression
        )
;

lock_statement[] { int type_count = 0; int secondtoken = 0; int fla = 0; DECLTYPE decl_type = NONE; ENTRY_DEBUG } :
        {
            // treat try block as nested block statement
            startNewMode(MODE_STATEMENT | MODE_NEST);

            // start of the try statement
            startElement(SLOCK_STATEMENT);

            // expect a condition to follow the keyword
            startNewMode(MODE_TOP | MODE_LIST | MODE_EXPECT | MODE_INTERNAL_END_PAREN);
        }
        LOCK LPAREN
        (
            // explicitly check for a variable declaration since it can easily
            // be confused with an expression
            { perform_noncfg_check(decl_type, secondtoken, fla, type_count) && decl_type == VARIABLE }?
            for_initialization_variable_declaration[type_count] |
            
            {
                // use a new mode without the expect so we don't nest expression parts
                startNewMode(MODE_EXPRESSION);

                // start the expression element
                startElement(SEXPRESSION);
            }
            // explicitly check for non-terminate so that a large switch statement
            // isn't needed
            expression
        )
;

unchecked_statement[] { ENTRY_DEBUG } :
        {
            // treat try block as nested block statement
            startNewMode(MODE_STATEMENT | MODE_NEST);

            // start of the try statement
            startElement(SUNCHECKED_STATEMENT);
        }
        UNCHECKED
;

catch_statement[] { ENTRY_DEBUG } :
        {
            // treat catch block as nested block statement
            startNewMode(MODE_STATEMENT | MODE_NEST);

            // start of the catch statement
            startElement(SCATCH_BLOCK);
        }
        CATCH
        {            
            // parameter list is unmarked with a single parameter
            if (LA(1) == LPAREN) {
                match(LPAREN);

                // expect a parameter list
                startNewMode(MODE_PARAMETER | MODE_LIST | MODE_EXPECT);
            }
        }
;

finally_statement[] { ENTRY_DEBUG } :
        {
            // treat catch block as nested block statement
            startNewMode(MODE_STATEMENT | MODE_NEST);

            // start of the catch statement
            startElement(SFINALLY_BLOCK);
        }
        FINALLY
;

lambda_anonymous[] { ENTRY_DEBUG } :
        {
            // treat catch block as nested block statement
            startNewMode(MODE_STATEMENT | MODE_NEST | MODE_ANONYMOUS);
        }
        lambda_marked

        /* completely parse a function until it is done */
        parse_complete_block
;

delegate_anonymous[] { ENTRY_DEBUG } :
        {
            // treat catch block as nested block statement
            startNewMode(MODE_STATEMENT | MODE_NEST | MODE_ANONYMOUS);

            // start of the catch statement
            startElement(SFUNCTION_DEFINITION);
        }
        delegate_marked
        (options { greedy = true; } : parameter_list)*

        /* completely parse a function until it is done */
        parse_complete_block
;

parse_complete_block[] { ENTRY_DEBUG 

    if (inputState->guessing) {

        int blockcount = 0;
        while (LA(1) != 1) {

            if (LA(1) == LCURLY)
                ++blockcount;
            else if (LA(1) == RCURLY)
                --blockcount;

            if (blockcount == 0)
                break;

            consume();
        }
    }
}:

;

delegate_marked[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // treat catch block as nested block statement
            startNewMode(MODE_LOCAL);

            // start of the catch statement
            startElement(SNAME);
        }
        DELEGATE
;

lambda_marked[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // treat catch block as nested block statement
            startNewMode(MODE_LOCAL);

            // start of the catch statement
//            startElement(SNAME);
        }
        LAMBDA
;

fixed_statement[] { ENTRY_DEBUG } :
        {
            // treat catch block as nested block statement
            startNewMode(MODE_STATEMENT | MODE_NEST);

            // start of the catch statement
            startElement(SFIXED_STATEMENT);
        }
        FIXED
        {            
            // looking for a LPAREN.  may have some whitespace before it
            if (LA(1) == LPAREN) {

                parameter_list();
            }
        }
;

throw_statement[] { ENTRY_DEBUG } :
        {
            // statement with expected expression
            startNewMode(MODE_STATEMENT | MODE_EXPRESSION | MODE_EXPECT);

            // start of throw statement
            startElement(STHROW_STATEMENT);
        }
        THROW
;

expression_statement_process[] { ENTRY_DEBUG } :
        {
            // statement with an embedded expression
            startNewMode(MODE_STATEMENT | MODE_EXPRESSION | MODE_EXPECT);

            // start the element which will end after the terminate
            startElement(SEXPRESSION_STATEMENT);
        }
;

expression_statement[CALLTYPE type = NOCALL] { ENTRY_DEBUG } :

        expression_statement_process

        expression[type]
;

/*
  Statement for the declaration of a variable or group of variables
*/
variable_declaration_statement[int type_count] { ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_STATEMENT);

            if (!inTransparentMode(MODE_INNER_DECL) || inTransparentMode(MODE_CLASS))
                // start the declaration statement
                startElement(SDECLARATION_STATEMENT);

            // declaration
            startNewMode(MODE_LOCAL);

            if (!inTransparentMode(MODE_INNER_DECL) || inTransparentMode(MODE_CLASS))
                // start the declaration
                startElement(SDECLARATION);
        }
        variable_declaration[type_count]
;

/*
  Statement for the declaration of a variable or group of variables
*/
short_variable_declaration[] { ENTRY_DEBUG } :
        {
            // declaration
            startNewMode(MODE_LOCAL);

            // start the declaration
            startElement(SDECLARATION);

            // variable declarations may be in a list
            startNewMode(MODE_LIST | MODE_VARIABLE_NAME | MODE_INIT | MODE_EXPECT);
        }
;

/*
  Declaration of a variable

  Example:
    int a;
    int a = b;
    int a, b;
    int a = b, c = d;
*/
variable_declaration[int type_count] { ENTRY_DEBUG } :
        {
            // variable declarations may be in a list
            startNewMode(MODE_LIST | MODE_VARIABLE_NAME | MODE_INIT | MODE_EXPECT);
        }
        variable_declaration_type[type_count]
;

/*
  A simple variable declaration of a single variable including the type,
  name, and initialization block.
*/
variable_declaration_type[int type_count] { ENTRY_DEBUG } :
        {
            // start a mode for the type that will end in this grammar rule
            startNewMode(MODE_EAT_TYPE);

            setTypeCount(type_count);

            // type element begins
            startElement(STYPE);
        }
        lead_type_identifier
        update_var_typecount
;

/*
  Variable declaration name and optional initialization
*/
variable_declaration_nameinit[] { bool isthis = LA(1) == THIS; bool not_csharp = !inLanguage(LANGUAGE_CSHARP); ENTRY_DEBUG } :
        complex_name[true, not_csharp]
        {
            // expect a possible initialization
            setMode(MODE_INIT | MODE_EXPECT);

            if (isthis && LA(1) == LBRACKET) {

                indexer_parameter_list();

                endDownToFirstMode(MODE_LIST);

                match(RBRACKET);

                endCurrentMode(MODE_LOCAL);
                endCurrentMode(MODE_LOCAL);
            }
        }
;

/*
  Initialization of a variable in a declaration.  Does not include the equal sign.
*/
function_pointer_initialization[] { ENTRY_DEBUG } :

        EQUAL
        {
            // end the init correctly
            setMode(MODE_EXPRESSION | MODE_EXPECT);

            // start the initialization element
            startNoSkipElement(SDECLARATION_INITIALIZATION);
        }
        (options { greedy = true; } : expression)*
;

variable_declaration_initialization[] { ENTRY_DEBUG } :

        EQUAL
        {
            // start a new mode that will end after the argument list
            startNewMode(MODE_LIST | MODE_IN_INIT | MODE_EXPRESSION | MODE_EXPECT);

            // start the initialization element
            startNoSkipElement(SDECLARATION_INITIALIZATION);
        } |
        {
            // start a new mode that will end after the argument list
            startNewMode(MODE_LIST | MODE_IN_INIT | MODE_EXPRESSION | MODE_EXPECT);

            // start the initialization element
            startElement(SDECLARATION_INITIALIZATION);
        } IN |
        {
            // start a new mode that will end after the argument list
            startNewMode(MODE_ARGUMENT | MODE_LIST);
        }
        call_argument_list
;

variable_declaration_range[] { ENTRY_DEBUG } :

        COLON
        {
            // start a new mode that will end after the argument list
            startNewMode(MODE_LIST | MODE_IN_INIT | MODE_EXPRESSION | MODE_EXPECT);

            // start the initialization element
            startNoSkipElement(SDECLARATION_RANGE);
        }
;

parameter_declaration_initialization[] { ENTRY_DEBUG } :

        EQUAL
        {
            // end the init correctly
            setMode(MODE_EXPRESSION | MODE_EXPECT);

            // start the initialization element
            startNoSkipElement(SDECLARATION_INITIALIZATION);
        }
;

pure_expression_block[] { ENTRY_DEBUG } :
        lcurly_base 
        {
            // nesting blocks, not statement
            replaceMode(MODE_NEST | MODE_STATEMENT, MODE_BLOCK | MODE_NEST | MODE_END_AT_BLOCK_NO_TERMINATE);

            // end this expression block correctly
            startNewMode(MODE_TOP | MODE_LIST | MODE_EXPRESSION | MODE_EXPECT);
        }
;

/*
  All possible operators
*/
general_operators[] { CompleteElement element; ENTRY_DEBUG } :
        {
            if (isoption(parseoptions, OPTION_OPERATOR)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the modifier
                startElement(SOPERATOR);
            }
        }
        (
        OPERATORS | TEMPOPS |
            TEMPOPE ({ SkipBufferSize() == 0 }? TEMPOPE)? ({ SkipBufferSize() == 0 }? TEMPOPE)? ({ SkipBufferSize() == 0 }? EQUAL)? |
    EQUAL | /*MULTIMM |*/ DESTOP | /* MEMBERPOINTER |*/ MULTOPS | REFOPS | DOTDOT | RVALUEREF | 
            QMARK ({ SkipBufferSize() == 0 }? QMARK)?

/*            general_operators_list (options { greedy = true; } : { SkipBufferSize() == 0 }? general_operators_list)* */ |

            // others are not combined
            NEW | DELETE | IN | IS | STACKALLOC | AS | AWAIT | LAMBDA
        )
;

sole_new[] { CompleteElement element; ENTRY_DEBUG } :
        {
            if (isoption(parseoptions, OPTION_OPERATOR)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the modifier
                startElement(SOPERATOR);
            }
        }
        NEW
;

sole_destop[] { CompleteElement element; ENTRY_DEBUG } :
        {
            if (isoption(parseoptions, OPTION_OPERATOR)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the modifier
                startElement(SOPERATOR);
            }
        }
        DESTOP
;

general_operators_list[] { ENTRY_DEBUG }:
        OPERATORS | TEMPOPS | TEMPOPE | EQUAL | /*MULTIMM |*/ DESTOP | /* MEMBERPOINTER |*/ MULTOPS | REFOPS | DOTDOT | RVALUEREF | QMARK
;

rparen_operator[bool markup = true] { CompleteElement element; ENTRY_DEBUG } :
        {
            if (markup && isoption(parseoptions, OPTION_OPERATOR) && !inMode(MODE_END_ONLY_AT_RPAREN)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the modifier
                startElement(SOPERATOR);
            }
        }
        RPAREN
    ;

rparen[bool markup = true] { bool isempty = getParen() == 0; ENTRY_DEBUG } :
        {
            if (isempty) {

                // additional right parentheses indicates end of non-list modes
                endDownToFirstMode(MODE_LIST | MODE_PREPROC | MODE_END_ONLY_AT_RPAREN, MODE_ONLY_END_TERMINATE);

                // special case:  Get to here, in for-initalization.  Need an extra end mode
                if (inMode(MODE_VARIABLE_NAME) && inTransparentMode(MODE_FOR_CONDITION))
                    endDownToFirstMode(MODE_FOR_CONDITION);

                // don't markup since not a normal operator
                markup = false;

            } else

                decParen();
        }
        rparen_operator[markup]
        {
            if (isempty) {
                
                // special handling for then part of an if statement
                // only when in a condition of an if statement
                if (inMode(MODE_CONDITION) && inPrevMode(MODE_IF)) {

                    // end the condition
                    endDownOverMode(MODE_CONDITION);

                    // then part of the if statement (after the condition)
                    startNewMode(MODE_STATEMENT | MODE_NEST | MODE_THEN);

                    // start the then element
                    startNoSkipElement(STHEN);
                }

                // end the single mode that started the list
                // don't end more than one since they may be nested
                if (inMode(MODE_LIST))
                    endCurrentMode(MODE_LIST);
            }
        }
;

/*
  All possible operators
*/

/*
  Dot (period) operator
*/
period[] { CompleteElement element; ENTRY_DEBUG } :
        {
            if (isoption(parseoptions, OPTION_OPERATOR)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the modifier
                startElement(SOPERATOR);
            }
        }
        PERIOD
;

/*
  Namespace operator '::'
*/
dcolon[] { CompleteElement element; ENTRY_DEBUG } :
        {
            if (isoption(parseoptions, OPTION_OPERATOR)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the modifier
                startElement(SOPERATOR);
            }
        }
        DCOLON
;

/*
   An expression
*/
expression_process[] { ENTRY_DEBUG } : 
        {
            // if expecting an expression start one. except if you are at a right curly brace
            if (inMode(MODE_EXPRESSION | MODE_EXPECT) && LA(1) != RCURLY &&
                !(inMode(MODE_FOR_INCREMENT) && LA(1) == RPAREN)) {

                // use a new mode without the expect so we don't nest expression parts
                startNewMode(MODE_EXPRESSION);

                // start the expression element
                startElement(SEXPRESSION);
            }
        }
;

expression[CALLTYPE type = NOCALL] { ENTRY_DEBUG } : 

        expression_process

        expression_part_plus_linq[type]
;

expression_setup_linq[CALLTYPE type = NOCALL] { ENTRY_DEBUG } : 

        expression_process

        expression_part[type]
;

guessing_startNewMode[State::MODE_TYPE mode]
    { if (inputState->guessing) startNewMode(mode | MODE_GUESSING); ENTRY_DEBUG } : ;

guessing_endDownToMode[State::MODE_TYPE mode]
    { if (inputState->guessing && inTransparentMode(MODE_GUESSING)) endDownToMode(mode | MODE_GUESSING); ENTRY_DEBUG } : ;

guessing_endCurrentModeSafely[State::MODE_TYPE mode]
    { if (inputState->guessing && inTransparentMode(MODE_GUESSING)) endCurrentModeSafely(mode | MODE_GUESSING); ENTRY_DEBUG } : ;

guessing_endGuessing[]
    { if (inTransparentMode(MODE_GUESSING)) endDownOverMode(MODE_GUESSING); ENTRY_DEBUG } : ;

guessing_end[]
    { if (!inputState->guessing && inTransparentMode(MODE_GUESSING)) endDownOverMode(MODE_GUESSING); ENTRY_DEBUG } : ;


/*
   Occurs only within another expression.  The mode is MODE_EXPRESSION.  Only
   elements such as names and function calls are marked up.
*/

expression_part_plus_linq[CALLTYPE type = NOCALL] { guessing_end(); ENTRY_DEBUG } :

        linq_expression | expression_part[type]
    ;

expression_part[CALLTYPE type = NOCALL] { guessing_end(); bool flag; ENTRY_DEBUG } :

        (DELEGATE LPAREN)=> delegate_anonymous |

        (LAMBDA LCURLY)=> lambda_anonymous |

        { inLanguage(LANGUAGE_JAVA_FAMILY) }?
        (NEW template_argument_list)=> sole_new template_argument_list |
        
        { inLanguage(LANGUAGE_JAVA_FAMILY) }?
        (NEW function_identifier paren_pair LCURLY)=> sole_new anonymous_class_definition |

        { notdestructor }? sole_destop { notdestructor = false; } | 

        // call
        // distinguish between a call and a macro
        { type == CALL || (perform_call_check(type, -1) && type == CALL) }?

            // Added argument to correct markup of default parameters using a call.
            // normally call claims left paren and start calls argument.
            // however I believe parameter_list matches a right paren of the call.
            call argument

            guessing_startNewMode[MODE_EXPRESSION | MODE_LIST | MODE_INTERNAL_END_PAREN] |

        // macro call
        { type == MACRO }? macro_call |

        // general math operators
        general_operators 
        {
            if (inLanguage(LANGUAGE_CXX_FAMILY) && LA(1) == DESTOP)
                general_operators();
        }
        | /* newop | */ period |

        // left parentheses
        lparen_marked
        guessing_startNewMode[MODE_INTERNAL_END_PAREN]
        {
            startNewMode(MODE_EXPRESSION | MODE_LIST | MODE_INTERNAL_END_PAREN);

        } |

        // right parentheses that only matches a left parentheses of an expression
        { inTransparentMode(MODE_INTERNAL_END_PAREN) }?
        {
            // stop at this matching paren, or a preprocessor statement
            endDownToFirstMode(MODE_INTERNAL_END_PAREN | MODE_PREPROC); 

            endCurrentModeSafely(MODE_EXPRESSION | MODE_LIST | MODE_INTERNAL_END_PAREN); 
        }
        guessing_endDownToMode[MODE_INTERNAL_END_PAREN]

        guessing_endCurrentModeSafely[MODE_INTERNAL_END_PAREN]

        // treat as operator for operator markup
        rparen[true] |

        // left curly brace
        {
            startNewMode(MODE_EXPRESSION | MODE_LIST);

            startElement(SBLOCK);
        }
        LCURLY
        {
            startNewMode(MODE_EXPRESSION | MODE_EXPECT | MODE_LIST | MODE_INTERNAL_END_CURLY);
        } |

        // right curly brace
        { inTransparentMode(MODE_INTERNAL_END_CURLY) }?
        { 
            endDownToMode(MODE_INTERNAL_END_CURLY);

            endCurrentModeSafely(MODE_INTERNAL_END_CURLY); 
        }
        RCURLY
        { 
            endCurrentModeSafely(MODE_EXPRESSION | MODE_LIST); 
        } |

        // variable or literal
        variable_identifier | string_literal | char_literal | literal | boolean |

        variable_identifier_array_grammar_sub[flag]
;

expression_part_default[CALLTYPE type = NOCALL] { guessing_end(); bool flag; ENTRY_DEBUG } :

        expression_process

        call argument
;

/*
  Only start and end of strings are put directly through the parser.
  The contents of the string are handled as is whitespace.
*/
string_literal[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // only markup strings in literal option
            if (isoption(parseoptions, OPTION_LITERAL)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the string
                startElement(SSTRING);
            }
        }
        (STRING_START STRING_END)
;

/*
  Only start and end of character are put directly through the parser.
  The contents of the character are handled as is whitespace.
*/
char_literal[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // only markup characters in literal option
            if (isoption(parseoptions, OPTION_LITERAL)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the character
                startElement(SCHAR);
            }
        }
        (CHAR_START CHAR_END)
;

literal[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // only markup literals in literal option
            if (isoption(parseoptions, OPTION_LITERAL)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the literal value
                startElement(SLITERAL);
            }
        }
        CONSTANTS
;

boolean[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // only markup boolean values in literal option
            if (isoption(parseoptions, OPTION_LITERAL)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the literal value
                startElement(SBOOLEAN);
            }
        }
        (TRUE | FALSE)
;

derived[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // end all elements at end of rule automatically
            startNewMode(MODE_LOCAL);

            // start the derivation list
            startElement(SDERIVATION_LIST);
        }
        COLON
        (options { greedy = true; } :
            { LA(1) != WHERE }? (
            (derive_access)*

            variable_identifier 
            ({ inLanguage(LANGUAGE_CSHARP) }? period variable_identifier)*

            (options { greedy = true; } : template_argument_list)*
            )
        |
            COMMA
        )*
;

super_list_java[] { ENTRY_DEBUG } :
        {
            // end all elements at end of rule automatically
            startNewMode(MODE_LOCAL);

            // start the derivation list
            startElement(SDERIVATION_LIST);
        }
;

extends_list[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // end all elements at end of rule automatically
            startNewMode(MODE_LOCAL);

            // start the derivation list
            startElement(SEXTENDS);
        }
        EXTENDS
        super_list
;

implements_list[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // end all elements at end of rule automatically
            startNewMode(MODE_LOCAL);

            // start the derivation list
            startElement(SIMPLEMENTS);
        }
        IMPLEMENTS
        super_list
;

super_list[] { bool flag = false; ENTRY_DEBUG } :
        (options { greedy = true; } :
            (derive_access)*

            complex_name_java[true, flag]
        |
            COMMA
        )*
;

derive_access[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // end all elements at end of rule automatically
            startNewMode(MODE_LOCAL);

            startElement(SCLASS_SPECIFIER);
        }
        (VIRTUAL)* (PUBLIC | PRIVATE | PROTECTED) (options { greedy = true; } : VIRTUAL)*
;

parameter_list[] { CompleteElement element; bool lastwasparam = false; bool foundparam = false; ENTRY_DEBUG } :
        {
            // list of parameters
            startNewMode(MODE_PARAMETER | MODE_LIST | MODE_EXPECT);

            // start the parameter list element
            startElement(SPARAMETER_LIST);
        }
        // parameter list must include all possible parts since it is part of
        // function detection
        LPAREN ({ foundparam = true; if (!lastwasparam) empty_element(SPARAMETER, !lastwasparam); lastwasparam = false; } 
        {
            // We are in a parameter list.  Need to make sure we end it down to the start of the parameter list
            if (!inMode(MODE_PARAMETER | MODE_LIST | MODE_EXPECT))
                endCurrentMode(MODE_LOCAL);
        } comma |
        full_parameter { foundparam = lastwasparam = true; })* empty_element[SPARAMETER, !lastwasparam && foundparam] rparen[false]
;

indexer_parameter_list[] { bool lastwasparam = false; bool foundparam = false; ENTRY_DEBUG } :
        {
            // list of parameters
            startNewMode(MODE_PARAMETER | MODE_LIST | MODE_EXPECT);

            // start the parameter list element
            startElement(SPARAMETER_LIST);
        }
        // parameter list must include all possible parts since it is part of
        // function detection
        LBRACKET 
        { startNewMode(MODE_LIST); }
        ({ foundparam = true; if (!lastwasparam) empty_element(SPARAMETER, !lastwasparam); lastwasparam = false; } 
        {
            // We are in a parameter list.  Need to make sure we end it down to the start of the parameter list
//            if (!inMode(MODE_PARAMETER | MODE_LIST | MODE_EXPECT))
//                endCurrentMode(MODE_LOCAL);
        } comma |

        full_parameter { foundparam = lastwasparam = true; })* 
        /* empty_element[SPARAMETER, !lastwasparam && foundparam] */
;

empty_element[int ele, bool cond] { CompleteElement element; ENTRY_DEBUG } :
        {
            if (cond) {
                startNewMode(MODE_LOCAL);

                startElement(ele);
            }
        }
;

kr_parameter[] { ENTRY_DEBUG } : 
        full_parameter terminate_pre terminate_token
;

full_parameter[] { ENTRY_DEBUG } :

        parameter
        (options { greedy = true; } : parameter_declaration_initialization expression)*
;

argument[] { ENTRY_DEBUG } :
        { getParen() == 0 }? rparen[false] |
        {
            // argument with nested expression
            startNewMode(MODE_ARGUMENT | MODE_EXPRESSION | MODE_EXPECT);

            // start the argument
            startElement(SARGUMENT);
        } 
        (
        { !(LA(1) == RPAREN && inTransparentMode(MODE_INTERNAL_END_PAREN)) }? expression |

        type_identifier
        )
;

/*
  Parameter for a function declaration or definition
*/                
parameter[] { int type_count = 0; int secondtoken = 0; int fla = 0; DECLTYPE decl_type = NONE; ENTRY_DEBUG } :
        {
            // end parameter correctly
            startNewMode(MODE_PARAMETER);

            // start the parameter element
            startElement(SPARAMETER);
        }
        (
        { perform_noncfg_check(decl_type, secondtoken, fla, type_count, true) && decl_type == FUNCTION }?
        function[TERMINATE, type_count]

        function_identifier // pointer_name_grammar

        (macro_call_check)*

        parameter_list 

        (options { greedy = true; } : function_pointer_initialization)* |
        {
            // start the declaration element
            startElement(SDECLARATION);

            if (decl_type != VARIABLE)
                type_count = 1;
        }
        { decl_type == VARIABLE || LA(1) == DOTDOTDOT}?
        parameter_type_count[type_count]
        {
            consumeSkippedTokens();

            // expect a name initialization
            setMode(MODE_VARIABLE_NAME | MODE_INIT);
        }
        ( options { greedy = true; } : variable_declaration_nameinit)*
        )
;

/*
*/
parameter_type_count[int type_count] { CompleteElement element; ENTRY_DEBUG } :
        {
            // local mode so start element will end correctly
            startNewMode(MODE_LOCAL);

            // start of type
            startElement(STYPE);
        }
        eat_type[type_count]
        {
            consumeSkippedTokens();
        }

        // sometimes there is no parameter name.  if so, we need to eat it
        ( options { greedy = true; } : multops | tripledotop | LBRACKET RBRACKET)*
;

multops[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // markup type modifiers if option is on
            if (isoption(parseoptions, OPTION_MODIFIER)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the modifier
                startElement(SMODIFIER);
            }
        }
        (MULTOPS | REFOPS | RVALUEREF | { inLanguage(LANGUAGE_CSHARP) }? QMARK set_bool[qmark, true])
;

tripledotop[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // markup type modifiers if option is on
            if (isoption(parseoptions, OPTION_MODIFIER)) {

                // end all elements at end of rule automatically
                startNewMode(MODE_LOCAL);

                // start the modifier
                startElement(SMODIFIER);
            }
        }
        DOTDOTDOT
;

/*
*/
parameter_type[] { CompleteElement element; int type_count = 0; int fla = 0; int secondtoken = 0; DECLTYPE decl_type = NONE; ENTRY_DEBUG } :
        {
            // local mode so start element will end correctly
            startNewMode(MODE_LOCAL);

            // start of type
            startElement(STYPE);
        }
        { perform_noncfg_check(decl_type, secondtoken, fla, type_count) }?
        eat_type[type_count]
;

/*
  Template
*/

/*
  template declaration
*/
template_declaration[] { ENTRY_DEBUG } :
        {
            // template with nested statement (function or class)
            // expect a template parameter list
            startNewMode(MODE_STATEMENT | MODE_NEST | MODE_TEMPLATE);

            // start the template
            startElement(STEMPLATE);
        }
        TEMPLATE 
        {
            startNewMode(MODE_TEMPLATE | MODE_LIST | MODE_EXPECT | MODE_TEMPLATE_PARAMETER_LIST);
        }
;

/*
  template parameter list
*/
template_param_list[] { ENTRY_DEBUG } :
        {
            // start the template parameter list
            startElement(STEMPLATE_PARAMETER_LIST);
        }
        tempops
;

/*
  template parameter

  A template parameter is a subset of a general function parameter
*/
template_param[] { ENTRY_DEBUG } :
        {
            // end parameter correctly
            startNewMode(MODE_PARAMETER);

            // start the parameter element
            startElement(STEMPLATE_PARAMETER);
        }
        (
        parameter_type
        {
            consumeSkippedTokens();
        }
        {
            // expect a name initialization
            setMode(MODE_VARIABLE_NAME | MODE_INIT);
        } |
        template_declaration
    )
;

/*
  template argument list
*/
template_argument_list[] { CompleteElement element; std::string namestack_save[2]; ENTRY_DEBUG } : 
        {
            // local mode
            startNewMode(MODE_LOCAL);

            startElement(STEMPLATE_ARGUMENT_LIST);
        }
        savenamestack[namestack_save]
        tempops (COMMA | template_argument)* tempope 

        (options { greedy = true; } : generic_constraint)*

        restorenamestack[namestack_save]
;

generic_constraint[] { CompleteElement element; ENTRY_DEBUG } : 
        {
            // local mode
            startNewMode(MODE_LOCAL);

            startElement(SWHERE);
        }
        WHERE complex_name COLON 
        (complex_name | CLASS | STRUCT | NEW LPAREN RPAREN)
        (options { greedy = true; } : COMMA (complex_name | CLASS | STRUCT | NEW LPAREN RPAREN))*
;

savenamestack[std::string namestack_save[]] { namestack_save[0] = namestack[0]; namestack_save[1] = namestack[1]; ENTRY_DEBUG } :;

restorenamestack[std::string namestack_save[]] { namestack[0] = namestack_save[0]; namestack[1] = namestack_save[1]; ENTRY_DEBUG } :;

/*
  template argument
*/
template_argument[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // local mode
            startNewMode(MODE_LOCAL);

            startElement(STEMPLATE_ARGUMENT);
        }
        ( options { greedy = true; } : 
            { LA(1) != SUPER && LA(1) != QMARK }?
            type_identifier |

            literal | char_literal | string_literal | boolean | 

            template_extends_java |

            template_super_java | qmark_marked
        )+
;

template_extends_java[] { CompleteElement element; bool iscomplex = false; ENTRY_DEBUG } :
        {
            startNewMode(MODE_LOCAL);

            startElement(SEXTENDS);
        }
        EXTENDS
        complex_name_java[true, iscomplex]
;


template_super_java[] { CompleteElement element; bool iscomplex = false; ENTRY_DEBUG } :
        {
            startNewMode(MODE_LOCAL);

            startElement(SDERIVATION_LIST);
        }
        SUPER
        complex_name_java[true, iscomplex]
;


tempops[] { ENTRY_DEBUG } :
        {
            // make sure we are in a list mode so that we can end correctly
            // some uses of tempope will have their own mode
            if (!inMode(MODE_LIST))
                startNewMode(MODE_LIST);
        }
        TEMPOPS
;

tempope[] { ENTRY_DEBUG } :
        {
            // end down to the mode created by the start template operator
            endDownToMode(MODE_LIST);
        }
        TEMPOPE
        {
            // end the mode created by the start template operator
            endCurrentModeSafely(MODE_LIST);
        }
;

/*
  label statement
*/
label_statement[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_STATEMENT);

            // start the label element
            startElement(SLABEL_STATEMENT);
        } 
        identifier[true] COLON
;

/*
  typedef_statement
*/
typedef_statement[] { ENTRY_DEBUG } :
        {
            // statement
            startNewMode(MODE_STATEMENT | MODE_EXPECT | MODE_VARIABLE_NAME | MODE_ONLY_END_TERMINATE);

            // start the typedef element
            startElement(STYPEDEF);

            startNewMode(MODE_NEST | MODE_STATEMENT | MODE_INNER_DECL | MODE_TYPEDEF | MODE_END_AT_BLOCK_NO_TERMINATE);
        }
        TYPEDEF
;

paren_pair[] :
        LPAREN (paren_pair | ~(LPAREN | RPAREN))* RPAREN
;

optional_paren_pair[] {

    if (LA(1) != LPAREN)
        return;

    consume();

    int parencount = 1;
    while (parencount > 0 && LA(1) != antlr::Token::EOF_TYPE) {

        if (LA(1) == RPAREN)
            --parencount;
        else if (LA(1) == LPAREN)
            ++parencount;

        consume();
    }

    ENTRY_DEBUG
} :;

/*
  See if there is a semicolon terminating a statement inside a block at the top level
*/        
nested_terminate[] {

    int parencount = 0;
    int bracecount = 0;
    while (LA(1) != antlr::Token::EOF_TYPE) {

        if (LA(1) == RPAREN)
            --parencount;
        else if (LA(1) == LPAREN)
            ++parencount;

        if (LA(1) == RCURLY)
            --bracecount;
        else if (LA(1) == LCURLY)
            ++bracecount;

        if (bracecount < 0)
            break;

        if (LA(1) == TERMINATE && parencount == 0 && bracecount == 0)
            break;

        consume();
    }
}:
        TERMINATE
;
        
/*
  Definition of an enum.  Start of the enum only
*/
enum_definition[] { ENTRY_DEBUG } :
        { inLanguage(LANGUAGE_JAVA_FAMILY) }?
        (enum_class_definition nested_terminate)=> enum_class_definition |

        { inLanguage(LANGUAGE_JAVA_FAMILY) || inLanguage(LANGUAGE_CSHARP) }?
        {
            // statement
            // end init correctly
            startNewMode(MODE_STATEMENT | MODE_EXPRESSION_BLOCK | MODE_VARIABLE_NAME | MODE_EXPECT | MODE_ENUM | MODE_END_AT_BLOCK);

            // start the enum definition element
            startElement(SENUM);
        }
        ({ inLanguage(LANGUAGE_CSHARP) }? attribute)* (specifier)*
        ENUM |
        {
            // statement
            // end init correctly
            startNewMode(MODE_STATEMENT | MODE_EXPRESSION_BLOCK | MODE_VARIABLE_NAME | MODE_EXPECT | MODE_ENUM);

            // start the enum definition element
            startElement(SENUM);
        }
        ENUM
;

/*
  Complete definition of an enum.  Used for enum's embedded in typedef's where the entire
  enum must be parsed since it is part of the type.
*/
enum_definition_whole[] { CompleteElement element; ENTRY_DEBUG } :
        enum_definition

        (variable_identifier)*

        // start of enum definition block

        {
            startNewMode(MODE_TOP | MODE_LIST | MODE_EXPRESSION | MODE_EXPECT | MODE_BLOCK | MODE_NEST);

            startElement(SBLOCK);
        }
        LCURLY

        (options { greedy = true; } : { LA(1) != RCURLY || inTransparentMode(MODE_INTERNAL_END_CURLY) }?
        expression | comma)*

        // end of enum definition block
        {
            endDownToMode(MODE_TOP | MODE_LIST | MODE_EXPRESSION | MODE_EXPECT | MODE_BLOCK | MODE_NEST);
        }
        RCURLY
;

/*
  end of file

  Reached the end of the input.  Must now make sure to end any open elements.  Open elements indicate
  either syntax error in the code, or a translation error.

  EOF marks the end of all processing, so it must occur after any ending modes
*/
eof[] :
        {
            // end all modes
            endAllModes();
        }
        EOF
;

/*
    Preprocessor

    Match on the directive itself not the entire directive
*/
preprocessor[] {
        int directive_token = 0;
        bool markblockzero = false;

        TokenPosition tp;

        // parse end of line
        startNewMode(MODE_PARSE_EOL);

        // mode for any preprocessor elements
        startNewMode(MODE_PREPROC);
        } :
        {
            // assume error.  will set to proper one later
            startElement(SCPP_ERROR);

            setTokenPosition(tp);
        }
        PREPROC markend[directive_token]
        {
            startNewMode(MODE_LOCAL);

            startElement(SCPP_DIRECTIVE);
        }
        (
        INCLUDE
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_INCLUDE);
        }
        cpp_filename |

        DEFINE
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_DEFINE);
        }
        cpp_symbol_optional |

        IFNDEF
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_IFNDEF);
        }
        cpp_symbol_optional |

        UNDEF
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_UNDEF);
        }
        cpp_symbol_optional |

        IF
            { markblockzero = false; }
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_IF);
        }
        cpp_condition[markblockzero] |

        ELIF
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_ELIF);
        }
        cpp_condition[markblockzero] |

        ELSE
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_ELSE);
        } |

        ENDIF
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_ENDIF);
        } |

        IFDEF
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_IFDEF);
        }
            cpp_symbol_optional |

        LINE
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_LINE);
        }
            cpp_linenumber

            cpp_filename |

        PRAGMA
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_PRAGMA);
        } |

        ERRORPREC
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_ERROR);
        } |

        NAME
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_ERROR);
        } |

        REGION
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_REGION);
        } |

        ENDREGION
        {
            endCurrentMode(MODE_LOCAL);

            tp.setType(SCPP_ENDREGION);
        } |

        /* blank preproc */

        /* skip over anything, start with stuff defined before */
        (~(NAME | ERRORPREC | INCLUDE | DEFINE | IF | ENDIF | IFNDEF | UNDEF | ELIF | ELSE | IFDEF | LINE | PRAGMA | EOL | LINECOMMENT_START | COMMENT_START | JAVADOC_COMMENT_START | REGION | ENDREGION))?

        )
        eol_skip[directive_token, markblockzero]
;
exception
catch[antlr::RecognitionException] {
        eol_skip(directive_token, markblockzero);
}

eol_skip[int directive_token, bool markblockzero] { 

    while (LA(1) != EOL && 
           LA(1) != LINECOMMENT_START && 
           LA(1) != COMMENT_START && 
           LA(1) != JAVADOC_COMMENT_START && 
           LA(1) != 1 /* EOF? */
        )
                consume();
    ENTRY_DEBUG } :
    eol[directive_token, markblockzero]
;

/*
  end of line

  Only used for ending preprocessor, and only those directives who end on the current
  line.
*/
eol[int directive_token, bool markblockzero] {
            // end all preprocessor modes
            endDownToMode(MODE_PREPROC);

            endCurrentMode(MODE_PREPROC);

            endCurrentMode(MODE_PARSE_EOL);
ENTRY_DEBUG } :
        (EOL | LINECOMMENT_START | eof)
        eol_post[directive_token, markblockzero]
;

eol_post[int directive_token, bool markblockzero] {
            // Flags to control skipping of #if 0 and #else.
            // Once in these modes, stay in these modes until the matching #endif is reached
            // cppifcount used to indicate which #endif matches the #if or #else
            switch (directive_token) {

                case IF :
                case IFDEF :
                case IFNDEF :

                    // start a new blank mode for new zero'ed blocks
                    if (!cpp_zeromode && markblockzero) {

                        // start a new blank mode for if
                        cpp_zeromode = true;

                        // keep track of nested if's (inside the #if 0) so we know when
                        // we reach the proper #endif
                        cppifcount = 0;
                    }

                    // another if reached
                    ++cppifcount;

                    // create new context for #if (and possible #else)
                    if (checkOption(OPTION_CPP_MARKUP_ELSE) && !inputState->guessing) {

                        cppmode.push(cppmodeitem(size()));
                    }

                    break;

                case ELSE :
                case ELIF :

                    // #else reached for #if 0 that started this mode
                    if (cpp_zeromode && cppifcount == 1)
                        cpp_zeromode = false;

                    // not in skipped #if, so skip #else until #endif of #if is reached
                    if (!cpp_zeromode) {
                        skipelse = true;
                        cppifcount = 1;
                    }

                    if (!checkOption(OPTION_CPP_MARKUP_ELSE) && !inputState->guessing) {

                        // create an empty cppmode for #if if one doesn't exist
                        if (cppmode.empty())
                            cppmode.push(cppmodeitem(size()));

                        // add new context for #else in current #if
                        cppmode.top().statesize.push_back(size()); 
                    
                        if (!cpp_zeromode) {
                            if (cppmode.top().statesize.front() > size())
                                cppmode.top().skipelse = true;
                        }
                    }

                    break;

                case ENDIF :

                    // another #if ended
                    --cppifcount;

                    // #endif reached for #if 0 that started this mode
                    if (cpp_zeromode && cppifcount == 0)
                        cpp_zeromode = false;

                    // #endif reached for #else that started this mode
                    if (skipelse && cppifcount == 0)
                        skipelse = false;

                    if (!checkOption(OPTION_CPP_MARKUP_ELSE) && !inputState->guessing &&
                        !cppmode.empty()) {

                        // add new context for #endif in current #if
                        cppmode.top().statesize.push_back(size()); 

                        // reached #endif so finished adding to this mode
                        cppmode.top().isclosed = true;

                        // remove any finished modes
                        cppmode_cleanup();
                    }

                default :
                    break;
            }

        /*
            Skip elements when:
                - in zero block (cpp_zeromode) and not marking #if 0
                - when processing only #if part, not #else
                - when guessing and in else (unless in zero block)
                - when ??? for cppmode
        */
        if ((!checkOption(OPTION_CPP_MARKUP_IF0) && cpp_zeromode) ||
            (!checkOption(OPTION_CPP_MARKUP_ELSE) && skipelse) ||
            (inputState->guessing && skipelse) ||
            (!cppmode.empty() && !cppmode.top().isclosed && cppmode.top().skipelse)
        ) {
            while (LA(1) != PREPROC && LA(1) != 1 /* EOF */)
                consume();
        }

        ENTRY_DEBUG } :
;

// remove any finished or unneeded cppmodes
cppmode_cleanup[] {

        bool equal = true;
        for (unsigned int i = 0; i < cppmode.top().statesize.size(); ++i) {
            if (cppmode.top().statesize[i] != cppmode.top().statesize[0])
                equal = false;
            }

            if (!cppmode.empty() && (equal || cppmode.top().statesize.size() == 2)) {
                cppmode.pop();
            }
        ENTRY_DEBUG } :
;

// ended modes that may lead to needed updates
cppmode_adjust[] {

    if (checkOption(OPTION_CPP_MARKUP_ELSE) && !cppmode.empty() && 
        cppmode.top().isclosed == true &&
        size() < cppmode.top().statesize.back()) {

           if (size() == cppmode.top().statesize[cppmode.top().statesize.size() - 1 - 1]) {
                
                // end if part of cppmode
                while (size() > cppmode.top().statesize.front())
                    endCurrentMode();

                // done with this cppmode
                cppmode.pop();
           }
    }

    ENTRY_DEBUG } :
;

line_continuation[] { ENTRY_DEBUG } :
        {
            // end all preprocessor modes
            endDownOverMode(MODE_PARSE_EOL);
        }
        EOL_BACKSLASH
;

cpp_condition[bool& markblockzero] { CompleteElement element; ENTRY_DEBUG } :

        set_bool[markblockzero, LA(1) == CONSTANTS && LT(1)->getText() == "0"]

        full_expression
;

cpp_symbol[] { CompleteElement element; ENTRY_DEBUG } :
        {
            // end all started elements in this rule
            startNewMode(MODE_LOCAL);

            // start of the name element
            startElement(SNAME);
        }
        NAME
;

cpp_symbol_optional[] { ENTRY_DEBUG } :
        (options { greedy = true; } : cpp_symbol)*
;

cpp_filename[] { CompleteElement element; ENTRY_DEBUG } :
        (
        {
            startNewMode(MODE_PREPROC);

            startElement(SCPP_FILENAME);
        }
        (string_literal | char_literal | TEMPOPS (~(TEMPOPE))* TEMPOPE))*
;

cpp_linenumber[] :
        (options { greedy = true; } : literal)*
;
