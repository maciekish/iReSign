//
//  iReSignAppDelegate.m
//  iReSign
//
//  Created by Maciej Swic on 2011-05-16.
//

#import "iReSignAppDelegate.h"

@implementation iReSignAppDelegate

@synthesize window,workingPath;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self resizeWindow:145];
    [flurry setAlphaValue:0.5];
    
    defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults valueForKey:@"CERT_NAME"])
        [certField setStringValue:[defaults valueForKey:@"CERT_NAME"]];
    if ([defaults valueForKey:@"MOBILEPROVISION_PATH"])
        [provisioningPathField setStringValue:[defaults valueForKey:@"MOBILEPROVISION_PATH"]];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/zip"]) {
        NSRunAlertPanel(@"Error", 
                        @"This app cannot run without the zip utility present at /usr/bin/zip",
                        @"OK",nil,nil);
        exit(0);
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/unzip"]) {
        NSRunAlertPanel(@"Error", 
                        @"This app cannot run without the unzip utility present at /usr/bin/unzip",
                        @"OK",nil,nil);
        exit(0);
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/codesign"]) {
        NSRunAlertPanel(@"Error", 
                        @"This app cannot run without the codesign utility present at /usr/bin/codesign",
                        @"OK",nil, nil);
        exit(0);
    }
}

- (IBAction)resign:(id)sender {
    //Save cert name
    [defaults setValue:[certField stringValue] forKey:@"CERT_NAME"];
    [defaults setValue:[provisioningPathField stringValue] forKey:@"MOBILEPROVISION_PATH"];
    [defaults synchronize];
    
    codesigningResult = nil;
    verificationResult = nil;
    
    originalIpaPath = [[pathField stringValue] retain];
    workingPath = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"com.appulize.iresign"] retain];
    
    if ([[[originalIpaPath pathExtension] lowercaseString] isEqualToString:@"ipa"]) {
        [self disableControls];
        
        NSLog(@"Setting up working directory in %@",workingPath);
        [statusLabel setStringValue:@"Setting up working directory"];
        
        [[NSFileManager defaultManager] removeItemAtPath:workingPath error:nil];
        
        [[NSFileManager defaultManager] createDirectoryAtPath:workingPath withIntermediateDirectories:TRUE attributes:nil error:nil];
        
        if (originalIpaPath && [originalIpaPath length] > 0) {
            NSLog(@"Unzipping %@",originalIpaPath);
            [statusLabel setStringValue:@"Extracting original app"];
        }
        
        unzipTask = [[NSTask alloc] init];
        [unzipTask setLaunchPath:@"/usr/bin/unzip"];
        [unzipTask setArguments:[NSArray arrayWithObjects:@"-q", originalIpaPath, @"-d", workingPath, nil]];
		
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkUnzip:) userInfo:nil repeats:TRUE];
        
        [unzipTask launch];
    } else {
        NSRunAlertPanel(@"Error", 
                        @"You must choose an *.ipa file",
                        @"OK",nil,nil);
        [self enableControls];
        [statusLabel setStringValue:@"Please try again"];
    }
}

- (void)checkUnzip:(NSTimer *)timer {
    if ([unzipTask isRunning] == 0) {
        [timer invalidate];
        [unzipTask release];
        unzipTask = nil;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[workingPath stringByAppendingPathComponent:@"Payload"]]) {
            NSLog(@"Unzipping done");
            [statusLabel setStringValue:@"Original app extracted"];
            if ([[provisioningPathField stringValue] isEqualTo:@""]) {
                [self doCodeSigning];
            } else {
                [self doProvisioning];
            }
        } else {
            NSRunAlertPanel(@"Error", 
                            @"Unzip failed",
                            @"OK",nil,nil);
            [self enableControls];
            [statusLabel setStringValue:@"Ready"];
        }
    }
}

- (void)doProvisioning {
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:@"Payload"] error:nil];
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            appPath = [[workingPath stringByAppendingPathComponent:@"Payload"] stringByAppendingPathComponent:file];
            if ([[NSFileManager defaultManager] fileExistsAtPath:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"]]) {
                NSLog(@"Found embedded.mobileprovision, deleting.");
                [[NSFileManager defaultManager] removeItemAtPath:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"] error:nil];
            }
            break;
        }
    }
    
    NSString *targetPath = [appPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
    
    provisioningTask = [[NSTask alloc] init];
    [provisioningTask setLaunchPath:@"/bin/cp"];
    [provisioningTask setArguments:[NSArray arrayWithObjects:[provisioningPathField stringValue], targetPath, nil]];
    
    [provisioningTask launch];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkProvisioning:) userInfo:nil repeats:TRUE];
}

- (void)checkProvisioning:(NSTimer *)timer {
    if ([provisioningTask isRunning] == 0) {
        [timer invalidate];
        [provisioningTask release];
        provisioningTask = nil;
        
        NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:@"Payload"] error:nil];
        
        for (NSString *file in dirContents) {
            if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
                appPath = [[workingPath stringByAppendingPathComponent:@"Payload"] stringByAppendingPathComponent:file];
                if ([[NSFileManager defaultManager] fileExistsAtPath:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"]]) {
                    
                    BOOL identifierOK = FALSE;
                    NSString *identifierInProvisioning = @"";
                    
                    NSString *embeddedProvisioning = [NSString stringWithContentsOfFile:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"] encoding:NSASCIIStringEncoding error:nil];
                    NSArray* embeddedProvisioningLines = [embeddedProvisioning componentsSeparatedByCharactersInSet:
                                                          [NSCharacterSet newlineCharacterSet]];
                    
                    for (int i = 0; i <= [embeddedProvisioningLines count]; i++) {
                        if ([[embeddedProvisioningLines objectAtIndex:i] rangeOfString:@"application-identifier"].location != NSNotFound) {
                            
                            NSInteger fromPosition = [[embeddedProvisioningLines objectAtIndex:i+1] rangeOfString:@"<string>"].location + 8;
                            
                            NSInteger toPosition = [[embeddedProvisioningLines objectAtIndex:i+1] rangeOfString:@"</string>"].location;
                            
                            NSRange range;
                            range.location = fromPosition;
                            range.length = toPosition-fromPosition;
                            
                            NSString *fullIdentifier = [[embeddedProvisioningLines objectAtIndex:i+1] substringWithRange:range];
                            
                            NSArray *identifierComponents = [fullIdentifier componentsSeparatedByString:@"."];
                            
                            if ([[identifierComponents lastObject] isEqualTo:@"*"]) {
                                identifierOK = TRUE;
                            }
                            
                            for (int i = 1; i < [identifierComponents count]; i++) {
                                identifierInProvisioning = [identifierInProvisioning stringByAppendingString:[identifierComponents objectAtIndex:i]];
                                if (i < [identifierComponents count]-1) {
                                    identifierInProvisioning = [identifierInProvisioning stringByAppendingString:@"."];
                                }
                            }
                            break;
                        }
                    }
                    
                    NSLog(@"Mobileprovision identifier: %@",identifierInProvisioning);
                    
                    NSString *infoPlist = [NSString stringWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"] encoding:NSASCIIStringEncoding error:nil];
                    if ([infoPlist rangeOfString:identifierInProvisioning].location != NSNotFound) {
                        NSLog(@"Identifiers match");
                        identifierOK = TRUE;
                    }
                    
                    if (identifierOK) {
                        NSLog(@"Provisioning completed.");
                        [statusLabel setStringValue:@"Provisioning completed"];
                        [self doCodeSigning];
                    } else {
                        NSRunAlertPanel(@"Error",
                                        @"Product identifiers don't match",
                                        @"OK",nil,nil);
                        [self enableControls];
                        [statusLabel setStringValue:@"Ready"];
                    }
                } else {
                    NSRunAlertPanel(@"Error",
                                    @"Provisioning failed",
                                    @"OK",nil,nil);
                    [self enableControls];
                    [statusLabel setStringValue:@"Ready"];
                }
                break;
            }
        }
    }
}

- (void)doCodeSigning {
    appPath = nil;
    
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:@"Payload"] error:nil];
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            appPath = [[workingPath stringByAppendingPathComponent:@"Payload"] stringByAppendingPathComponent:file];
            NSLog(@"Found %@",appPath);
            appName = [file retain];
            [statusLabel setStringValue:[NSString stringWithFormat:@"Codesigning %@",file]];
            break;
        }
    }
    
    if (appPath) {
        NSString *resourceRulesPath = [[NSBundle mainBundle] pathForResource:@"ResourceRules" ofType:@"plist"];
        NSString *resourceRulesArgument = [NSString stringWithFormat:@"--resource-rules=%@",resourceRulesPath];
        
        codesignTask = [[NSTask alloc] init];
        [codesignTask setLaunchPath:@"/usr/bin/codesign"];
        [codesignTask setArguments:[NSArray arrayWithObjects:@"-fs", [certField stringValue], resourceRulesArgument, appPath, nil]];
		
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkCodesigning:) userInfo:nil repeats:TRUE];
        
        [appPath retain];
        
        NSPipe *pipe=[NSPipe pipe];
        [codesignTask setStandardOutput:pipe];
        [codesignTask setStandardError:pipe];
        NSFileHandle *handle=[pipe fileHandleForReading];
        
        [codesignTask launch];
        
        [NSThread detachNewThreadSelector:@selector(watchCodesigning:)
                                 toTarget:self withObject:handle];
    }
}

- (void)watchCodesigning:(NSFileHandle*)streamHandle {
    NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
    
    codesigningResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    
    [pool release];
}

- (void)checkCodesigning:(NSTimer *)timer {
    if ([codesignTask isRunning] == 0) {
        [timer invalidate];
        [codesignTask release];
        codesignTask = nil;
        NSLog(@"Codesigning done");
        [statusLabel setStringValue:@"Codesigning completed"];
        [self doVerifySignature];
    }
}

- (void)doVerifySignature {
    if (appPath) {
        verifyTask = [[NSTask alloc] init];
        [verifyTask setLaunchPath:@"/usr/bin/codesign"];
        [verifyTask setArguments:[NSArray arrayWithObjects:@"-v", appPath, nil]];
		
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkVerificationProcess:) userInfo:nil repeats:TRUE];
        
        NSLog(@"Verifying %@",appPath);
        [statusLabel setStringValue:[NSString stringWithFormat:@"Verifying %@",appName]];
        
        NSPipe *pipe=[NSPipe pipe];
        [verifyTask setStandardOutput:pipe];
        [verifyTask setStandardError:pipe];
        NSFileHandle *handle=[pipe fileHandleForReading];
        
        [verifyTask launch];
        
        [NSThread detachNewThreadSelector:@selector(watchVerificationProcess:)
                                 toTarget:self withObject:handle];
    }
}

- (void)watchVerificationProcess:(NSFileHandle*)streamHandle {
    NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
    
    verificationResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    
    [pool release];
}

- (void)checkVerificationProcess:(NSTimer *)timer {
    if ([verifyTask isRunning] == 0) {
        [timer invalidate];
        [verifyTask release];
        verifyTask = nil;
        if ([verificationResult length] == 0) {
            NSLog(@"Verification done");
            [statusLabel setStringValue:@"Verification completed"];
            [self doZip];
        } else {
            NSString *error = [[codesigningResult stringByAppendingString:@"\n\n"] stringByAppendingString:verificationResult];
            NSRunAlertPanel(@"Signing failed", error, @"OK",nil, nil);
            [self enableControls];
            [statusLabel setStringValue:@"Please try again"];
        }
    }
}

- (void)doZip {
    if (appPath) {
        NSArray *destinationPathComponents = [originalIpaPath pathComponents];
        NSString *destinationPath = @"";
        
        for (int i = 0; i < ([destinationPathComponents count]-1); i++) {
            destinationPath = [destinationPath stringByAppendingPathComponent:[destinationPathComponents objectAtIndex:i]];
        }
        
        fileName = [originalIpaPath lastPathComponent];
        fileName = [fileName substringToIndex:[fileName length]-4];
        fileName = [fileName stringByAppendingString:@"-resigned"];
        fileName = [fileName stringByAppendingPathExtension:@"ipa"];
        
        destinationPath = [destinationPath stringByAppendingPathComponent:fileName];
        
        NSLog(@"Dest: %@",destinationPath);
        
        zipTask = [[NSTask alloc] init];
        [zipTask setLaunchPath:@"/usr/bin/zip"];
        [zipTask setCurrentDirectoryPath:workingPath];
        [zipTask setArguments:[NSArray arrayWithObjects:@"-qr", destinationPath, @".", nil]];
		
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkZip:) userInfo:nil repeats:TRUE];
        
        NSLog(@"Zipping %@", destinationPath);
        [statusLabel setStringValue:[NSString stringWithFormat:@"Saving %@",fileName]];
        
        [fileName retain];
        [zipTask launch];
    }
}

- (void)checkZip:(NSTimer *)timer {
    if ([zipTask isRunning] == 0) {
        [timer invalidate];
        [zipTask release];
        zipTask = nil;
        NSLog(@"Zipping done");
        [statusLabel setStringValue:[NSString stringWithFormat:@"Saved %@",fileName]];
        
        [[NSFileManager defaultManager] removeItemAtPath:workingPath error:nil];
        
        [appPath release];
        [workingPath release];
        [self enableControls];
        
        NSString *result = [[codesigningResult stringByAppendingString:@"\n\n"] stringByAppendingString:verificationResult];
        NSLog(@"Codesigning result: %@",result);
    }
}

- (IBAction)browse:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    
    if ( [openDlg runModalForTypes:[NSArray arrayWithObject:@"ipa"]] == NSOKButton )
    {        
        NSString* fileNameOpened = [[openDlg filenames] objectAtIndex:0];
        [pathField setStringValue:fileNameOpened];
    }
}

- (IBAction)provisioningBrowse:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    
    if ( [openDlg runModalForTypes:[NSArray arrayWithObject:@"mobileprovision"]] == NSOKButton )
    {        
        NSString* fileNameOpened = [[openDlg filenames] objectAtIndex:0];
        [provisioningPathField setStringValue:fileNameOpened];
    }
}

- (IBAction)showHelp:(id)sender {
    NSRunAlertPanel(@"How to use iReSign", 
                    @"iReSign allows you to re-sign any unencrypted ipa-file with any certificate for which you hold the corresponding private key.\n\n1. Drag your unsigned .ipa file to the top box, or use the browse button.\n\n2. Enter your full certificate name from Keychain Access, for example \"iPhone Developer: Firstname Lastname (XXXXXXXXXX)\" in the bottom box.\n\n3. Click ReSign! and wait. The resigned file will be saved in the same folder as the original file.",
                    @"OK",nil, nil);
}

- (void)disableControls {
    [pathField setEnabled:FALSE];
    [certField setEnabled:FALSE];
    [browseButton setEnabled:FALSE];
    [resignButton setEnabled:FALSE];
    
    [flurry startAnimation:self];
    [flurry setAlphaValue:1.0];
    
    [self resizeWindow:185];
}

- (void)enableControls {
    [pathField setEnabled:TRUE];
    [certField setEnabled:TRUE];
    [browseButton setEnabled:TRUE];
    [resignButton setEnabled:TRUE];
    
    [flurry stopAnimation:self];
    [flurry setAlphaValue:0.5];
}

- (void)resizeWindow:(int)newHeight {
    NSRect r;
    
    r = NSMakeRect([window frame].origin.x - ([window frame].size.width - (int)(NSWidth([window frame]))), [window frame].origin.y - (newHeight - (int)(NSHeight([window frame]))), [window frame].size.width, newHeight);
    
    [window setFrame:r display:YES animate:YES];
}

@end
