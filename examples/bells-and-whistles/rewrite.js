'use strict';

exports.handler = (event, context, callback) => {
    var cf = event.Records[0].cf;
    var request = cf.request;

    if (request.uri === "/test3/index.html") {
        request.uri = "/index.html";
    }
    
    return callback(null, request);
};