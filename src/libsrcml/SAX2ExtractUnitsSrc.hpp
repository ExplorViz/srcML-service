/*
  SAX2ExtractUnitsSrc.hpp

  Copyright (C) 2008-2012  SDML (www.srcML.org)

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

  Class for straightforward translation
*/

#ifndef INCLUDED_SAX2EXTRACTUNITSSRC
#define INCLUDED_SAX2EXTRACTUNITSSRC

#include <libxml/parser.h>
#include "srcMLUtility.hpp"
#include "ProcessUnit.hpp"
#include <vector>

struct Element {

  Element() : localname(0), prefix(0), URI(0),
              nb_namespaces(0), namespaces(0), nb_attributes(0),
              nb_defaulted(0), attributes(0)
  {}

    const xmlChar* localname;
    const xmlChar* prefix;
    const xmlChar* URI;
    int nb_namespaces;
    const xmlChar** namespaces;
    int nb_attributes;
    int nb_defaulted;
    const xmlChar** attributes;
};

extern const char* diff_version;

class SAX2ExtractUnitsSrc {

public:

    ProcessUnit* pprocess;
    OPTION_TYPE* poptions;
    int unit;
    long count;
    Element root;
    std::string firstcharacters;
    bool isarchive;
    bool rootonly;
    bool stop;
    enum DIFF { DIFF_COMMON, DIFF_OLD, DIFF_NEW };
    std::vector<DIFF> st;
    int status;

public:

    SAX2ExtractUnitsSrc(ProcessUnit* pprocess, OPTION_TYPE* poptions, int unit, const char* diff_version)
        : pprocess(pprocess), poptions(poptions), unit(unit), count(0), isarchive(false), rootonly(false), stop(false)
        {
            if (isoption(*poptions, OPTION_DIFF))
                status = strcmp(diff_version, "1") == 0 ? DIFF_OLD : DIFF_NEW;
            st.push_back(DIFF_COMMON);
        }

    static xmlSAXHandler factory();

    static void startDocument(void *ctx);

    static void endDocument(void *ctx);

    // output all characters to output buffer
    static void charactersPre(void* user_data, const xmlChar* ch, int len);

    // handle root unit of compound document
    static void startElementNsRoot(void* ctx, const xmlChar* localname, const xmlChar* prefix, const xmlChar* URI,
                                   int nb_namespaces, const xmlChar** namespaces, int nb_attributes, int nb_defaulted,
                                   const xmlChar** attributes);

    // unit element
    static void startElementNsFirst(void* ctx, const xmlChar* localname, const xmlChar* prefix, const xmlChar* URI,
                                    int nb_namespaces, const xmlChar** namespaces, int nb_attributes, int nb_defaulted,
                                    const xmlChar** attributes);

    // unit element
    static void startElementNs(void* ctx, const xmlChar* localname, const xmlChar* prefix, const xmlChar* URI,
                               int nb_namespaces, const xmlChar** namespaces, int nb_attributes, int nb_defaulted,
                               const xmlChar** attributes);

    static void endElementNs(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI);

    static void endElementNsSkip(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI);

    /*
      Call process methods
    */
    static void startElementNsUnit(void* ctx, const xmlChar* localname, const xmlChar* prefix, const xmlChar* URI,
                                   int nb_namespaces, const xmlChar** namespaces, int nb_attributes, int nb_defaulted,
                                   const xmlChar** attributes);

    // output all characters to output buffer
    static void charactersUnit(void* user_data, const xmlChar* ch, int len);
    static void cdatablockUnit(void* user_data, const xmlChar* ch, int len);
    static void commentUnit(void* user_data, const xmlChar* ch);

    static void endElementNsUnit(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI);

    // stop all processing
    static void stopUnit(void* ctx);

};

#endif
