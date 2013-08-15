/*
  srcexfun.hpp

  Copyright (C) 2009-2010  SDML (www.sdml.info)

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

#ifndef INCLUDED_SRCEXFUN_HPP
#define INCLUDED_SRCEXFUN_HPP

#include <libxml/xpath.h>
#include "SAX2Utilities.hpp"
#include <vector>

void setPosition(int n);

void setRootAttributes(const xmlChar** attributes, int pnb_attributes);

void setRootAttributes(PROPERTIES_TYPE&);

void xsltsrcMLRegister();

void xpathsrcMLRegister(xmlXPathContextPtr context);

struct xpath_ext_function {

    std::string prefix;
    std::string name;
    std::string expr;
};

void xpathRegisterExtensionFunction(const std::string& uri, const std::string & name, const std::string & xpath);

const std::vector<xpath_ext_function> getXPathExtensionFunctions();

#endif
