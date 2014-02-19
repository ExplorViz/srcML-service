/*
  ProcessUnit.hpp

  Copyright (C) 2008-2010  SDML (www.srcML.org)

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

#ifndef INCLUDED_PROCESSUNIT_HPP
#define INCLUDED_PROCESSUNIT_HPP

#include <libxml/parser.h>

class ProcessUnit {
public :

    virtual ~ProcessUnit() {}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"

    virtual void startDocument(void* ctx) {}

    virtual void endDocument(void* ctx) {}

    virtual void startRootUnit(void* ctx, const xmlChar* localname, const xmlChar* prefix, const xmlChar* URI,
                               int nb_namespaces, const xmlChar** namespaces, int nb_attributes, int nb_defaulted,
                               const xmlChar** attributes) {}

    virtual void startUnit(void* ctx, const xmlChar* localname, const xmlChar* prefix, const xmlChar* URI,
                           int nb_namespaces, const xmlChar** namespaces, int nb_attributes, int nb_defaulted,
                           const xmlChar** attributes) {}

    virtual void startElementNs(void* ctx, const xmlChar* localname, const xmlChar* prefix, const xmlChar* URI,
                                int nb_namespaces, const xmlChar** namespaces, int nb_attributes, int nb_defaulted,
                                const xmlChar** attributes) {}

    virtual void endElementNs(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI) {}

    virtual void characters(void* ctx, const xmlChar* ch, int len) {}

    // comments
    virtual void comments(void* ctx, const xmlChar* ch) {}

    virtual void cdatablock(void* ctx, const xmlChar* ch, int len) {}

    virtual void endUnit(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI) {}

    virtual void endRootUnit(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI) {}

#pragma GCC diagnostic pop

    virtual OPTION_TYPE getOptions() const { return 0; }

};


#endif
