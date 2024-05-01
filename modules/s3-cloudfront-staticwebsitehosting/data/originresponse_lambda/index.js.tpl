'use strict';

var URL = require('url').URL;
var path = require('path');
var AWSLambda = require('@aws-sdk/client-lambda');
const { Console } = require('console');

const LambdaClient = AWSLambda.LambdaClient;
const InvokeCommand = AWSLambda.InvokeCommand;

var directoryIndexKey = "${index_document}";
var preserveRedirectQuery = ${preserveRedirectQuery};
var emulateStaticWebsiteHosting = ${emulateStaticWebsiteHosting};
var passthroughFunctionQualifiedArn = "${passthrough}";

exports.handler = (event, context, callback) => {
    var cf = event.Records[0].cf;
    var request = cf.request;
    var response = cf.response;
    var uri = request.uri;
    console.log("Settings", JSON.stringify({
        preserveRedirectQuery,
        emulateStaticWebsiteHosting,
        directoryIndexKey,
        passthroughFunctionQualifiedArn,
    }));
    console.log("Request", JSON.stringify(request));
    console.log("Initial response", JSON.stringify(response));

    if (emulateStaticWebsiteHosting) {
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
    }

    if (preserveRedirectQuery) {
        if (response.status[0] === "3" && response.headers.location && response.headers.location[0] && request.querystring) {
            response.headers.location[0].value += "?" + request.querystring;
        }
    }

    console.log("Final response", JSON.stringify(response));

    if (passthroughFunctionQualifiedArn) {
        var lambda = new LambdaClient({
            region: 'us-east-1'
        });

        var qualifiedArnSplitter = passthroughFunctionQualifiedArn.lastIndexOf(":");
        var unqualifiedArn = passthroughFunctionQualifiedArn.slice(0, qualifiedArnSplitter);
        var qualifier = passthroughFunctionQualifiedArn.slice(qualifiedArnSplitter + 1);
        lambda.send(new InvokeCommand({
            InvocationType: "RequestResponse",
            FunctionName: unqualifiedArn,
            Qualifier: qualifier,
            Payload: JSON.stringify(event),
        })).then(data => {
            if(data.FunctionError) {
                callback("User-defined lambda function returned an error: " + data.Payload, null);
                return;
            }
            callback(null, JSON.parse(Buffer.from(data.Payload).toString()));
        }, err => {
            callback(err, null);
        });
    } else {
        callback(null, response);
    }

    return;
};