/*
  srcMLToken.hpp

  Copyright (C) 2004-2013  SDML (www.sdml.info)

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
*/

/*
  Specialized token for srcML markup elements.
*/

#ifndef INCLUDED_SRCMLTOKEN_HPP
#define INCLUDED_SRCMLTOKEN_HPP

#include <antlr/Token.hpp>
#include <antlr/TokenRefCount.hpp>

enum { STARTTOKEN = 0, ENDTOKEN = 50, EMPTYTOKEN = 75 };

class srcMLToken : public antlr::Token {
    friend bool isstart(const antlr::RefToken& token);
    friend bool isempty(const antlr::RefToken& token);

public:
    srcMLToken()
        : Token(), category(-1) {
    }

    srcMLToken(int t, int cat)
        : Token(t), category(cat) {
    }

    static antlr::RefToken factory() {
        return new srcMLToken();
    }

    virtual void setLine(int l) { line = l; }
    virtual int getLine() const { return line; }

    virtual void setColumn(int c) { column = c; }
    virtual int getColumn() const { return column; }

    // current text of the token
    virtual std::string getText() const { return text; }

    // set the current text of the token
    virtual void setText(const std::string& s) { text = s; }

    // destructor
    virtual ~srcMLToken() {}

    int category;
    int line;
    int column;
    std::string text;
};

inline srcMLToken* EndTokenFactory(int token) {

    return new srcMLToken(token, ENDTOKEN);
}

inline srcMLToken* EmptyTokenFactory(int token) {

    return new srcMLToken(token, EMPTYTOKEN);
}

inline srcMLToken* StartTokenFactory(int token) {

    return new srcMLToken(token, STARTTOKEN);
}

inline bool isstart(const antlr::RefToken& token) {

    return static_cast<const srcMLToken*>(&(*token))->category != ENDTOKEN;
}

inline bool isempty(const antlr::RefToken& token) {

    return static_cast<const srcMLToken*>(&(*token))->category == EMPTYTOKEN;
}

#endif
