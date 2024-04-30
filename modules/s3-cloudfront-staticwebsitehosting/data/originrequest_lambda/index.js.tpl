'use strict';

var URL = require('url').URL;
var AWSLambda = require('@aws-sdk/client-lambda');

const LambdaClient = AWSLambda.LambdaClient;
const InvokeCommand = AWSLambda.InvokeCommand;

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
        callback(null, request);
    }

    return;
};