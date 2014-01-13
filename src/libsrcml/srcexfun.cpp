/*
  srcexfun.cpp

  Copyright (C) 2009-2014  SDML (www.srcML.org)

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

#include <srcexfun.hpp>
#include <srcmlns.hpp>
#include <cmath>
#include <cstring>
#include <string>

#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>
#include <libxml/parserInternals.h>
#include <libxml/xmlreader.h>

/*
  static xmlChar* unit_directory = 0;
  static xmlChar* unit_filename = 0;
*/

#include <libxml/tree.h>

#if defined(__GNUG__) && !defined(__MINGW32__) && !defined(NO_DLLOAD)
#include <dlfcn.h>
#else
#include <libxslt/xsltutils.h>
#include <libxslt/xsltInternals.h>
#include <libxslt/extensions.h>
#endif

#include <URIStream.hpp>

static int Position;
static PROPERTIES_TYPE* oldpattributes;
static const xmlChar** pattributes;
static int nb_attributes;

static std::vector<struct xpath_ext_function> MACROS;

void setPosition(int n) {
  Position = n;
}

void setRootAttributes(const xmlChar** attributes, int pnb_attributes) {
  pattributes = attributes;
  nb_attributes = pnb_attributes;
}

void setRootAttributes(PROPERTIES_TYPE& attributes) {
  oldpattributes = &attributes;
}

//
static void srcContextFunction (xmlXPathParserContextPtr ctxt, int nargs) {

  if (nargs != 0) {
    xmlXPathSetArityError(ctxt);
    return;
  }

  fprintf(stderr, "DEBUG:  %s %s %d\n", __FILE__,  __FUNCTION__, __LINE__);

  valuePush(ctxt, xmlXPathNewFloat(Position));
}

static void srcRootFunction (xmlXPathParserContextPtr ctxt, int nargs) {

  if (nargs != 1) {
    xmlXPathSetArityError(ctxt);
    return;
  }

  xmlChar* name = xmlXPathPopString(ctxt);

  int n = find_attribute_index(nb_attributes, pattributes, (const char*) name);
  if (n == -1) {
    valuePush(ctxt, NULL);
    return;
  }

  std::string s(pattributes[n + 3], pattributes[n + 4]);

  valuePush(ctxt, xmlXPathNewString(BAD_CAST s.c_str()));
}

static void srcMacrosFunction (xmlXPathParserContextPtr ctxt, int nargs) {

  // as of now, all of these have no arguments
  if (nargs != 0) {
    xmlXPathSetArityError(ctxt);
    return;
  }

  // find out which expression is being used based on the name
  unsigned int i;
  for (i = 0; i < MACROS.size(); ++i)
    if (strcmp(MACROS[i].name.c_str(), (const char*) ctxt->context->function) == 0)
      break;

  // evaluate the expression on the given context
  xmlXPathObjectPtr ret = xmlXPathEval(BAD_CAST MACROS[i].expr.c_str(), ctxt->context);

  if (ret) {
    valuePush(ctxt, ret);
  }
}

static void srcInFunction (xmlXPathParserContextPtr ctxt, int nargs) {

  // need at least one argument
  if (nargs == 0) {
    xmlXPathSetArityError(ctxt);
    return;
  }

  // find the first xpath that produces a result
  for (int i = 0; i < nargs; ++i) {

    std::string path = "ancestor::";

    // find the name of the element
    xmlChar* name = xmlXPathPopString(ctxt);

    path.append((const char*) name);

    // evaluate the expression on the given context
    xmlXPathObjectPtr ret = xmlXPathEval(BAD_CAST path.c_str(), ctxt->context);
    if (ret) {
      valuePush(ctxt, xmlXPathNewBoolean(1));
      return;
    }
  }

  valuePush(ctxt, xmlXPathNewBoolean(0));
}

static void srcPowersetFunction (xmlXPathParserContextPtr ctxt, int nargs) {

  if (nargs != 1) {
    xmlXPathSetArityError(ctxt);
    return;
  }

  // node set to form powerset over
  xmlNodeSetPtr master = xmlXPathPopNodeSet(ctxt);

  // node set of sets
  xmlNodeSetPtr ret = xmlXPathNodeSetCreate(NULL);

  // number of sets
  int setsize = pow(2, master->nodeNr);

  // create all the sets
  for (int setnum = 0; setnum < setsize; ++setnum) {

    // set node
    xmlNodePtr setnode = xmlNewNodeEatName(0, (xmlChar*)"set");
    xmlXPathNodeSetAdd(ret, setnode);

    // create this set, only leaving in what fits the bit position
    for (int i = 0; i < master->nodeNr; ++i) {

      if (setnum & (1 << i)) {
        xmlNodePtr node = xmlCopyNode(master->nodeTab[i], 1);
        xmlAddChild(setnode, node);
      }
    }
  }

  if (ret) {
    valuePush(ctxt, xmlXPathNewNodeSetList(ret));
  }
}

void xpathsrcMLRegister(xmlXPathContextPtr context) {

  xmlXPathRegisterFuncNS(context, (const xmlChar *)"unit",
                         BAD_CAST SRCML_SRC_NS_URI,
                         srcContextFunction);

  xmlXPathRegisterFuncNS(context, (const xmlChar *)"archive",
                         BAD_CAST SRCML_SRC_NS_URI,
                         srcRootFunction);

  xmlXPathRegisterFuncNS(context, (const xmlChar *)"powerset",
                         BAD_CAST SRCML_SRC_NS_URI,
                         srcPowersetFunction);

  // register all the xpath extension functions
  for (unsigned int i = 0; i < MACROS.size(); ++i) {

    xmlXPathRegisterFuncNS(context, BAD_CAST MACROS[i].name.c_str(),
                           BAD_CAST MACROS[i].prefix.c_str(),
                           srcMacrosFunction);
  }

  xmlXPathRegisterFuncNS(context, (const xmlChar *)"in",
                         BAD_CAST SRCML_SRC_NS_URI,
                         srcInFunction);
}

void xsltsrcMLRegister () {

#if defined(__GNUG__) && !defined(__MINGW32__) && !defined(NO_DLLOAD)
  typedef int (*xsltRegisterExtModuleFunction_function) (const xmlChar *, const xmlChar *, xmlXPathFunction);
  void* handle = dlopen("libexslt.so", RTLD_LAZY);
  if (!handle) {
    handle = dlopen("libexslt.so.0", RTLD_LAZY);
    if (!handle) {
      handle = dlopen("libexslt.dylib", RTLD_LAZY);
      if (!handle) {
        fprintf(stderr, "Unable to open libexslt library\n");
        return;
      }
    }
  }

  dlerror();
  xsltRegisterExtModuleFunction_function xsltRegisterExtModuleFunction = (xsltRegisterExtModuleFunction_function)dlsym(handle, "xsltRegisterExtModuleFunction");
  char* error;
  if ((error = dlerror()) != NULL) {
    dlclose(handle);
    return;
  }
#endif

  xsltRegisterExtModuleFunction(BAD_CAST "unit",
                                BAD_CAST SRCML_SRC_NS_URI,
                                srcContextFunction);

  xsltRegisterExtModuleFunction(BAD_CAST "archive",
                                BAD_CAST SRCML_SRC_NS_URI,
                                srcRootFunction);

  xsltRegisterExtModuleFunction(BAD_CAST "powerset",
                                BAD_CAST SRCML_SRC_NS_URI,
                                srcPowersetFunction);

  // register all the xpath extension functions
  for (unsigned int i = 0; i < MACROS.size(); ++i) {

    xsltRegisterExtModuleFunction(BAD_CAST MACROS[i].name.c_str(),
                                  BAD_CAST MACROS[i].prefix.c_str(),
                                  srcMacrosFunction);
  }

#if defined(__GNUG__) && !defined(__MINGW32__) && !defined(NO_DLLOAD)
  dlclose(handle);
#endif
}

void xpathRegisterExtensionFunction(const std::string& prefix, const std::string & name, const std::string & xpath) {

  xpath_ext_function xpath_function = {prefix, name, xpath};

  MACROS.push_back(xpath_function);
}

const std::vector<xpath_ext_function> getXPathExtensionFunctions() {

  return MACROS;
}
