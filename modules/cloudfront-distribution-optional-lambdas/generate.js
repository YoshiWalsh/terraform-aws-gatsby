#!/usr/bin/env node
'use strict';

/* Designed to be run with Node 8.10 */
/* IMPORTANT: If you modify this file or any templates, please run it before you commit your changes and include the output in your commit */

// This JavaScript is not pretty, but it's only necessary until Terraform 0.12 comes out. Forgive me.

var fs = require('fs');

var mainTemplate = fs.readFileSync(__dirname + '/templates/main-template.tf', 'utf8');

// This array will contain Slot objects, each of which has a slotName string and a replacements array.
// The replacements array contains Replacement objects, each of which has a condition string and a value string.
var slotReplacements = getSlots();

fs.writeFileSync(__dirname + "/generated.tf", generate(mainTemplate, slotReplacements));

function getSlots() {
    var slotReplacements = [];

    // The first Slot is for S3 vs custom origins.
    slotReplacements.push({
        slotName: "ORIGIN SLOT",
        replacements: [
            {
                condition: 'var.origin_access_identity != ""',
                value: [
                    's3_origin_config {',
                    '    origin_access_identity = "${var.origin_access_identity}"',
                    '}',
                ].join("\n")
            },
            {
                condition: 'var.origin_access_identity == ""',
                value: [
                    'custom_origin_config {',
                    '    http_port = "${var.custom_origin_http_port}"',
                    '    https_port = "${var.custom_origin_https_port}"',
                    '    origin_protocol_policy = "${var.custom_origin_protocol_policy}"',
                    '    origin_ssl_protocols = "${var.custom_origin_ssl_protocols}"',
                    '}',
                ].join("\n")
            }
        ]
    });

    // The second Slot is for all the combinations of Lambda functions
    slotReplacements.push({
        slotName: "LAMBDA SLOT",
        replacements: getLambdaReplacements()
    });

    // The third Slot is for all the combinations of custom error handlers
    slotReplacements.push({
        slotName: "CUSTOM RESPONSE SLOT",
        replacements: getResponseReplacements()
    })

    return slotReplacements;
};

function generateCombinations(places, base, getConditionsAndInclusions) {
    var replacements = [];
    for(var i = 0; i < Math.pow(base, places.length); i++) {
        var conditions = [];
        var inclusions = [];
    
        for(var i2 = 0; i2 < places.length; i2++) {
            var place = places[i2];
            var discriminator = (Math.floor(i / Math.pow(base, i2))) % base;
            var conditionsAndInclusions = getConditionsAndInclusions(place, discriminator);
            conditions = conditions.concat(conditionsAndInclusions.conditions);
            inclusions = inclusions.concat(conditionsAndInclusions.inclusions);
        }

        replacements.push({
            condition: conditions.join(" && "),
            value: inclusions.join("\n")
        });
    }
    return replacements;
}

function getResponseReplacements() {
    var responseTypes = [
        403,
        404
    ];

    return generateCombinations(responseTypes, 2, function(responseType, discriminator) {
        var responseEnabled = !!discriminator;

        var responseCondition = "var.custom_response_" + responseType + "_enabled";
        if(responseEnabled) {
            return {
                conditions: [responseCondition],
                inclusions: [
                    [
                        'custom_error_response {',
                        '    error_code = ' + responseType,
                        '    response_code = "${var.custom_response_' + responseType + '_code}"',
                        '    response_page_path = "${var.custom_response_' + responseType + '_page_path}"',
                        '}',
                    ].join("\n")
                ]
            };
        } else {
            return {
                conditions: ['!' + responseCondition],
                inclusions: []
            };
        }
    });
}

function getLambdaReplacements() {
    var lambdaTypes = [
        "viewer-request",
        "origin-request",
        "origin-response",
        "viewer-response"
    ];

    return generateCombinations(lambdaTypes, 3, function(lambdaType, discriminator) {
        var conditions = [];
        var lambdas = [];

        var tfLambdaType = lambdaType.replace('-', '');
        var lambdaEnabledVariable = "var." + tfLambdaType + "_lambda_enabled";
        var lambdaArnVariable = "var." + tfLambdaType + "_lambda_qualifiedarn";
        var lambdaBodyVariable = "var." + tfLambdaType + "_lambda_includebody";

        var functionEnabled = discriminator > 0;
        var bodyIncluded = discriminator == 2;

        if (functionEnabled) {
            conditions.push(lambdaEnabledVariable);
            conditions.push((bodyIncluded ? '' : '!') + lambdaBodyVariable);
            
            lambdas.push([
                'lambda_function_association {',
                '    event_type = "' + lambdaType + '"',
                '    lambda_arn = "${' + lambdaArnVariable + '}"',
                '    include_body = ' +  (bodyIncluded ? 'true' : 'false'),
                '}',
            ].join("\n"));
        } else {
            conditions.push('!' + lambdaEnabledVariable);
        }

        return {
            conditions: conditions,
            inclusions: lambdas
        };
    });
}

function generate(mainTemplate, slotReplacements) {
    var output = "/*\nThis file is automatically generated, DO NOT modify it manually.\n*/";

    var permutations = slotReplacements.reduce(function(total, cur) {return total * cur.replacements.length;}, 1);

    var resourceConditions = [];

    for(var i = 0; i < permutations; i++) {
        output += "\n";
        var iterationOutput = mainTemplate;
        var conditions = [];
        var currentValue = i;
        for(var i2 = 0; i2 < slotReplacements.length; i2++) {
            var slot = slotReplacements[i2];
            var discriminator = currentValue % slot.replacements.length;
            var replacement = slot.replacements[discriminator];

            conditions.push(replacement.condition);
            iterationOutput = replaceWithIndentation(iterationOutput, "/* " + slot.slotName + " */", replacement.value);

            currentValue = (currentValue - discriminator) / slot.replacements.length;
        }

        var resourceName = "distribution_permutation_" + i;
        var conditionsString = conditions.join(" && ");
        iterationOutput = iterationOutput.replace("/* CONDITION */", 'count = "${(' + conditionsString + ') ? 1 : 0}"');
        iterationOutput = iterationOutput.replace("distribution_permutation", resourceName);
        resourceConditions.push({
            resourceName: resourceName,
            condition: conditionsString
        });

        output += iterationOutput;
        output += "\n";
    }

    var resourceConditionTree = recursivelyMergePathsIntoTree(createConditionPaths(resourceConditions));
    
    output += "\n";

    var outputs = [
        "id",
        "arn",
        "status",
        "domain_name",
        "etag",
        "hosted_zone_id"
    ];
    for(var i = 0; i < outputs.length; i++) {
        output += [
            '\noutput "' + outputs[i] + '" {',
            '    value = "${' + getAttributeExpression(resourceConditionTree, "aws_cloudfront_distribution", outputs[i]) + '}"',
            '}\n'
        ].join('\n');
    }

    return output;
}

function createConditionPaths(resourceConditions) {
    return resourceConditions.map(function(resourceCondition) {
        return {
            resourceName: resourceCondition.resourceName,
            path: resourceCondition.condition.split(" && ")
        };
    }).sort(function(a, b) {
        var maxElems = Math.max(a.length, b.length);
        for(var i = 0; i < maxElems; i++) {
            var aElm = a[i];
            var bElm = b[i];

            if(aElm != undefined && bElm == undefined) {
                return -1;
            }
            if(bElm != undefined && aElm == undefined) {
                return 1;
            }
            if(aElm < bElm) {
                return -1;
            }
            if(bElm < aElm) {
                return 1;
            }
        }
        return 0;
    });
}

function recursivelyMergePathsIntoTree(resourcePaths) {
    var groupedPaths = {};
    if(resourcePaths.length > 1) {
        for(var i = 0; i < resourcePaths.length; i++) {
            var resourcePath = resourcePaths[i];
            var firstElement = resourcePath.path[0];
            if(!firstElement) {
                console.warn(resourcePaths);
                throw new Error("We have multiple resources on the same path, but we've run out of conditions to use to separate them.");
            }
            if(!groupedPaths[firstElement]) {
                groupedPaths[firstElement] = [];
            }
            groupedPaths[firstElement].push({
                resourceName: resourcePath.resourceName,
                path: resourcePath.path.slice(1)
            });
        }
        var tree = {};
        for(var k in groupedPaths) {
            var paths = groupedPaths[k];

            tree[k] = recursivelyMergePathsIntoTree(paths);
        }
        return tree;
    } else {
        return resourcePaths[0].resourceName;
    }
}

function getAttributeExpression(resourceConditionTree, resourceType, attributeName) {
    if(typeof(resourceConditionTree) === "string") {
        return 'element(concat(' + resourceType + "." + resourceConditionTree + ".*." + attributeName + ', list("")), 0)';
    }
    var conditions = Object.keys(resourceConditionTree);
    if(conditions.length !== 2) {
        throw new Error("Resource condition tree has a fork with " + conditions.length + " branches, but we only support 2 branch forks.");
    }
    var antinegatedFirstCondition = conditions[0].replace("!=", "==").replace("!", "");
    var antinegatedSecondCondition = conditions[1].replace("!=", "==").replace("!", "");
    var firstBranchIsNonNegated = antinegatedFirstCondition == conditions[0];
    var secondBranchIsNonNegated = antinegatedSecondCondition == conditions[1];
    if(antinegatedFirstCondition !== antinegatedSecondCondition && (firstBranchIsNonNegated || secondBranchIsNonNegated)) {
        throw new Error("Resource condition tree has a fork with a complex condition. Only forks where one branch's condition is a negation of the other branch's condition are supported.");
    }

    var positiveCondition = antinegatedFirstCondition;
    var negativeCondition = firstBranchIsNonNegated ? conditions[1] : conditions[0];

    var positiveChildren = getAttributeExpression(resourceConditionTree[positiveCondition], resourceType, attributeName);
    var negativeChildren = getAttributeExpression(resourceConditionTree[negativeCondition], resourceType, attributeName);
    return "(" + positiveCondition + " ? " + positiveChildren + " : " + negativeChildren + ")";
}

function replaceWithIndentation(haystack, needle, replaceWith) {
    var regex = new RegExp("^([ \\t]*)" + regexEscape(needle), "gm");
    return haystack.replace(regex, function(str, indentation) {
        return replaceWith.split("\n").map(function(str) { return indentation + str; }).join("\n");
    })
}

function regexEscape(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}