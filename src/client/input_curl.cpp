/**
 * @file input_curl.hpp
 *
 * @copyright Copyright (C) 2014 srcML, LLC. (www.srcML.org)
 *
 * This file is part of the srcml command-line client.
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
 * along with the srcml command-line client; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <input_curl.hpp>
#include <decompress_srcml.hpp>
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshorten-64-to-32"
#include <boost/thread.hpp>
#pragma GCC diagnostic pop

#include <curl/curl.h>

#if defined(_MSC_BUILD) || defined(__MINGW32__)
#include <io.h>
#include <fcntl.h>
#include <windows.h>
#endif

// global request
extern srcml_request_t global_srcml_request;

struct curl_write_info {
    int outfd;
    size_t currentsize;
    std::string buffer;
};

static const int CURL_MAX_ERROR_SIZE = 100;

int curl_error = 0;

/*
    Write callback for curl. libcurl internals use fwrite() as default, so replacing it
    with our own callback does not entail an additional copy
*/
size_t our_curl_write_callback(char *ptr, size_t size, size_t nmemb, void *userdata) {

    curl_write_info* data = (curl_write_info*) userdata;

    // we may have previously buffered data to output
    if (data->buffer.size() >= CURL_MAX_ERROR_SIZE) {
        write(data->outfd, data->buffer.c_str(), data->buffer.size());
        data->buffer.clear();
    }

    size_t total_size = size * nmemb;
    data->currentsize += total_size;

    // cache any data until we make sure we do not have a 404 error
    // prevent the 404 or other error pages from getting into the pipe
    // previously handled by latch in libarchive
    if (data->currentsize < CURL_MAX_ERROR_SIZE) {
        data->buffer.append(ptr, size * nmemb);
        return total_size;
    }

	return write(data->outfd, ptr, total_size);
}

// downloads URL into file descriptor
void curl_download_url(const srcml_request_t& srcml_request,
    const srcml_input_t& input_sources,
    const srcml_output_dest& destination) {

    curl_error = 0;

    // input comes from URL
    std::string url = input_sources[0].filename;

    curl_write_info write_info;
    write_info.outfd = *destination.fd; // output is a file descriptor
    write_info.currentsize = 0;

    CURL *curl_handle;

    curl_global_init(CURL_GLOBAL_DEFAULT);
    curl_handle = curl_easy_init();

    curl_easy_setopt(curl_handle, CURLOPT_SSL_VERIFYPEER, 0L);
    curl_easy_setopt(curl_handle, CURLOPT_SSL_VERIFYHOST, 0L);
    curl_easy_setopt(curl_handle, CURLOPT_HTTPAUTH, (long)CURLAUTH_ANY);
    curl_easy_setopt(curl_handle, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl_handle, CURLOPT_VERBOSE, 0L);

    // setup to use a write function
    curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, &write_info);
    curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, our_curl_write_callback);

    curl_easy_setopt(curl_handle, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl_handle, CURLOPT_USERAGENT, "libcurl-agent/1.0");

    curl_easy_setopt(curl_handle, CURLOPT_LOW_SPEED_LIMIT, 1L);
    curl_easy_setopt(curl_handle, CURLOPT_LOW_SPEED_TIME, 5L);
    //curl_easy_setopt(curl_handle, CURLOPT_NOPROGRESS, 0L);

    // start the download
    CURLcode response;
    response = curl_easy_perform(curl_handle);

    // check for download errors
    long http_code = 0;
    curl_easy_getinfo (curl_handle, CURLINFO_RESPONSE_CODE, &http_code);
    if(response != CURLE_OK || http_code != 200) {

        std::cerr << "srcml: Unable to access URL " << url << std::endl;
        curl_error = 1;

        // if there is only a single input source, and we have an error, then just error out here
       //if (global_srcml_request.input_sources.size() == 1)
//            exit(1);

    } else {

        // ok, no errors, but may have cached data in the buffer, especially for small files
        if (!write_info.buffer.empty()) {
            write(write_info.outfd, write_info.buffer.c_str(), write_info.buffer.size());
        }
    }

    // close the output file descriptor we were writing the download to
    close(write_info.outfd);

    // cleanup out download
    curl_easy_cleanup(curl_handle);

    // all done with libcurl
    curl_global_cleanup();
}

void input_curl(srcml_input_src& input) {

    	// setup the pipes
	    int fds[2] = { -1, -1 };
#if !defined(_MSC_BUILD) && !defined(__MINGW32__)
        pipe(fds);
#else
        HANDLE read_pipe;
        HANDLE write_pipe;
        CreatePipe(&read_pipe,&write_pipe, NULL, 0);

        fds[1] = _open_osfhandle((intptr_t)write_pipe, 0);
        fds[0] = _open_osfhandle((intptr_t)read_pipe, _O_RDONLY);
#endif

   	    // create a single thread to prefix decompression
        boost::thread input_thread(
            boost::bind(
                curl_download_url,
                srcml_request_t(),
                srcml_input_t(1, input),
                srcml_output_dest("-", fds[1])
            )
        );

        // the thread will write to fds[1], and the following input can read
        // from fds[0]
        input.fd = fds[0];
}
