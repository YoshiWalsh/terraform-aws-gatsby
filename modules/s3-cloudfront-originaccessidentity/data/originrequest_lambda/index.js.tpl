'use strict';

var URL = require('url').URL;

var directoryIndexKey = "${index_document}";

exports.handler = (event, context, callback) => {
    var request = event.Records[0].cf.request;
    var uri = request.uri;
    console.log("URI before rewriting: " + uri);

    // Discard query string & hash
    var urlObject = new URL("https://www.example.com" + uri);
    uri = urlObject.pathname;

    // If the URI has a trailing slash, append directoryIndexKey
    if (uri.slice(-1) === "/") {
        uri += directoryIndexKey;
    }

    // Restore query string & hash
    uri = uri + urlObject.search + urlObject.hash;
    
    request.uri = uri;
    
    console.log("URI after rewriting: " + uri);
    return callback(null, request);
};