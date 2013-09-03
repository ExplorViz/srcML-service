/*
  XSLTUnits.cpp

  Copyright (C) 2008-2013  SDML (www.sdml.info)

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

#ifndef INCLUDED_XSLTUNITS_HPP
#define INCLUDED_XSLTUNITS_HPP

#include <sstream>

#include <libxml/parser.h>
#include <libxml/xpath.h>

#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>

#include <libxslt/transform.h>

#define SIZEPLUSLITERAL(s) sizeof(s) - 1, s
#define LITERALPLUSSIZE(s) s, sizeof(s) - 1

#include "srcexfun.hpp"

#include "UnitDOM.hpp"

#if defined(__GNUG__) && !defined(__MINGW32__)
typedef xmlDocPtr (*xsltApplyStylesheetUser_function) (xsltStylesheetPtr,xmlDocPtr,const char **,const char *, FILE *,
                                                       xsltTransformContextPtr);
typedef xmlDocPtr (*xsltApplyStylesheet_function) (xsltStylesheetPtr,xmlDocPtr,const char **);

xsltApplyStylesheetUser_function xsltApplyStylesheetUserDynamic;
xsltApplyStylesheet_function xsltApplyStylesheetDynamic;

//typedef int (*xsltSaveResultTo_function) (xmlOutputBufferPtr, xmlDocPtr, xsltStylesheetPtr);
//xsltSaveResultTo_function xsltSaveResultToDynamic;
#else
#include <libxslt/xslt.h>
#include <libxslt/xsltInternals.h>
#include <libxslt/xsltutils.h>

#include <libexslt/exslt.h>
#endif

class XSLTUnits : public UnitDOM {
public :

    XSLTUnits(const char* a_context_element, const char* a_ofilename, OPTION_TYPE & options, xsltStylesheetPtr stylesheet,
              const char** params, int fd = 0)
        : UnitDOM(options), ofilename(a_ofilename), options(options),
          stylesheet(stylesheet), total(0), found(false), needroot(true),
          result_type(0), params(params), fd(fd) {

#if defined(__GNUG__) && !defined(__MINGW32__)
        void* handle = dlopen("libxslt.so", RTLD_LAZY);
        if (!handle) {
            handle = dlopen("libxslt.dylib", RTLD_LAZY);
            if (!handle) {
                fprintf(stderr, "Unable to open libxslt library\n");
                return;
            }
        }

        dlerror();
        xsltApplyStylesheetUserDynamic = (xsltApplyStylesheetUser_function)dlsym(handle, "xsltApplyStylesheetUser");
        char* error;
        if ((error = dlerror()) != NULL) {
            dlclose(handle);
            return;
        }
        dlerror();
        xsltApplyStylesheetDynamic = (xsltApplyStylesheet_function)dlsym(handle, "xsltApplyStylesheet");
        if ((error = dlerror()) != NULL) {
            dlclose(handle);
            return;
        }
/*
  dlerror();
  xsltSaveResultToDynamic = (xsltSaveResultTo_function)dlsym(handle, "xsltSaveResultTo");
  if ((error = dlerror()) != NULL) {
  dlclose(handle);
  return;
  }
*/
#endif

    }

    virtual ~XSLTUnits() {}

    virtual void startOutput(void* ctx) {

        // setup output
        buf = xmlOutputBufferCreateFilename(ofilename, NULL, 0);
        // TODO:  Detect error

    }

    virtual bool apply(void* ctx) {

        xmlParserCtxtPtr ctxt = (xmlParserCtxtPtr) ctx;
        SAX2ExtractUnitsSrc* pstate = (SAX2ExtractUnitsSrc*) ctxt->_private;

        setPosition(pstate->count);

        // apply the style sheet to the document, which is the individual unit
#if defined(__GNUG__) && !defined(__MINGW32__)
        xmlDocPtr res = xsltApplyStylesheetUserDynamic(stylesheet, ctxt->myDoc, params, 0, 0, 0);
//      xmlDocPtr res = xsltApplyStylesheetDynamic(stylesheet, ctxt->myDoc, 0);
#else
        xmlDocPtr res = xsltApplyStylesheetUser(stylesheet, ctxt->myDoc, params, 0, 0, 0);
#endif
        if (!res) {
            fprintf(stderr, "srcml2src:  Error in applying stylesheet\n");
            exit(1);
        }

        // only interestd in non-empty results
        if (res && res->children) {

            // determine the type of data that is going to be output
            if (!found)
                result_type = res->children->type;

	    // output the xml declaration, if needed
	    if (result_type == XML_ELEMENT_NODE && !found && !isoption(options, OPTION_XMLDECL))
	      xmlOutputBufferWriteXMLDecl(ctxt, buf);

            // output the root unit start tag
            // this is only if in per-unit mode and this is the first result found
            // have to do so here because it may be empty
            if (result_type == XML_ELEMENT_NODE && pstate->isarchive && !found && !isoption(options, OPTION_XSLT_ALL)) {

                // output a root element, just like the one read in
                // note that this has to be ended somewhere
                xmlOutputBufferWriteElementNs(buf, pstate->root.localname, pstate->root.prefix, pstate->root.URI,
                                              pstate->root.nb_namespaces, pstate->root.namespaces,
                                              pstate->isarchive ? pstate->root.nb_attributes : 0, pstate->root.nb_defaulted, pstate->root.attributes);

                xmlOutputBufferWrite(buf, SIZEPLUSLITERAL(">\n\n"));
            }
            found = true;

            // save the result, but temporarily hide the namespaces since we only want them on the root element
            xmlNodePtr resroot = xmlDocGetRootElement(res);
            xmlNsPtr savens = resroot ? resroot->nsDef : 0;
            bool turnoff_namespaces = savens && pstate->isarchive && !isoption(options, OPTION_XSLT_ALL);

            if (turnoff_namespaces) {
                xmlNsPtr cur = savens;
                xmlNsPtr ret = NULL;
                xmlNsPtr p = NULL;

                while (cur != NULL) {
                    if (strcmp((const char*) cur->href, SRCML_CPP_NS_URI) == 0) {
                        xmlNsPtr q = xmlCopyNamespace(cur);
                        if (p == NULL) {
                            ret = p = q;
                        } else {
                            p->next = q;
                            p = q;
                        }
                    }
                    cur = cur->next;
                }
                resroot->nsDef = ret;
            }
/*
  #if defined(__GNUG__) && !defined(__MINGW32__)
  xsltSaveResultToDynamic(buf, res, stylesheet);
  #else
  xsltSaveResultTo(buf, res, stylesheet);
  #endif
*/
            // output the transformed result
            for (xmlNodePtr child = res->children; child != NULL; child = child->next)
              if (child->type == XML_TEXT_NODE)
                xmlOutputBufferWriteString(buf, (const char *) child->content);
	      else
                xmlNodeDumpOutput(buf, res, child, 0, 0, 0);

            if (turnoff_namespaces) {
                xmlFreeNsList(resroot->nsDef);

                resroot->nsDef = savens;
            }

            // put some space between this unit and the next one if compound
            if (result_type == XML_ELEMENT_NODE && pstate->isarchive && !isoption(options, OPTION_XSLT_ALL))
                xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\n\n"));

            // finished with the result of the transformation
            // TODO:  Get rid of this memory leak.
//            xmlFreeDoc(res);
        }

        return true;
    }
    virtual void endOutput(void *ctx) {

        xmlParserCtxtPtr ctxt = (xmlParserCtxtPtr) ctx;
        SAX2ExtractUnitsSrc* pstate = (SAX2ExtractUnitsSrc*) ctxt->_private;

        // root unit end tag
        if (result_type == XML_ELEMENT_NODE && found && pstate->isarchive && !isoption(options, OPTION_XSLT_ALL)) {

            xmlOutputBufferWriteString(buf, found ? "</unit>\n" : "/>\n");

        } else if (result_type == XML_ELEMENT_NODE && found && !pstate->isarchive) {
	    xmlOutputBufferWriteString(buf, "\n");
        }

        // all done with the buffer
        xmlOutputBufferClose(buf);
    }

    static void xmlOutputBufferWriteXMLDecl(xmlParserCtxtPtr ctxt, xmlOutputBufferPtr buf) {

        xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("<?xml version=\""));
        xmlOutputBufferWriteString(buf, (const char*) ctxt->version);
        xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\" encoding=\""));
        xmlOutputBufferWriteString(buf, (const char*) (ctxt->encoding ? ctxt->encoding : ctxt->input->encoding));
        xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\" standalone=\""));
        xmlOutputBufferWriteString(buf, ctxt->standalone ? "yes" : "no");
        xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\"?>\n"));
    }

    static void xmlOutputBufferWriteElementNs(xmlOutputBufferPtr buf, const xmlChar* localname, const xmlChar* prefix,
                                              const xmlChar* URI, int nb_namespaces, const xmlChar** namespaces,
                                              int nb_attributes, int nb_defaulted, const xmlChar** attributes) {

        xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("<"));
        if (prefix != NULL) {
            xmlOutputBufferWriteString(buf, (const char*) prefix);
            xmlOutputBufferWrite(buf, SIZEPLUSLITERAL(":"));
        }
        xmlOutputBufferWriteString(buf, (const char*) localname);

        // output the namespaces
        for (int i = 0; i < nb_namespaces; ++i) {

            xmlOutputBufferWrite(buf, SIZEPLUSLITERAL(" xmlns"));
            if (namespaces[i * 2]) {
                xmlOutputBufferWrite(buf, SIZEPLUSLITERAL(":"));
                xmlOutputBufferWriteString(buf, (const char*) namespaces[i * 2]);
            }
            xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("=\""));
            xmlOutputBufferWriteString(buf, (const char*) namespaces[i * 2 + 1]);
            xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\""));
        }

        // output the attributes
        for (int i = 0; i < nb_attributes; ++i) {

            xmlOutputBufferWrite(buf, SIZEPLUSLITERAL(" "));
            if (attributes[i * 5 + 1]) {
                xmlOutputBufferWriteString(buf, (const char*) attributes[i * 5 + 1]);
                xmlOutputBufferWrite(buf, SIZEPLUSLITERAL(":"));
            }
            xmlOutputBufferWriteString(buf, (const char*) attributes[i * 5]);
            xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("=\""));

            xmlOutputBufferWrite(buf, attributes[i * 5 + 4] - attributes[i * 5 + 3] + 1,
                                 (const char*) attributes[i * 5 + 3]);

            xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\""));
        }
    }

    static void xmlOutputBufferWriteElementNs(std::string& s, const xmlChar* localname, const xmlChar* prefix,
                                              const xmlChar* URI, int nb_namespaces, const xmlChar** namespaces,
                                              int nb_attributes, int nb_defaulted, const xmlChar** attributes) {

        s.append(LITERALPLUSSIZE("<"));
        if (prefix != NULL) {
            s.append((const char*) prefix);
            s.append(LITERALPLUSSIZE(":"));
        }
        s.append((const char*) localname);

        // output the namespaces
        for (int i = 0; i < nb_namespaces; ++i) {

            s.append(LITERALPLUSSIZE(" xmlns"));
            if (namespaces[i * 2]) {
                s.append(LITERALPLUSSIZE(":"));
                s.append((const char*) namespaces[i * 2]);
            }
            s.append(LITERALPLUSSIZE("=\""));
            s.append((const char*) namespaces[i * 2 + 1]);
            s.append(LITERALPLUSSIZE("\""));
        }

        // output the attributes
        for (int i = 0; i < nb_attributes; ++i) {

            s.append(LITERALPLUSSIZE(" "));
            if (attributes[i * 5 + 1]) {
                s.append((const char*) attributes[i * 5 + 1]);
                s.append(LITERALPLUSSIZE(":"));
            }
            s.append((const char*) attributes[i * 5]);
            s.append(LITERALPLUSSIZE("=\""));

            s.append((const char*) attributes[i * 5 + 3], attributes[i * 5 + 4] - attributes[i * 5 + 3] + 1);

            s.append(LITERALPLUSSIZE("\""));
        }
    }

private :
    const char* ofilename;
    OPTION_TYPE & options;
    xmlXPathContextPtr context;
    xsltStylesheetPtr stylesheet;
    double total;
    bool result_bool;
    int nodetype;
    bool found;
    xmlOutputBufferPtr buf;
    bool needroot;
    bool closetag;
    int result_type;
    const char** params;
    int fd;
};

#endif
