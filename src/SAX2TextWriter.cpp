/*
  SAX2TextWriter.cpp

  Copyright (C) 2008-2010 SDML (www.srcML.org)

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

  A SAX2 handler for libxml2 that converts input to TextWriter.  It performs
  a (attempted) identical copy of the input.  Typically used for part of
  an xml document, e.g., an individual subpart.  It can also be customized
  by overriding individual callbacks.
*/

#include <cstring>
#include <libxml/xmlwriter.h>
#include <libxml/parser.h>
#include <libxml/parserInternals.h>
#include <iostream>

#include "SAX2TextWriter.hpp"
#include "SAX2Utilities.hpp"
#include "Options.hpp"

SAX2TextWriter::SAX2TextWriter(const char* ofilename, OPTION_TYPE& options, int unit):
    unit(unit), options(options), filename(ofilename) {

}

xmlSAXHandler SAX2TextWriter::factory() {

    xmlSAXHandler sax = { 0 };

    sax.initialized    = XML_SAX2_MAGIC;
    sax.startDocument  = &SAX2TextWriter::startDocument;
    sax.endDocument    = &SAX2TextWriter::endDocument;
    sax.startElementNs = &SAX2TextWriter::startElementNs;
    sax.endElementNs   = &SAX2TextWriter::endElementNs;
    sax.characters     = &SAX2TextWriter::characters;
    sax.comment        = &SAX2TextWriter::comments;

    return sax;
}

// start document
void SAX2TextWriter::startDocument(void *ctx) {

    SAX2TextWriter* pstate = (SAX2TextWriter*) ctx;

    // open the output text writer stream
    // "-" filename is standard output
    pstate->writer = xmlNewTextWriterFilename(pstate->filename,
                                              isoption(pstate->options, OPTION_COMPRESSED) ? 1 : 0);

    // start this document the same as the current document
    if (!isoption(pstate->options, OPTION_XMLDECL))
        xmlTextWriterStartDocument(pstate->writer,
                                   (const char*) pstate->ctxt->version,
                                   (const char*) (pstate->ctxt->encoding ? pstate->ctxt->encoding : pstate->ctxt->input->encoding),
                                   pstate->ctxt->standalone ? "yes" : "no");
}

// end document
void SAX2TextWriter::endDocument(void *ctx) {

    SAX2TextWriter* pstate = (SAX2TextWriter*) ctx;

    xmlTextWriterEndDocument(pstate->writer);

    xmlFreeTextWriter(pstate->writer);
}

// characters
void SAX2TextWriter::characters(void* ctx, const xmlChar* ch, int len) {

    SAX2TextWriter* pstate = (SAX2TextWriter*) ctx;

    const char* c = (const char*) ch;
    int pos = 0;
    const char* chend = (const char*) ch + len;
    while (c < chend) {

        switch (*c) {
        case '<' :
            xmlTextWriterWriteRawLen(pstate->writer, BAD_CAST c - pos, pos);
            pos = 0;
            xmlTextWriterWriteRawLen(pstate->writer, BAD_CAST "&lt;", 4);
            break;

        case '>' :
            xmlTextWriterWriteRawLen(pstate->writer, BAD_CAST c - pos, pos);
            pos = 0;
            xmlTextWriterWriteRawLen(pstate->writer, BAD_CAST "&gt;", 4);
            break;

        case '&' :
            xmlTextWriterWriteRawLen(pstate->writer, BAD_CAST c - pos, pos);
            pos = 0;
            xmlTextWriterWriteRawLen(pstate->writer, BAD_CAST "&amp;", 5);
            break;

        default :
            ++pos;
            break;
        };
        ++c;
    }

    xmlTextWriterWriteRawLen(pstate->writer, BAD_CAST c - pos, pos);
}

// comments
void SAX2TextWriter::comments(void* ctx, const xmlChar* ch) {

    SAX2TextWriter* pstate = (SAX2TextWriter*) ctx;

    xmlTextWriterWriteComment(pstate->writer, ch);
}

// start a new output buffer and corresponding file for a
// unit element
void SAX2TextWriter::startElementNs(void* ctx, const xmlChar* localname, const xmlChar* prefix, const xmlChar* URI,
                                    int nb_namespaces, const xmlChar** namespaces, int nb_attributes, int nb_defaulted,
                                    const xmlChar** attributes) {

    SAX2TextWriter* pstate = (SAX2TextWriter*) ctx;

    // start element with proper prefix
    const char* name = qname((const char*) prefix, (const char*) localname);
    xmlTextWriterStartElement(pstate->writer, BAD_CAST name);

    // copy namespaces
    if (!isoption(pstate->options, OPTION_NAMESPACE))
        for (int i = 0, index = 0; i < nb_namespaces; ++i, index += 2) {

            const char* name = xmlnsprefix((const char*) namespaces[index]);

            xmlTextWriterWriteAttribute(pstate->writer, BAD_CAST name, namespaces[index + 1]);
        }

    // copy attributes
    for (int i = 0, index = 0; i < nb_attributes; ++i, index += 5) {

        const char* name = qname((const char*) attributes[index + 1], (const char*) attributes[index]);

        // write the attribute raw so we don't have to convert
        // the begin/end pointers of the attribute value to a string
        xmlTextWriterStartAttribute(pstate->writer, BAD_CAST name);
        xmlTextWriterWriteRawLen(pstate->writer, attributes[index + 3],
                                 attributes[index + 4] - attributes[index + 3]);
        xmlTextWriterEndAttribute(pstate->writer);
    }
}

// end unit element and current file/buffer (started by startElementNs
void SAX2TextWriter::endElementNs(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI) {

    SAX2TextWriter* pstate = (SAX2TextWriter*) ctx;

    xmlTextWriterEndElement(pstate->writer);

    if (pstate->unit > 0 && pstate->ctxt->nameNr == 2) {

        pstate->ctxt->sax->startDocument  = 0;
        pstate->ctxt->sax->endDocument    = &SAX2TextWriter::endDocument;
        pstate->ctxt->sax->startElementNs = 0;
        pstate->ctxt->sax->endElementNs   = 0;
        pstate->ctxt->sax->characters     = 0;

        xmlStopParser(pstate->ctxt);
    }
}
