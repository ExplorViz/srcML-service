/**
 * @file xpath_query_units.hpp
 *
 * @copyright Copyright (C) 2008-2014 SDML (www.srcML.org)
 *
 * This file is part of the srcML Toolkit.
 *
 * The srcML Toolkit is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * The srcML Toolkit is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with the srcML Toolkit; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef INCLUDED_XPATH_QUERY_UNITS_HPP
#define INCLUDED_XPATH_QUERY_UNITS_HPP

#include <libxml/parser.h>
#include <libxml/xpath.h>

#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>

#include <libexslt/exslt.h>

/** size of string then the literal */
#define SIZEPLUSLITERAL(s) sizeof(s) - 1, s
/** literal followed by its size */
#define LITERALPLUSSIZE(s) s, sizeof(s) - 1

#include <srcexfun.hpp>
#include <unit_dom.hpp>
#include <srcmlns.hpp>

#if defined(__GNUG__) && !defined(__MINGW32__) && !defined(NO_DLLOAD)
#include <dlfcn.h>
#endif

#ifdef _MSC_BUILD
#include <io.h>
#define snprintf _snprintf
#endif

/**
 * xpath_query_units
 *
 * Extends unit_dom to execute XPath expression and write results.
 */
class xpath_query_units : public unit_dom {
public :

    /**
     * xpath_query_units
     * @param options list of srcML options
     * @param compiled_xpath Combined XPath expression
     * @param fd file descriptor in which to write
     *
     * Constructor.
     */
    xpath_query_units(OPTION_TYPE options, xmlXPathCompExprPtr compiled_xpath, int fd = 0)
        : unit_dom(options), options(options),
          compiled_xpath(compiled_xpath), total(0), found(false), needroot(true), closetag(false), fd(fd) {
    }

    /**
     * ~xpath_query_units
     *
     * Destructor.
     */
    virtual ~xpath_query_units() {}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"

    /**
     * form_simple_xpath
     * @param root_result_node the root node form xpath query result
     *
     * Form a simple xpath expression that marks the location of the result.
     * @returns the simple xpath to the result node as a string.
     */
    std::string form_simple_xpath(xmlNodePtr root_result_node) {

        std::string simple_xpath = form_full_name(root_result_node)
         + std::string("[") + child_offset(root_result_node) + std::string("]");
        xmlNodePtr parent_node = root_result_node->parent;

        while(parent_node) {

            if(parent_node->name)
                simple_xpath = form_full_name(parent_node)
                 + std::string("[") + child_offset(parent_node) + std::string("]")
                 + std::string("/") + simple_xpath;

            parent_node = parent_node->parent;

        }

        simple_xpath = "/" + simple_xpath;

        return simple_xpath;

    }

    /**
     * form_full_name
     * @param prefix the xml prefix
     * @param name the xml name;
     *
     * Form the full xpath name.
     * @returns the full name as a string.
     */
    std::string form_full_name(xmlNodePtr root_result_node) {

        std::string full_name = ""; 
        if(root_result_node->ns && root_result_node->ns->prefix) {

            full_name += (const char *)root_result_node->ns->prefix;

        } else {

            full_name += "src";

        }

        full_name += ":";
        full_name += (const char *)root_result_node->name;

        return full_name;

    }

    /**
     * child_offset
     * @param root_result_node the root node form xpath query result
     *
     * Find the child offset.
     * @returns the child offset number as a string.
     */
    std::string child_offset(xmlNodePtr root_result_node) {

        xmlNodePtr siblilng_node = root_result_node->prev;
        std::ostringstream child_offset_string("");

        int child_count = 1;
        if(siblilng_node) {

            std::string full_name = form_full_name(root_result_node);

            for(; sibling_node; sibling_node = sibling_node->prev) {

                if(full_name == form_full_name(sibling_node))
                    ++child_count;

            }

        }

        child_offset_string << child_count;

        return child_offset_string.str();

    }

    /**
     * start_output
     *
     * Create the output buffer and setup XPath.
     */
    virtual void start_output() {

        buf = xmlOutputBufferCreateFd(fd, NULL);

        // TODO:  Detect error

#ifdef _MSC_BUILD
        buf->writecallback = (xmlOutputWriteCallback)_write;
#endif

    }

#pragma GCC diagnostic push

    /**
     * apply
     *
     * Apply XPath expression, writing results.
     * 
     * @returns true on success false on failure.
     */
    virtual bool apply() {

        xmlXPathContextPtr context = xmlXPathNewContext(ctxt->myDoc);
        // TODO:  Detect error

        xpathsrcMLRegister(context);
        // TODO:  Detect error

        // register standard prefixes for standard namespaces
        const char* prefixes[] = {
            SRCML_SRC_NS_URI, "src",
            SRCML_CPP_NS_URI, SRCML_CPP_NS_PREFIX_DEFAULT,
            SRCML_ERR_NS_URI, SRCML_ERR_NS_PREFIX_DEFAULT,
            SRCML_EXT_LITERAL_NS_URI, SRCML_EXT_LITERAL_NS_PREFIX_DEFAULT,
            SRCML_EXT_OPERATOR_NS_URI, SRCML_EXT_OPERATOR_NS_PREFIX_DEFAULT,
            SRCML_EXT_MODIFIER_NS_URI, SRCML_EXT_MODIFIER_NS_PREFIX_DEFAULT,
            SRCML_EXT_POSITION_NS_URI, SRCML_EXT_POSITION_NS_PREFIX_DEFAULT,
            SRCML_DIFF_NS_URI, SRCML_DIFF_NS_PREFIX_DEFAULT,
            0, 0
        };

        for (unsigned int i = 0; prefixes[i] != 0; i += 2){
            if (xmlXPathRegisterNs(context, BAD_CAST prefixes[i + 1], BAD_CAST prefixes[i]) == -1) {
                fprintf(stderr, "%s: Unable to register prefix '%s' for namespace %s\n", "srcml2src", prefixes[i + 1], prefixes[i]);
                exit(1);
            }
        }

#if LIBEXSLT_VERSION > 813
#if defined(__GNUG__) && !defined(__MINGW32__) && !defined(NO_DLLOAD)
        typedef int (*exsltXpathCtxtRegister)(xmlXPathContextPtr, const xmlChar*);

        /** create a variable for dynamically load from library */
        typedef void * __attribute__ ((__may_alias__)) VOIDPTR;
        #define dlsymvar(type, name) type name;  *(VOIDPTR *)(&name) = dlsym(handle, #name)


        void* handle = dlopen("libexslt.so", RTLD_LAZY);
        if (!handle) {
            handle = dlopen("libexslt.so.0", RTLD_LAZY);
            if (!handle) {
                handle = dlopen("libexslt.dylib", RTLD_LAZY);
                if (!handle)
                    fprintf(stderr, "Unable to open libexslt library\n");
            }
        }

        if (handle) {

            dlerror();
            dlsymvar(exsltXpathCtxtRegister,exsltDateXpathCtxtRegister);
            if (dlerror() == NULL)  {
                // register exslt functions for XPath usage
                if (exsltDateXpathCtxtRegister(context, BAD_CAST "date") == -1) {
                    fprintf(stderr, "%s: Unable to register prefix for exslt '%s' function\n",
                            "srcml2src", "date");
                }
            }

            dlerror();
            dlsymvar(exsltXpathCtxtRegister,exsltMathXpathCtxtRegister);
            if (dlerror() == NULL)  {
                if (exsltMathXpathCtxtRegister(context, BAD_CAST "math") == -1) {
                    fprintf(stderr, "%s: Unable to register prefix for exslt '%s' function\n",
                            "srcml2src", "math");
                }

            }

            dlerror();
            dlsymvar(exsltXpathCtxtRegister,exsltSetsXpathCtxtRegister);
            if (dlerror() == NULL)  {

                if (exsltSetsXpathCtxtRegister(context, BAD_CAST "set") == -1) {
                    fprintf(stderr, "%s: Unable to register prefix for exslt '%s' function\n",
                            "srcml2src", "set");
                }

            }

            dlerror();
            dlsymvar(exsltXpathCtxtRegister,exsltStrXpathCtxtRegister);
            if (dlerror() == NULL)  {

                if (exsltStrXpathCtxtRegister(context, BAD_CAST "str") == -1) {
                    fprintf(stderr, "%s: Unable to register prefix for exslt '%s' function\n",
                            "srcml2src", "str");
                }

            }
        }

        #undef dlsymvar
#endif
#endif

        // evaluate the xpath
        xmlXPathObjectPtr result_nodes = xmlXPathCompiledEval(compiled_xpath, context);
        if (result_nodes == 0) {
            fprintf(stderr, "%s: Error in executing xpath\n", "srcml2src");
            return false;
        }

        // process the resulting nodes
        xmlNodePtr a_node = xmlDocGetRootElement(ctxt->myDoc);
        std::string wrap;
        bool outputunit = false;
        xmlNodePtr onode = 0;
        int result_size = 0;
        nodetype = result_nodes->type;

        switch (nodetype) {

            // node set result
        case XPATH_NODESET:

            if (needroot /*&& !isoption(options, SRCML_OPTION_APPLY_ROOT)*/) {

                // xml declaration
                if (isoption(options, SRCML_OPTION_XML_DECL))
                    xml_output_buffer_write_xml_decl(ctxt, buf);

                xml_output_buffer_write_processing_instruction(buf, processing_instruction);

                // output a root element, just like the one read in
                // note that this has to be ended somewhere
                xml_output_buffer_write_element_ns(buf, root->localname, root->prefix, root->URI,
                                                   root->nb_namespaces, root->namespaces,
                                                   is_archive ? root->nb_attributes : 0, root->nb_defaulted, is_archive ? root->attributes : 0);

                closetag = true;

                if(meta_tags->size()) {

                    xmlOutputBufferWrite(buf, SIZEPLUSLITERAL(">"));
                    for(std::vector<std::string>::size_type i = 0; i < meta_tags->size(); ++i) {
                        xml_output_buffer_write_element_ns(buf, meta_tags->at(i).localname, meta_tags->at(i).prefix, meta_tags->at(i).URI,
                                                           meta_tags->at(i).nb_namespaces, meta_tags->at(i).namespaces,
                                                           meta_tags->at(i).nb_attributes, meta_tags->at(i).nb_defaulted, meta_tags->at(i).attributes);

                        xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("/>"));

                    }


                }

            }
            needroot = false;

            // may not have any values or results
            result_size = xmlXPathNodeSetGetLength(result_nodes->nodesetval);
            if (isoption(options, SRCML_OPTION_APPLY_ROOT) && result_size == 0) {

                if(meta_tags->size())
                    xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("</unit>"));
                else
                    xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("/>"));

            }

            if (result_size == 0)
                break;

            // opened the root start element before, now need to close it.
            // why not do this when it is started?  May not have any results, and
            // need an empty element
            if (closetag) {
                if(meta_tags->size())
                    xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\n\n"));
                else
                    xmlOutputBufferWrite(buf, SIZEPLUSLITERAL(">\n\n"));

                closetag = false;
            }

            found = true;

            // output all the found nodes
            for (int i = 0; i < result_nodes->nodesetval->nodeNr; ++i) {

                // index into results
                onode = result_nodes->nodesetval->nodeTab[i];

                // output a unit element around the fragment, unless
                // is is already a unit
                outputunit = !onode->name || strcmp("unit", (const char*) onode->name) != 0;

                // if we need a unit, output the start tag.  Line number starts at 1, not 0
                if (outputunit) {

                    // form text for wrapping unit.  Cached in a string since we may need it for
                    // each result
                    if (wrap == "") {

                        // output a wrapping element, just like the one read in
                        // note that this has to be ended somewhere
                        xml_output_buffer_write_element_ns(wrap, root->localname, root->prefix, root->URI,
                                                           (int)((data.size() - rootsize) / 2), &data[rootsize],
                                                           0, 0, 0);

                        // output all the current attributes from the individual unit
                        for (xmlAttrPtr pAttr = a_node->properties; pAttr; pAttr = pAttr->next) {

                            wrap.append(LITERALPLUSSIZE(" "));
                            if (pAttr->ns && pAttr->ns->prefix) {
                                wrap.append((const char*) pAttr->ns->prefix);
                                wrap.append(LITERALPLUSSIZE(":"));
                            }
                            wrap.append((const char*) pAttr->name);
                            wrap.append(LITERALPLUSSIZE("=\""));

                            for (xmlNodePtr child = pAttr->children; child; child = child->next)
                                wrap.append((const char*) child->content);

                            wrap.append(LITERALPLUSSIZE("\""));
                        }

                        wrap.append(LITERALPLUSSIZE(" item=\""));

                    }

                    // output the start of the wrapping unit
                    xmlOutputBufferWrite(buf, (int)wrap.size(), wrap.c_str());

                    // append line number and close unit start tag
                    const int MAXSSIZE = 50;
                    static char itoabuf[MAXSSIZE];
                    snprintf(itoabuf, MAXSSIZE, "%d", i + 1);
                    xmlOutputBufferWriteString(buf, itoabuf);
                    xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\""));

                    xmlOutputBufferWrite(buf, SIZEPLUSLITERAL(" xpath=\""));
                    std::string simple_xpath = form_simple_xpath(onode);
                    xmlOutputBufferWriteString(buf, simple_xpath.c_str());
                    xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\">"));
                }

                /*
                  Three possibilities:

                  - Input was an archive, and XPath result is a unit
                  Resulting namespaces are those that were on the original unit

                  - Input was not an archive, and XPath result is a unit
                  Need to split the name

                  - XPath result was a node, but not a unit
                */

                // input was an archive, xpath result is a unit
                if (onode->type == XML_ELEMENT_NODE && is_archive && !outputunit) {

                    // create a new list of namespaces
                    // skip over the namespaces on the root
                    xmlNsPtr savens = onode->nsDef;
                    if(!isoption(options, SRCML_OPTION_APPLY_ROOT)) {
                        onode->nsDef = savens;
                        for (std::vector<const xmlChar*>::size_type i = 0; i < unit_dom::rootsize / 2; ++i)
                            onode->nsDef = onode->nsDef->next;
                    }
                    // dump the namespace-modified tree
                    xmlNodeDumpOutput(buf, ctxt->myDoc, onode, 0, 0, 0);

                    // restore original namespaces
                    onode->nsDef = savens;

                    // space between internal units
                    xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\n\n"));

                } else if (onode->type == XML_ELEMENT_NODE && !is_archive && !outputunit) {

                    // input was not an archive, xpath result is a unit

                    // namespace list only need the cpp namespace, if it exists
                    if(!isoption(options, SRCML_OPTION_APPLY_ROOT)) {
                        xmlNsPtr savens = onode->nsDef;
                        for (onode->nsDef = savens; onode->nsDef; onode->nsDef = onode->nsDef->next)
                            if (strcmp((const char*) onode->nsDef->href, SRCML_CPP_NS_URI) == 0)
                                break;

                        // if we found it, then
                        xmlNsPtr keepcppnext = 0;
                        if (onode->nsDef) {
                            keepcppnext = onode->nsDef->next;
                            onode->nsDef->next = 0;
                        }

                        // dump the namespace-modified tree
                        xmlNodeDumpOutput(buf, ctxt->myDoc, onode, 0, 0, 0);

                        // restore original namespaces
                        if (onode->nsDef)
                            onode->nsDef->next = keepcppnext;
                        onode->nsDef = savens;

                        // space between internal units
                        xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\n\n"));

                    } else {

                        // dump the namespace-modified tree
                        xmlNodeDumpOutput(buf, ctxt->myDoc, onode, 0, 0, 0);

                        // space between internal units
                        xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\n\n"));

                    }


                } else if (onode->type == XML_ATTRIBUTE_NODE) {

                    // xpath of attribute is value of attribute

                    // dump the namespace-modified tree
                    xmlNodeDumpOutput(buf, ctxt->myDoc, onode->children, 0, 0, 0);

                    // wrapped in a unit, so output the end tag
                    xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("</unit>\n\n"));

                } else {

                    // xpath of nodeset, that is not a unit

                    // dump the namespace-modified tree
                    xmlNodeDumpOutput(buf, ctxt->myDoc, onode, 0, 0, 0);

                    // wrapped in a unit, so output the end tag
                    xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("</unit>\n\n"));
                }
            }

            break;

            // numeric result
        case XPATH_NUMBER:
            if (!isoption(options, SRCML_OPTION_XPATH_TOTAL)) {
                std::ostringstream out;
                if ((int)result_nodes->floatval == result_nodes->floatval)
                    out << (int)result_nodes->floatval;
                else
                    out << result_nodes->floatval;

                xmlOutputBufferWriteString(buf, out.str().c_str());
                xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\n"));
            }
            total += result_nodes->floatval;
            break;

            // boolean result
        case XPATH_BOOLEAN:
            if (!isoption(options, SRCML_OPTION_XPATH_TOTAL))
                xmlOutputBufferWriteString(buf, result_nodes->boolval ? "true\n" : "false\n");

            result_bool |= (result_nodes->boolval != 0);
            break;

            // string
        case XPATH_STRING:
            {
                char* p = (char*) result_nodes->stringval;
                char* pos = p;
                while (*p) {

                    if (p[0] == '&') {
                        if (p[1] == 'l' && p[2] == 't' && p[3] == ';') {

                            xmlOutputBufferWrite(buf, (int)(p - pos), pos);
                            xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("<"));
                            p += 4;
                            pos = p;

                        } else if (p[1] == 'g' && p[2] == 't' && p[3] == ';') {

                            xmlOutputBufferWrite(buf, (int)(p - pos), pos);
                            xmlOutputBufferWrite(buf, SIZEPLUSLITERAL(">"));
                            p += 4;
                            pos = p;

                        } else if (p[1] == '#' && isdigit(p[2]) && isdigit(p[3])) {

                            xmlOutputBufferWrite(buf, (int)(p - pos), pos);

                            int end = 4;
                            if(p[4] == ';')
                                end = 5;
                            else if (isdigit(p[4]) && p[5] == ';')
                                end = 6;

                            if(end > 4) {
                                p[end - 1] = '\0';

                                int c = atoi(p + 2);
                                xmlOutputBufferWrite(buf, 1, (const char*) &c);

                                p[end - 1] = ';';
                            } else
                                xmlOutputBufferWrite(buf, 4, (const char*) p);

                            p += end;
                            pos = p;
                        }
                    } else {

                        ++p;
                    }
                }
                xmlOutputBufferWrite(buf, (int)(p - pos), pos);
            }

            xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\n"));

            break;

        default:
            fprintf(stderr, "Unhandled type %d\n", nodetype);
            break;
        };

        // finished with the result nodes
        xmlXPathFreeObject(result_nodes);
        if(context) xmlXPathFreeContext(context);

#if LIBEXSLT_VERSION > 813
#if defined(__GNUG__) && !defined(__MINGW32__) && !defined(NO_DLLOAD)
        dlclose(handle);
#endif
#endif
        return true;
    }

    /**
     * end_output
     *
     * Finish the archive and close buffer.
     */
    virtual void end_output() {

        // finalize results
        switch (nodetype) {
        case XPATH_NODESET:

            {

                std::string full_unit = "</";
                if(root->prefix) {
                    full_unit += (const char *)root->prefix;
                    full_unit += ":";
                }
                full_unit += "unit>\n";

                // root unit end tag
                if (!isoption(options, SRCML_OPTION_APPLY_ROOT))
                    xmlOutputBufferWriteString(buf, found || meta_tags->size() ? full_unit.c_str() : "/>\n");
                else if(found)
                    xmlOutputBufferWriteString(buf, full_unit.c_str());
                else
                    xmlOutputBufferWriteString(buf, "\n");

                break;

            }

        case XPATH_NUMBER:
            if (isoption(options, SRCML_OPTION_XPATH_TOTAL)) {
                std::ostringstream out;
                if ((int)total == total)
                    out << (int)total;
                else
                    out << total;

                xmlOutputBufferWriteString(buf, out.str().c_str());
                xmlOutputBufferWriteString(buf, "\n");
            }
            break;

            // boolean result
        case XPATH_BOOLEAN:
            if (isoption(options, SRCML_OPTION_XPATH_TOTAL))
                xmlOutputBufferWriteString(buf, result_bool ? "true\n" : "false\n");
            break;

        default:
            break;
        }

        // all done with the buffer
        xmlOutputBufferClose(buf);
    }

    /**
     * xml_output_buffer_write_xml_decl
     * @param ctxt an xml parser context
     * @param buf output buffer to write element
     *
     * Write the xml declaration to output buffer.
     */
    static void xml_output_buffer_write_xml_decl(xmlParserCtxtPtr ctxt, xmlOutputBufferPtr buf) {

        xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("<?xml version=\""));
        xmlOutputBufferWriteString(buf, (const char*) ctxt->version);
        xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\" encoding=\""));
        xmlOutputBufferWriteString(buf, (const char*) (ctxt->encoding ? ctxt->encoding : ctxt->input->encoding));
        xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\" standalone=\""));
        xmlOutputBufferWriteString(buf, ctxt->standalone ? "yes" : "no");
        xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\"?>\n"));
        
    }

    /**
     * xml_output_buffer_write_processing_instruction
     * @param buf output buffer to write element
     * @param processing_instruction the pre-root processing instruction to write
     *
     * Write the xml pre-root processing instruction to the output buffer.
     */
    static void xml_output_buffer_write_processing_instruction(xmlOutputBufferPtr buf, boost::optional<std::pair<std::string, std::string> > processing_instruction) {

        if(processing_instruction) {

            xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("<?"));
            xmlOutputBufferWriteString(buf, processing_instruction->first.c_str());
            xmlOutputBufferWrite(buf, SIZEPLUSLITERAL(" "));
            xmlOutputBufferWriteString(buf, processing_instruction->second.c_str());
            xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("?>\n"));

        }

    }

    /**
     * xml_output_buffer_write_element_ns
     * @param buf output buffer to write element
     * @param localname the name of the element tag
     * @param prefix the tag prefix
     * @param URI the namespace of tag
     * @param nb_namespaces number of namespaces definitions
     * @param namespaces the defined namespaces
     * @param nb_attributes the number of attributes on the tag
     * @param nb_defaulted the number of defaulted attributes
     * @param attributes list of attribute name value pairs (localname/prefix/URI/value/end)
     *
     * Write an element to output buffer.
     */
    void xml_output_buffer_write_element_ns(xmlOutputBufferPtr buf, const xmlChar* localname, const xmlChar* prefix,
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

            // don't put cpp namespace on the root for a non-archive
            if (!is_archive && strcmp((const char*) namespaces[2 * i + 1], SRCML_CPP_NS_URI) == 0)
                continue;

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

            xmlOutputBufferWrite(buf, (int)(attributes[i * 5 + 4] - attributes[i * 5 + 3]),
                                 (const char*) attributes[i * 5 + 3]);

            xmlOutputBufferWrite(buf, SIZEPLUSLITERAL("\""));
        }
    }

    /**
     * xml_output_buffer_write_element_ns
     * @param s string to write output
     * @param localname the name of the element tag
     * @param prefix the tag prefix
     * @param URI the namespace of tag
     * @param nb_namespaces number of namespaces definitions
     * @param namespaces the defined namespaces
     * @param nb_attributes the number of attributes on the tag
     * @param nb_defaulted the number of defaulted attributes
     * @param attributes list of attribute name value pairs (localname/prefix/URI/value/end)
     *
     * Write an element to a string.
     */
    void xml_output_buffer_write_element_ns(std::string& s, const xmlChar* localname, const xmlChar* prefix,
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

            // only put cpp namespace on the non-root unit for a non-archive
            if (!is_archive && strcmp((const char*) namespaces[2 * i + 1], SRCML_CPP_NS_URI) != 0)
                continue;

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

            s.append((const char*) attributes[i * 5 + 3], attributes[i * 5 + 4] - attributes[i * 5 + 3]);

            s.append(LITERALPLUSSIZE("\""));
        }
    }

private :

    OPTION_TYPE options;
    xmlXPathCompExprPtr compiled_xpath;
    double total;
    bool result_bool;
    int nodetype;
    bool found;
    xmlOutputBufferPtr buf;
    bool needroot;
    bool closetag;
    int fd;

};

#endif
