'use strict';

var URL = require('url').URL;
var path = require('path');
var AWS = require('aws-sdk');

var directoryIndexKey = "${index_document}";
var passthroughFunctionQualifiedArn = "${passthrough}";

exports.handler = (event, context, callback) => {
    var cf = event.Records[0].cf;
    var uri = cf.request.uri;
    var response = cf.response;
    console.log("Processing response for URI: " + uri);
    console.log("Original response code: " + response.status);

    if (response.status === "403" && uri.slice(-1) !== "/" && uri.slice(0 - directoryIndexKey.length) !== directoryIndexKey) {
        // Add trailing slash
        uri += '/';

        // Redirect
        response.status = "301";
        response.statusDescription = "Moved Permanently";
        response.body = "";
        response.headers["location"] = [{
            key: "Location",
            value: uri
        }];
        console.log("301 redirecting to ", uri);
    }

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
            Qualifier: qualifier,
            Payload: JSON.stringify(event),
        }, function(err, data) {
            if(err) {
                callback(err, null);
                return;
            }
            if(data.FunctionError) {
                callback("User-defined lambda function returned an error: " + data.Payload, null);
            }
            callback(null, JSON.parse(data.Payload));
        });
    } else {
        callback(null, response);
    }

    return;
};