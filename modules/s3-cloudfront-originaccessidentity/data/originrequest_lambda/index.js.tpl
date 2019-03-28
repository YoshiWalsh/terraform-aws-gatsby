'use strict';

var URL = require('url').URL;
var AWS = require('aws-sdk');

var directoryIndexKey = "${index_document}";
var passthroughFunctionQualifiedArn = "${passthrough}";

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

    if (passthroughFunctionQualifiedArn) {
        var lambda = new AWS.Lambda({
            region: 'us-east-1'
        });

        var qualifiedArnSplitter = passthroughFunctionQualifiedArn.lastIndexOf(":");
        var unqualifiedArn = passthroughFunctionQualifiedArn.slice(0, qualifiedArnSplitter);
        var qualifier = passthroughFunctionQualifiedArn.slice(qualifiedArnSplitter + 1);
        lambda.invoke({
            InvocationType: "RequestResponse",
            FunctionName: unqualifiedArn,
            Qualifier: qualifier
            Payload: JSON.stringify(event),
        }, function(err, data) {
            callback(err, JSON.parse(data));
        });
    } else {
        callback(null, request);
    }

    return;
};