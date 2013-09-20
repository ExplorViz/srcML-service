/*
  ExtractUnitsSrc.cpp

  Copyright (C) 2008-2013  SDML (www.srcML.org)

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

#ifndef INCLUDED_EXTRACTUNITSSRC_HPP
#define INCLUDED_EXTRACTUNITSSRC_HPP

#include "SAX2ExtractUnitsSrc.hpp"
#include "ProcessUnit.hpp"
#include "srcmlapps.hpp"
#include "srcmlns.hpp"

#if defined(__GNUC__)
#define EOL "\n"
#define EOL_SIZE 1
#else
#define EOL "\r\n"
#define EOL_SIZE 2
#endif

class ExtractUnitsSrc : public ProcessUnit {
public :
  ExtractUnitsSrc(const char* to_dir, const char* output_filename, const char* output_encoding)
    : to_directory(to_dir), output_filename(output_filename), buffer(0) {
    
    output_buffer[0] = 0;
    handler = xmlFindCharEncodingHandler(output_encoding);
  }

  ExtractUnitsSrc(xmlBufferPtr buffer, const char* output_encoding)
    : to_directory(0), output_filename(0), buffer(buffer) {

    output_buffer[0] = 0;
    handler = xmlFindCharEncodingHandler(output_encoding);
  }

  ExtractUnitsSrc(xmlOutputBufferPtr obuffer)
    : to_directory(0), output_filename(0), buffer(0)  {

    output_buffer[0] = obuffer;
  }

private :
  const char* to_directory;
  const char* output_filename;
  xmlBufferPtr buffer;
  xmlCharEncodingHandlerPtr handler;

public :

  virtual void startUnit(void* ctx, const xmlChar* localname, const xmlChar* prefix, const xmlChar* URI,
                         int nb_namespaces, const xmlChar** namespaces, int nb_attributes, int nb_defaulted,
                         const xmlChar** attributes) {

    xmlParserCtxtPtr ctxt = (xmlParserCtxtPtr) ctx;
    SAX2ExtractUnitsSrc* pstate = (SAX2ExtractUnitsSrc*) ctxt->_private;

    if (to_directory && !isoption(*(pstate->poptions), OPTION_NULL)) {

      /*
        The filename to extract to is based on:

        - path given in the extract on the command line
        - directory attribute of the root unit.  This can be superseded by the directory attribute
        of the individual unit
        - filename on the unit (which is really a path)
      */

      // start the path with the (optional) target directory
      path = to_directory;

      // append the directory attribute from the root
      int dir_index = -1;
      if (pstate->isarchive) {

        dir_index = find_attribute_index(pstate->root.nb_attributes, pstate->root.attributes, UNIT_ATTRIBUTE_DIRECTORY);
        if (dir_index != -1) {

          if (!path.empty() && path[path.size() - 1] != PATH_SEPARATOR)
            path += PATH_SEPARATOR;

          path.append((const char*) pstate->root.attributes[dir_index + 3], (const char*) pstate->root.attributes[dir_index + 4]);
        }
      }

      // append the directory attribute from the individual unit
      dir_index = find_attribute_index(nb_attributes, attributes, UNIT_ATTRIBUTE_DIRECTORY);
      if (dir_index != -1) {

        if (!path.empty() && path[path.size() - 1] != PATH_SEPARATOR)
          path += PATH_SEPARATOR;

        path.append((const char*) attributes[dir_index + 3], (const char*) attributes[dir_index + 4]);

      }

      // find the filename attribute
      int filename_index = find_attribute_index(nb_attributes, attributes, UNIT_ATTRIBUTE_FILENAME);
      bool foundfilename = filename_index != -1;

      // filename is required
      if (!foundfilename && !isoption(*(pstate->poptions), OPTION_NULL)) {
        fprintf(stderr, "Skipping unit %ld:  Missing filename attribute\n", pstate->count);
        return;
      }

      // append the filename
      if (!path.empty() && path[path.size() - 1] != PATH_SEPARATOR)
        path += PATH_SEPARATOR;
      path.append((const char*) attributes[filename_index + 3], (const char*) attributes[filename_index + 4]);

      // output file status message if in verbose mode
      if (!isoption(*(pstate->poptions), OPTION_QUIET))
        fprintf(stderr, "%ld\t%s\n", pstate->count, path.c_str());

    } else if (output_filename) {

      path = output_filename;

    } else {

      path = "-";
    }

    // now create the file itself
    if(!output_buffer[0]) {

      if (isoption(*(pstate->poptions), OPTION_NULL)) {
        output_buffer[0] = xmlOutputBufferCreateFd(1, handler);
      } else if(buffer) {
        output_buffer[0] = xmlOutputBufferCreateBuffer(buffer, handler);

      } else
        output_buffer[0] = xmlOutputBufferCreateFilename(path.c_str(), handler, isoption(*(pstate->poptions), OPTION_COMPRESSED));

    }

    if (output_buffer[0] == NULL) {
      fprintf(stderr, "Output buffer error\n");
      xmlStopParser(ctxt);
    }
  }

  virtual void characters(void* ctx, const xmlChar* ch, int len) {

#if defined(__GNUC__)
    xmlOutputBufferWrite(output_buffer[0], len, (const char*) ch);
#else
    const char* c = (const char*) ch;
    int pos = 0;
    const char* chend = (const char*) ch + len;
    while (c < chend) {

      switch (*c) {
      case '\n' :
        xmlOutputBufferWrite(output_buffer[0], pos, (const char*)(BAD_CAST c - pos));
        pos = 0;
        xmlOutputBufferWrite(output_buffer[0], EOL_SIZE, EOL);
        break;

      default :
        ++pos;
        break;
      };
      ++c;
    }

    xmlOutputBufferWrite(output_buffer[0], pos, (const char*)(BAD_CAST c - pos));
#endif
  }

  virtual void endUnit(void *ctx, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI) {

    xmlParserCtxtPtr ctxt = (xmlParserCtxtPtr) ctx;
    SAX2ExtractUnitsSrc* pstate = (SAX2ExtractUnitsSrc*) ctxt->_private;

    if (isoption(*(pstate->poptions), OPTION_NULL)) {
      xmlOutputBufferWrite(output_buffer[0], 1, "\0");
    }


    // finish up this file
    xmlOutputBufferClose(output_buffer[0]);
    output_buffer[0] = 0;

    // stop after this file (and end gracefully) with ctrl-c
    if (isoption(*(pstate->poptions), OPTION_TERMINATE)) {
      xmlStopParser(ctxt);
      throw TerminateLibXMLError();
    }
  }

  // escape control character elements
  void startElementNs(void* ctx, const xmlChar* localname,
                      const xmlChar* prefix, const xmlChar* URI,
                      int nb_namespaces, const xmlChar** namespaces,
                      int nb_attributes, int nb_defaulted,
                      const xmlChar** attributes) {

    // only reason for this handler is that the escape element
    // needs to be expanded to the equivalent character.
    // So make it as quick as possible, since this is rare
    if (localname[0] == 'e' && localname[1] == 's' &&
        strcmp((const char*) localname, "escape") == 0 &&
        strcmp((const char*) URI, SRCML_SRC_NS_URI) == 0) {

      // convert from the escaped to the unescaped value
      char value = strtod((const char*) attributes[3], NULL);

      characters(ctx, BAD_CAST &value, 1);
    }
  }

private :
  std::string path;
  xmlOutputBufferPtr output_buffer[2];
};

#endif
