'use strict';

exports.handler = (event, context, callback) => {
    var cf = event.Records[0].cf;
    var request = cf.request;
    var response = cf.response;

    if (response.status[0] === "3" && response.headers.location && response.headers.location[0] && request.querystring) {
        response.headers.location[0].value += "?" + request.querystring;
    }
    
    return callback(null, response);
};