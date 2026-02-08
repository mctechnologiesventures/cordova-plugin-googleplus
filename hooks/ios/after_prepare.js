#!/usr/bin/env node

/**
 * after_prepare hook for cordova-plugin-googleplus
 *
 * Reads REVERSED_CLIENT_ID from GoogleService-Info.plist and injects
 * the corresponding URL scheme into the app's Info.plist.
 */

var fs = require('fs');
var path = require('path');

module.exports = function (context) {
    var platformRoot = path.join(context.opts.projectRoot, 'platforms', 'ios');

    if (!fs.existsSync(platformRoot)) {
        console.log('GooglePlus: iOS platform not found, skipping after_prepare hook.');
        return;
    }

    // Find the app name by looking for *-Info.plist in subdirectories
    var appName = findAppName(platformRoot);
    if (!appName) {
        console.error('GooglePlus: Could not determine app name from iOS platform directory.');
        return;
    }

    // Find GoogleService-Info.plist
    var googlePlistPath = findGoogleServicePlist(platformRoot, appName);
    if (!googlePlistPath) {
        console.error('GooglePlus: GoogleService-Info.plist not found in iOS platform directory.');
        return;
    }

    // Read and parse REVERSED_CLIENT_ID from GoogleService-Info.plist
    var googlePlistContent = fs.readFileSync(googlePlistPath, 'utf8');
    var reversedClientIdMatch = googlePlistContent.match(/<key>REVERSED_CLIENT_ID<\/key>\s*<string>(.*?)<\/string>/);
    if (!reversedClientIdMatch) {
        console.error('GooglePlus: Could not find REVERSED_CLIENT_ID in GoogleService-Info.plist.');
        return;
    }
    var reversedClientId = reversedClientIdMatch[1];
    console.log('GooglePlus: Read REVERSED_CLIENT_ID from GoogleService-Info.plist: ' + reversedClientId);

    // Find and read the app's Info.plist
    var infoPlistPath = path.join(platformRoot, appName, appName + '-Info.plist');
    if (!fs.existsSync(infoPlistPath)) {
        console.error('GooglePlus: App Info.plist not found at: ' + infoPlistPath);
        return;
    }

    var infoPlistContent = fs.readFileSync(infoPlistPath, 'utf8');

    // Check if CFBundleURLTypes exists
    var hasUrlTypes = infoPlistContent.indexOf('<key>CFBundleURLTypes</key>') !== -1;

    // Check if REVERSED_CLIENT_ID entry already exists
    var hasReversedClientIdEntry = infoPlistContent.indexOf('<string>REVERSED_CLIENT_ID</string>') !== -1;

    var urlSchemeEntry =
        '\t\t<dict>\n' +
        '\t\t\t<key>CFBundleTypeRole</key>\n' +
        '\t\t\t<string>Editor</string>\n' +
        '\t\t\t<key>CFBundleURLName</key>\n' +
        '\t\t\t<string>REVERSED_CLIENT_ID</string>\n' +
        '\t\t\t<key>CFBundleURLSchemes</key>\n' +
        '\t\t\t<array>\n' +
        '\t\t\t\t<string>' + reversedClientId + '</string>\n' +
        '\t\t\t</array>\n' +
        '\t\t</dict>';

    if (hasReversedClientIdEntry) {
        // Update existing entry — replace the URL scheme value
        var updateRegex = /(<key>CFBundleURLName<\/key>\s*<string>REVERSED_CLIENT_ID<\/string>\s*<key>CFBundleURLSchemes<\/key>\s*<array>\s*<string>)(.*?)(<\/string>\s*<\/array>)/;
        infoPlistContent = infoPlistContent.replace(updateRegex, '$1' + reversedClientId + '$3');
        console.log('GooglePlus: Updated existing REVERSED_CLIENT_ID URL scheme in Info.plist.');
    } else if (hasUrlTypes) {
        // CFBundleURLTypes exists but no REVERSED_CLIENT_ID entry — add it
        var arrayInsertRegex = /(<key>CFBundleURLTypes<\/key>\s*<array>)/;
        infoPlistContent = infoPlistContent.replace(arrayInsertRegex, '$1\n' + urlSchemeEntry);
        console.log('GooglePlus: Added REVERSED_CLIENT_ID URL scheme to existing CFBundleURLTypes in Info.plist.');
    } else {
        // No CFBundleURLTypes at all — add before closing </dict></plist>
        var closingTag = '</dict>\n</plist>';
        var newBlock =
            '\t<key>CFBundleURLTypes</key>\n' +
            '\t<array>\n' +
            urlSchemeEntry + '\n' +
            '\t</array>\n' +
            closingTag;
        infoPlistContent = infoPlistContent.replace(closingTag, newBlock);
        console.log('GooglePlus: Created CFBundleURLTypes with REVERSED_CLIENT_ID URL scheme in Info.plist.');
    }

    fs.writeFileSync(infoPlistPath, infoPlistContent, 'utf8');
    console.log('GooglePlus: Info.plist updated successfully.');
};

function findAppName(platformRoot) {
    var entries = fs.readdirSync(platformRoot);
    for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        var entryPath = path.join(platformRoot, entry);
        if (fs.statSync(entryPath).isDirectory() && entry !== 'CordovaLib' && entry !== 'Pods' && !entry.startsWith('.') && entry !== 'build' && entry !== 'cordova') {
            var infoPlist = path.join(entryPath, entry + '-Info.plist');
            if (fs.existsSync(infoPlist)) {
                return entry;
            }
        }
    }
    return null;
}

function findGoogleServicePlist(platformRoot, appName) {
    var candidates = [
        path.join(platformRoot, appName, 'Resources', 'GoogleService-Info.plist'),
        path.join(platformRoot, appName, 'GoogleService-Info.plist'),
        path.join(platformRoot, 'GoogleService-Info.plist')
    ];
    for (var i = 0; i < candidates.length; i++) {
        if (fs.existsSync(candidates[i])) {
            return candidates[i];
        }
    }
    return null;
}
