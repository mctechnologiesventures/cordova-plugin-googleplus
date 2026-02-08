#import "GooglePlus.h"

@implementation GooglePlus

- (void)pluginInitialize {
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleOpenURL:)
        name:CDVPluginHandleOpenURLNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleOpenURLWithAppSourceAndAnnotation:)
        name:CDVPluginHandleOpenURLWithAppSourceAndAnnotationNotification object:nil];
}

- (NSString*)getClientId {
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"GoogleService-Info" ofType:@"plist"];
    if (plistPath) {
        NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        return plist[@"CLIENT_ID"];
    }
    return nil;
}

- (NSString*)getReversedClientId {
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"GoogleService-Info" ofType:@"plist"];
    if (plistPath) {
        NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        return plist[@"REVERSED_CLIENT_ID"];
    }
    return nil;
}

- (void)handleOpenURL:(NSNotification*)notification {
    // no-op, need sourceApplication from the other handler
}

- (void)handleOpenURLWithAppSourceAndAnnotation:(NSNotification*)notification {
    NSMutableDictionary *options = [notification object];
    NSURL *url = options[@"url"];
    NSString *possibleReversedClientId = [url.absoluteString componentsSeparatedByString:@":"].firstObject;
    if ([possibleReversedClientId isEqualToString:[self getReversedClientId]] && self.isSigningIn) {
        self.isSigningIn = NO;
        [GIDSignIn.sharedInstance handleURL:url];
    }
}

- (void)isAvailable:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)login:(CDVInvokedUrlCommand*)command {
    _callbackId = command.callbackId;
    NSDictionary *options = command.arguments[0];

    NSString *clientId = [self getClientId];
    if (clientId == nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
            messageAsString:@"Could not find CLIENT_ID in GoogleService-Info.plist"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:_callbackId];
        return;
    }

    NSString *serverClientId = options[@"webClientId"];
    NSString *loginHint = options[@"loginHint"];
    BOOL offline = [options[@"offline"] boolValue];
    NSString *hostedDomain = options[@"hostedDomain"];
    NSString *scopesString = options[@"scopes"];

    // Create configuration
    GIDConfiguration *config;
    if (serverClientId != nil && offline) {
        if (hostedDomain != nil) {
            config = [[GIDConfiguration alloc] initWithClientID:clientId
                                                 serverClientID:serverClientId
                                                   hostedDomain:hostedDomain
                                                    openIDRealm:nil];
        } else {
            config = [[GIDConfiguration alloc] initWithClientID:clientId
                                                 serverClientID:serverClientId];
        }
    } else {
        if (hostedDomain != nil) {
            config = [[GIDConfiguration alloc] initWithClientID:clientId
                                                 serverClientID:nil
                                                   hostedDomain:hostedDomain
                                                    openIDRealm:nil];
        } else {
            config = [[GIDConfiguration alloc] initWithClientID:clientId];
        }
    }
    GIDSignIn.sharedInstance.configuration = config;

    // Parse scopes
    NSArray *scopes = nil;
    if (scopesString != nil) {
        scopes = [scopesString componentsSeparatedByString:@" "];
    }

    self.isSigningIn = YES;

    // Call signIn with completion handler
    [GIDSignIn.sharedInstance signInWithPresentingViewController:self.viewController
                                                           hint:loginHint
                                               additionalScopes:scopes
                                                     completion:^(GIDSignInResult * _Nullable signInResult,
                                                                  NSError * _Nullable error) {
        self.isSigningIn = NO;
        if (error) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                messageAsString:error.localizedDescription];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self->_callbackId];
            return;
        }

        GIDGoogleUser *user = signInResult.user;
        NSURL *imageUrl = [user.profile imageURLWithDimension:120];

        NSDictionary *result = @{
            @"email"          : user.profile.email ?: [NSNull null],
            @"idToken"        : user.idToken ? user.idToken.tokenString : @"",
            @"serverAuthCode" : signInResult.serverAuthCode ?: @"",
            @"accessToken"    : user.accessToken.tokenString ?: @"",
            @"refreshToken"   : user.refreshToken.tokenString ?: @"",
            @"userId"         : user.userID ?: [NSNull null],
            @"displayName"    : user.profile.name ?: [NSNull null],
            @"givenName"      : user.profile.givenName ?: [NSNull null],
            @"familyName"     : user.profile.familyName ?: [NSNull null],
            @"imageUrl"       : imageUrl ? imageUrl.absoluteString : [NSNull null],
        };

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
            messageAsDictionary:result];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self->_callbackId];
    }];
}

- (void)trySilentLogin:(CDVInvokedUrlCommand*)command {
    _callbackId = command.callbackId;
    NSDictionary *options = command.arguments[0];

    NSString *clientId = [self getClientId];
    if (clientId == nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
            messageAsString:@"Could not find CLIENT_ID in GoogleService-Info.plist"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:_callbackId];
        return;
    }

    NSString *serverClientId = options[@"webClientId"];
    BOOL offline = [options[@"offline"] boolValue];
    NSString *hostedDomain = options[@"hostedDomain"];

    // Create configuration
    GIDConfiguration *config;
    if (serverClientId != nil && offline) {
        if (hostedDomain != nil) {
            config = [[GIDConfiguration alloc] initWithClientID:clientId
                                                 serverClientID:serverClientId
                                                   hostedDomain:hostedDomain
                                                    openIDRealm:nil];
        } else {
            config = [[GIDConfiguration alloc] initWithClientID:clientId
                                                 serverClientID:serverClientId];
        }
    } else {
        if (hostedDomain != nil) {
            config = [[GIDConfiguration alloc] initWithClientID:clientId
                                                 serverClientID:nil
                                                   hostedDomain:hostedDomain
                                                    openIDRealm:nil];
        } else {
            config = [[GIDConfiguration alloc] initWithClientID:clientId];
        }
    }
    GIDSignIn.sharedInstance.configuration = config;

    // restorePreviousSignIn returns GIDGoogleUser directly (NOT GIDSignInResult)
    // serverAuthCode is NOT available from restorePreviousSignIn
    [GIDSignIn.sharedInstance restorePreviousSignInWithCompletion:^(GIDGoogleUser * _Nullable user,
                                                                    NSError * _Nullable error) {
        if (error) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                messageAsString:error.localizedDescription];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self->_callbackId];
            return;
        }

        NSURL *imageUrl = [user.profile imageURLWithDimension:120];

        NSDictionary *result = @{
            @"email"          : user.profile.email ?: [NSNull null],
            @"idToken"        : user.idToken ? user.idToken.tokenString : @"",
            @"serverAuthCode" : @"",
            @"accessToken"    : user.accessToken.tokenString ?: @"",
            @"refreshToken"   : user.refreshToken.tokenString ?: @"",
            @"userId"         : user.userID ?: [NSNull null],
            @"displayName"    : user.profile.name ?: [NSNull null],
            @"givenName"      : user.profile.givenName ?: [NSNull null],
            @"familyName"     : user.profile.familyName ?: [NSNull null],
            @"imageUrl"       : imageUrl ? imageUrl.absoluteString : [NSNull null],
        };

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
            messageAsDictionary:result];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self->_callbackId];
    }];
}

- (void)logout:(CDVInvokedUrlCommand*)command {
    [GIDSignIn.sharedInstance signOut];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
        messageAsString:@"logged out"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)disconnect:(CDVInvokedUrlCommand*)command {
    [GIDSignIn.sharedInstance disconnectWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                messageAsString:error.localizedDescription];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
            messageAsString:@"disconnected"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

@end
