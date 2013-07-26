/*
  srcMLUtility.hpp

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

  Class for extracting basic information from srcML documents, including equivalent source code.
*/

#ifndef SRCMLUTILITY_HPP
#define SRCMLUTILITY_HPP

#include "Language.hpp"
#include "Options.hpp"

#include "SAX2Utilities.hpp"

class LibXMLError;
class TerminateLibXMLError;
class OutOfRangeUnitError;

class XMLProcess {
 public:
  virtual void process() = 0;
};

class XSLTProcess : public XMLProcess {

};

class srcMLUtility {
 public:

  // constructor
  srcMLUtility(const char* infilename, const char* encoding, OPTION_TYPE& op, const char* diff_version = "");
  srcMLUtility(const char * buffer, int size, const char* encoding, OPTION_TYPE& op, const char* diff_version = "");

  // set the input filename after the constructor
  void set_input_filename(const char* infilename);

  // attribute
  const char* attribute(const char* attribute_name);

  // namespace
  const char* namespace_ext(const char* uri);

  // move to a particular nested unit
  //  void move_to_unit(int unitnumber);
  void move_to_unit(int unitnumber, srcMLUtility&su, OPTION_TYPE options, int optioncount, int optionorder[], FILE * output);
  const char * long_info(srcMLUtility & su);

  // namespaces and prefixes
  const PROPERTIES_TYPE* getNS() const;

  // count of nested units
  int unit_count(FILE* output);

  // list the elements
  void list();

  // extract (intact) current unit as XML
  void extract_xml(const char* ofilename, int unit = 0);
  const char * extract_xml(int unit);

  // extract (intact) current unit as text
  void extract_text(const char* to_dir, const char* ofilename, int unit = 0);
  const char * extract_text(int unit = 0);

  // extract a particular srcML version from srcDiff format
  void extract_diff_xml(const char* ofilename, int unit, const char* version);

  // extract (intact) current unit as XML only preserving the URI
  void extract_xml_uri(const char* ofilename, int unit, const char* uri);

  // extract a particular version from srcDiff format
  void extract_diff_text(const char* to_dir, const char* ofilename, int unit, const char* version);

  // expand the compound srcML to individual files
  void expand(const char* root_filename = "", const char* output_format = 0,
	      const char* to_directory = "");

  // perform xpath evaluation
  void xpath(const char* context_element, const char* ofilename, const char* xpaths[]);

  // perform xslt evaluation
  void xslt(const char* context_element, const char* ofilename, const char* xslts[], const char* params[], int paramcount);

  // perform relaxng evaluation
  void relaxng(const char* ofilename, const char** xslts);

  static bool checkEncoding(const char* encoding) {

    return xmlFindCharEncodingHandler(encoding) != 0;
  }

  int curunits() const;

  // destructor
  ~srcMLUtility();

 private:
  const char* infile;
  const char* output_encoding;
  OPTION_TYPE options;
  int units;
  const char* diff_version;
  const char * buffer;
  int size;
 public:
  PROPERTIES_TYPE nsv;
  PROPERTIES_TYPE attrv;
};

class LibXMLError {
 public:
  LibXMLError(int errnum)
    : error(errnum) {}

  int getErrorNum() const { return error; }

 private:
  int error;
};

class TerminateLibXMLError : public LibXMLError {
 public:
  TerminateLibXMLError() : LibXMLError(0) {}
};

class OutOfRangeUnitError : public LibXMLError {
 public:
  OutOfRangeUnitError(int s) : LibXMLError(0), size(s) {}

  int size;
};

extern "C" {

  // constructor
  srcMLUtility * srcml_utility_file_new(const char* infilename, const char* encoding, OPTION_TYPE op, const char* diff_version = "");
  srcMLUtility * srcml_utility_memory_new(const char * buffer, int size, const char* encoding, OPTION_TYPE op, const char* diff_version = "");

  // extract (intact) current unit as text
  void srcml_extract_text_file(srcMLUtility * su, const char* to_dir, const char* ofilename, int unit);
  const char * srcml_extract_text_buffer(srcMLUtility * su, int unit);

  // count of nested units
  int srcml_unit_count(srcMLUtility * su, FILE* output);

  // extract (intact) current unit as XML
  //void srcml_extract_xml_file(const char* ofilename, int unit);
  const char * srcml_extract_xml_buffer(srcMLUtility * su, int unit);

  const char * srcml_long_info(srcMLUtility * su);

  void srcml_utility_delete(srcMLUtility * su);

}

#endif
