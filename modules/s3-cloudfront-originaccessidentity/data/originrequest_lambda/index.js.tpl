'use strict';

var URL = require('url').URL;

var directoryIndexKey = "${index_document}";

exports.handler = (event, context, callback) => {
    var request = event.Records[0].cf.request;
    var uri = request.uri;
    console.log("URI before rewriting: " + uri);

    // If the URI has a trailing slash, append directoryIndexKey
    if (uri.slice(-1) === "/") {
        uri += directoryIndexKey;
    }
    
    request.uri = uri;
    
    console.log("URI after rewriting: " + uri);
    return callback(null, request);
};