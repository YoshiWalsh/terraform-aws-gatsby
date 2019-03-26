'use strict';
exports.handler = (event, context, callback) => {
    var request = event.Records[0].cf.request;
    var uri = request.uri;
    console.log("URI before rewriting: " + uri);

    uri = uri.replace(/\/$/, '\/index.html'); // Add index.html after trailing slash
    
    request.uri = uri;
    
    console.log("URI after rewriting: " + uri);
    return callback(null, request);
};