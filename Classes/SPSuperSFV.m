/*
 SuperSFV is the legal property of its developers, whose names are
 listed in the copyright file included with this source distribution.

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License along
 with this program; if not, write to the Free Software Foundation, Inc.,
 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#import "SPSuperSFV.h"
#import "SPFileEntry.h"
#import "SPIntegrityOperation.h"

#define SuperSFVToolbarIdentifier    @"SuperSFV Toolbar Identifier"
#define AddToolbarIdentifier         @"Add Toolbar Identifier"
#define RemoveToolbarIdentifier      @"Remove Toolbar Identifier"
#define RecalculateToolbarIdentifier @"Recalculate Toolbar Identifier"
#define ChecksumToolbarIdentifier    @"Checksum Toolbar Identifier"
#define StopToolbarIdentifier        @"Stop Toolbar Identifier"
#define SaveToolbarIdentifier        @"Save Toolbar Identifier"

#pragma mark Private methods
@interface SPSuperSFV ()
- (void)queueEntry:(SPFileEntry *)entry withAlgorithm:(SPCryptoAlgorithm)algorithm;
- (void)updateUI;
- (void)startProcessingQueue;
- (void)stopProcessingQueue;
@end

@implementation SPSuperSFV
@synthesize tableView_fileList;

#pragma mark Initialization (App launching)
+ (void)initialize {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"checksum_algorithm"] = @"CRC32"; // default for most SFV programs
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:dictionary];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    records = [[NSMutableArray alloc] init];
    queue = [[NSOperationQueue alloc] init];
    // TODO: We want to run several ops at the same time in the future
    //[queue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
    
    [self setup_toolbar];

    // this is for the 'status' image
    cell = [[NSImageCell alloc] initImageCell:nil];
    NSTableColumn *tableColumn;
    tableColumn = [tableView_fileList tableColumnWithIdentifier:@"status"];
    [cell setEditable: YES];
    [tableColumn setDataCell:cell];
    cell = [[NSImageCell alloc] initImageCell:nil];

    // selecting items in our table view and pressing the delete key
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(removeSelectedRecords:)
                                                 name:@"RM_RECORD_FROM_LIST"
                                               object:nil];

    // register for drag and drop on the table view
    [tableView_fileList registerForDraggedTypes:
     @[NSFilenamesPboardType]];

    // make the window pertee and show it
    [button_stop setEnabled:NO];
    [self updateUI];

    [window_main center];
    [window_main makeKeyAndOrderFront:nil];
}

#pragma mark Termination (App quitting)
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *) sender
{
    // we're not document based, so we'll quit when the last window is closed
    return YES;
}

/*- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *) sender
{
        if ([records count] > 0) {
            NSBeginAlertSheet(@"Confirm Quit", @"Quit", @"Cancel", nil, window_main, self,
                              @selector(quitSheetDidEnd:returnCode:contextInfo:),
                              nil, nil, @"You seem to still have some unfinished business here bud, sure you want to quit?");
            return NSTerminateLater;
        }
    return NSTerminateNow;
}

- (void) quitSheetDidEnd: (NSWindow *) sheet returnCode: (int) returnCode
             contextInfo: (void *) contextInfo
{
    [NSApp stopModal];
    [NSApp replyToApplicationShouldTerminate: returnCode == NSAlertDefaultReturn];
}*/

- (void) applicationWillTerminate: (NSNotification *) notification
{
    // dealloc, etc

    [updateProgressTimer invalidate];
    updateProgressTimer = nil;

    [queue cancelAllOperations];
    queue = nil;
}

#pragma mark IBActions
- (IBAction)addClicked:(id)sender
{
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setPrompt:@"Add"];
    [oPanel setTitle:@"Add files or folder contents"];
    [oPanel setAllowsMultipleSelection:YES];
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:YES];
    [oPanel beginSheetModalForWindow:window_main completionHandler:^(NSInteger result) {
        if (result == NSOKButton) {
            NSArray *URLs = [oPanel URLs];
            NSMutableArray *paths = [[NSMutableArray alloc] initWithCapacity:[URLs count]];
            for (NSURL *url in URLs) {
                [paths addObject:[url path]];
            }
            [self processFiles:paths];
        }
    }];
}

// Hmm... Is this OK?
- (IBAction)recalculateClicked:(id)sender
{
    NSMutableArray *t = [[NSMutableArray alloc] initWithCapacity:1];
	[t addObjectsFromArray:records];
	[records removeAllObjects];
    for (SPFileEntry *i in t) {
        [self processFiles:@[i.filePath]];
    }
    [self updateUI];
}

- (IBAction)removeClicked:(id)sender
{
    if ((![tableView_fileList numberOfSelectedRows]) && ([records count] > 0))
        NSBeginAlertSheet(@"Confirm Removal", @"Removal All", @"Cancel", nil, window_main, self,
                          @selector(didEndRemoveAllSheet:returnCode:contextInfo:),
                          nil, nil, @"You sure you want to ditch all of the entries? They're so cute!");
    else
        [self removeSelectedRecords:nil];
}

- (void)didEndRemoveAllSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSOKButton) {
        [records removeAllObjects];
        [self updateUI];
    }
}

- (IBAction)saveClicked:(id)sender
{
    if (![records count])
        return;

    NSSavePanel *sPanel = [NSSavePanel savePanel];
    [sPanel setPrompt:@"Save"];
    [sPanel setTitle:@"Save"];
    sPanel.allowedFileTypes = @[@"sfv"];
    
    [sPanel beginSheetModalForWindow:window_main completionHandler:^(NSInteger result) {
        if (result == NSOKButton) {
            if ([records count]) {
                // shameless plug to start out with
                NSString *output = [NSString stringWithFormat:@"; Created using SuperSFV v%@ on Mac OS X", [self _applicationVersion]];
                
                for (SPFileEntry *entry in records) {
                    if ((![entry.result isEqualToString:@"Missing"])
                        && (![entry.result isEqualToString:@""])) {
                        
                        output = [output stringByAppendingFormat:@"\n%@ %@",
                                  [entry.filePath lastPathComponent],
                                  entry.result];
                    }
                }
                
                [output writeToURL:[sPanel URL] atomically:NO encoding:NSUTF8StringEncoding error:NULL];
            }
        }
    }];
}

- (IBAction)stopClicked:(id)sender
{
    [queue cancelAllOperations];
}

- (IBAction)showLicense:(id)sender
{
    NSString *licensePath = [[NSBundle mainBundle] pathForResource:@"License" ofType:@"txt"];
    [textView_license setString:[NSString stringWithContentsOfFile:licensePath usedEncoding:NULL error:NULL]];

    [NSApp beginSheet:panel_license
       modalForWindow:window_about
        modalDelegate:nil
       didEndSelector:nil
          contextInfo:nil];
}

- (IBAction)closeLicense:(id)sender
{
    [panel_license orderOut:nil];
    [NSApp endSheet:panel_license returnCode:0];
}

- (IBAction)aboutIconClicked:(id)sender
{

}

- (IBAction)showAbout:(id)sender
{
    // Credits
    NSAttributedString *creditsString;
    creditsString = [[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"] documentAttributes:nil];
    [[textView_credits textStorage] setAttributedString:creditsString];

    // Version
    [textField_version setStringValue:[self _applicationVersion]];

    // die you little blue bastard for attempting to thwart my easter egg
    [button_easterEgg setFocusRingType:NSFocusRingTypeNone];

    // Center n show eet
    [window_about center];
    [window_about makeKeyAndOrderFront:nil];
}

- (IBAction)contactClicked:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:reikonmusha@gmail.com"]];
}

#pragma mark KVO handling
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    /* if ([keyPath isEqual:@"operationCount"])
    {
        NSUInteger oldCount, newCount;

        oldCount = [[change objectForKey:NSKeyValueChangeOldKey] unsignedIntegerValue];
        newCount = [[change objectForKey:NSKeyValueChangeNewKey] unsignedIntegerValue];

        if (oldCount == 0 && newCount > 0)
        {
            NSNumber *newNumber;

            newNumber = [[NSNumber alloc] initWithUnsignedInteger:newCount];
            [newNumber retain];
            [self performSelectorOnMainThread:@selector(startProcessingQueue:) withObject:newNumber waitUntilDone:NO];
        }
        else if (oldCount > 0 && newCount == 0)
        {
            [self performSelectorOnMainThread:@selector(stopProcessingQueue) withObject:NULL waitUntilDone:NO];
        }
    }
     */
    // be sure to call the super implementation
    // if the superclass implements it
//    [super observeValueForKeyPath:keyPath
//                         ofObject:object
//                           change:change
//                          context:context];
}

#pragma mark Runloop
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    [self processFiles:@[filename]];
    return YES;
}

-(void)application:(NSApplication *)sender openFiles:(NSArray<NSString *> *)filenames
{
    [self processFiles:filenames];
}

// remove selected records from our table view
- (void)removeSelectedRecords:(id)ssender
{
	NSIndexSet *rows = [tableView_fileList selectedRowIndexes];

	NSUInteger current_index = [rows lastIndex];
    while (current_index != NSNotFound) {
        [records removeObjectAtIndex:current_index];
        current_index = [rows indexLessThanIndex:current_index];
    }

    [self updateUI];
}

- (void)startProcessingQueue
{
    [progressBar_progress setIndeterminate:YES];
    [progressBar_progress setHidden:NO];
    [progressBar_progress startAnimation:self];
    [button_stop setEnabled:YES];
    [popUpButton_checksum setEnabled:NO];
    [textField_status setHidden:NO];
}

- (void)stopProcessingQueue
{
    [progressBar_progress stopAnimation:self];
    [progressBar_progress setHidden:YES];
    [button_stop setEnabled:NO];
    [popUpButton_checksum setEnabled:YES];
    [textField_status setHidden:YES];
    [textField_status setStringValue:@""];
}

// Called periodically for updating the UI
- (void)updateProgress:(NSTimer *)timer
{
	if ([queue operationCount] == 0)
	{
		[timer invalidate];
        updateProgressTimer = nil;
        [self stopProcessingQueue];
    }

    [self updateUI];

    [textField_status setIntegerValue:[queue operationCount]];
}

// updates the general UI, i.e the toolbar items, and reloads the data for our tableview
- (void)updateUI
{
    [button_recalculate setEnabled:([records count] > 0)];
    [button_remove setEnabled:([records count] > 0)];
    [button_save setEnabled:([records count] > 0)];
    [textField_fileCount setIntegerValue:[records count]];

    // other 'stats' .. may be a bit sloppy
    int error_count = 0, failure_count = 0, verified_count = 0;

    NSEnumerator *e = [records objectEnumerator];
    SPFileEntry *entry;
    while (entry = [e nextObject]) {
        if ([entry.result isEqualToString:@"Missing"] ||
            [entry.expected isEqualToString:@"Unknown (not recognized)"]) {
                error_count++;
                continue;
        }

        if ([entry.expected compare:entry.result options:NSCaseInsensitiveSearch] != NSOrderedSame) {
            failure_count++;
            continue;
        }

        if ([entry.expected compare:entry.result options:NSCaseInsensitiveSearch] == NSOrderedSame) {
            verified_count++;
            continue;
        }
    }

    [textField_errorCount setIntValue:error_count];
    [textField_failedCount setIntValue:failure_count];
    [textField_verifiedCount setIntValue:verified_count];

    [tableView_fileList reloadData];
    [tableView_fileList scrollRowToVisible:([records count]-1)];
}

// process files dropped on the tableview, icon, or are manually opened
- (void)processFiles:(NSArray *) filenames
{
    BOOL isDir;
    NSFileManager *dm = [NSFileManager defaultManager];

    for (NSString *file in filenames) {
        if ([[[file lastPathComponent] substringWithRange:NSMakeRange(0, 1)] isEqualToString:@"."])
            continue;  // ignore hidden files
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"sfv"]) {
            if ([dm fileExistsAtPath:file isDirectory:&isDir] && !isDir) {
                [self parseSFVFile:file];
                continue;
            }
        } else {
            // recurse directories (I didn't feel like using NSDirectoryEnumerator)
            if ([dm fileExistsAtPath:file isDirectory:&isDir] && isDir) {
				NSError *err = nil;
                NSArray *dirContents = [dm contentsOfDirectoryAtPath:file error:&err];
                int i;
                for (i = 0; i < [dirContents count]; i++) {
                    [self processFiles:@[[file stringByAppendingPathComponent:dirContents[i]]]];
                }
                continue;
            }

            SPFileEntry *newEntry = [[SPFileEntry alloc] initWithPath:file];

            [self queueEntry:newEntry withAlgorithm:(SPCryptoAlgorithm)[popUpButton_checksum indexOfSelectedItem]];
        }
    }
}

- (void)queueEntry:(SPFileEntry *)entry withAlgorithm:(SPCryptoAlgorithm)algorithm
{
    SPIntegrityOperation *integrityOp;

    if (algorithm == SPCryptoAlgorithmUnknown)
    {
        integrityOp = [[SPIntegrityOperation alloc] initWithFileEntry:entry
                                                               target:self];
    }
    else
    {
        integrityOp = [[SPIntegrityOperation alloc] initWithFileEntry:entry
                                                               target:self
                                                            algorithm:algorithm];
    }
         
    [queue addOperation: integrityOp];

    NSString *fileName = entry.filePath;
    NSString *expectedHash = entry.expected;

    SPFileEntry *newEntry = [[SPFileEntry alloc] initWithPath:fileName expectedHash:expectedHash];

    /* TODO: Set image indicating "in progress" */
    newEntry.status = SPFileStatusChecking;
    
    [records addObject:newEntry];
    
    /* If this was the first operation added to the queue */
    if ([queue operationCount] == 1)
    {
        [self startProcessingQueue];
        updateProgressTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                target:self
                                                              selector:@selector(updateProgress:)
                                                              userInfo:nil
                                                               repeats:YES];
    }
}

- (void)parseSFVFile:(NSString *) filepath
{
    NSArray *contents = [[NSString stringWithContentsOfFile:filepath usedEncoding:NULL error:NULL] componentsSeparatedByString:@"\n"];
    
    for (__strong NSString *entry in contents) {
        int errc = 0; // error count
        NSString *newPath;
        NSString *hash;

        entry = [entry stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([entry isEqualToString:@""])
            continue;
        if ([[entry substringWithRange:NSMakeRange(0, 1)] isEqualToString:@";"])
            continue; // skip the line if it's a comment

        NSRange r = [entry rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" "] options:NSBackwardsSearch];
        newPath = [[filepath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[entry substringToIndex:r.location]];
        hash = [entry substringFromIndex:(r.location+1)]; // +1 so we don't capture the space

        SPFileEntry *newEntry = [[SPFileEntry alloc] initWithPath:newPath expectedHash:hash];

        // file doesn't exist...
        if (![[NSFileManager defaultManager] fileExistsAtPath:newPath]) {
            newEntry.status = SPFileStatusFileNotFound;
            newEntry.result = @"Missing";
            errc++;
        }

        // length doesn't match CRC32, MD5 or SHA-1 respectively
        if ([hash length] != 8 && [hash length] != 32 && [hash length] != 40) {
            newEntry.status = SPFileStatusUnknownChecksum;
            newEntry.expected = @"Unknown";
            errc++;
        }
        
        // if theres an error, then we don't need to continue with this entry
        if (errc) {
            [records addObject:newEntry];
            [self updateUI];
            continue;
        }
        // assume it'll fail until proven otherwise
        newEntry.status = SPFileStatusInvalid;

        [self queueEntry:newEntry withAlgorithm:SPCryptoAlgorithmUnknown];
    }
}

- (NSString *)_applicationVersion
{
    NSString *version = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
    return [NSString stringWithFormat:@"%@",(version ? version : @"")];
}

#pragma mark TableView
- (id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
    NSString *key = [column identifier];
    SPFileEntry *newEntry = records[row];
    if ([key isEqualToString:@"filepath"]) {
        return newEntry.filePath.lastPathComponent;
    } else if ([key isEqualToString:@"status"]) {
        return [SPFileEntry imageForStatus:newEntry.status];
    } else if ([key isEqualToString:@"expected"]) {
        if (newEntry.status == SPFileStatusUnknownChecksum) {
            return @"Unknown (not recognized)";
        }
        return newEntry.expected;
    } else if ([key isEqualToString:@"result"]) {
        if (newEntry.status == SPFileStatusFileNotFound) {
            return @"Missing";
        }
        return newEntry.result;
    }
    return @"";
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [records count];
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
    return NSDragOperationEvery;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard* pboard = [info draggingPasteboard];
    NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];

    [self processFiles:files];

    return YES;
}

- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	if (tableView==tableView_fileList) {
		NSArray *allColumns = [tableView_fileList tableColumns];
		NSInteger i;
		for (i = 0; i < [tableView_fileList numberOfColumns]; i++)
			if ([allColumns objectAtIndex:i] != tableColumn)
				[tableView_fileList setIndicatorImage:nil inTableColumn:[allColumns objectAtIndex:i]];

		[tableView_fileList setHighlightedTableColumn:tableColumn];

		if ([tableView_fileList indicatorImageInTableColumn:tableColumn] != [NSImage imageNamed:@"NSAscendingSortIndicator"]) {
			[tableView_fileList setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:tableColumn];
			[self sortWithDescriptor:[[NSSortDescriptor alloc] initWithKey:[tableColumn identifier] ascending:YES]];
		} else {
			[tableView_fileList setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:tableColumn];
			[self sortWithDescriptor:[[NSSortDescriptor alloc] initWithKey:[tableColumn identifier] ascending:NO]];
		}
	}
}

- (void)sortWithDescriptor:(NSSortDescriptor*)descriptor
{
	NSMutableArray *sorted = [records mutableCopy];
    [sorted sortUsingDescriptors:@[descriptor]];
	[records removeAllObjects];
	[records addObjectsFromArray:sorted];
	[self updateUI];
}


#pragma mark Toolbar
- (void)setup_toolbar
{
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier: SuperSFVToolbarIdentifier];

    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
    //toolbar.sizeMode = NSToolbarSizeModeSmall;

    [toolbar setDelegate: self];
    [window_main setToolbar: toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL)flag
{

    NSToolbarItem *toolbarItem = nil;

    if ([itemIdent isEqual: AddToolbarIdentifier]) {
        
        toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdent];

        [toolbarItem setLabel: @"Add"];
        [toolbarItem setPaletteLabel: @"Add"];
        [toolbarItem setToolTip: @"Add a file or the contents of a folder"];
        [toolbarItem setImage: [NSImage imageNamed: NSImageNameAddTemplate]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(addClicked:)];
        [toolbarItem setAutovalidates: NO];

    } else if ([itemIdent isEqual: RemoveToolbarIdentifier]) {
        
        toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdent];
        
        [toolbarItem setLabel: @"Remove"];
        [toolbarItem setPaletteLabel: @"Remove"];
        [toolbarItem setToolTip: @"Remove selected items or prompt to remove all items if none are selected"];
        [toolbarItem setImage: [NSImage imageNamed: NSImageNameRemoveTemplate]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(removeClicked:)];
        [toolbarItem setAutovalidates: NO];

    } else if ([itemIdent isEqual: RecalculateToolbarIdentifier]) {
        
        toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdent];

        [toolbarItem setLabel: @"Recalculate"];
        [toolbarItem setPaletteLabel: @"Recalculate"];
        [toolbarItem setToolTip: @"Recalculate checksums"];
        [toolbarItem setImage: [NSImage imageNamed: NSImageNameRefreshTemplate]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(recalculateClicked:)];
        [toolbarItem setAutovalidates: NO];

    } else if ([itemIdent isEqual: StopToolbarIdentifier]) {
        
        toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdent];
        
        [toolbarItem setLabel: @"Stop"];
        [toolbarItem setPaletteLabel: @"Stop"];
        [toolbarItem setToolTip: @"Stop calculating checksums"];
        [toolbarItem setImage: [NSImage imageNamed: NSImageNameStopProgressTemplate]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(stopClicked:)];
        [toolbarItem setAutovalidates: NO];

    } else if ([itemIdent isEqual: SaveToolbarIdentifier]) {
        
        toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdent];

        [toolbarItem setLabel: @"Save"];
        [toolbarItem setPaletteLabel: @"Save"];
        [toolbarItem setToolTip: @"Save current state"];
        [toolbarItem setImage: [NSImage imageNamed: @"1downarrow"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(saveClicked:)];
        [toolbarItem setAutovalidates: NO];

    } else if ([itemIdent isEqual: ChecksumToolbarIdentifier]) {
        
        toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdent];

        [toolbarItem setLabel: @"Checksum"];
        [toolbarItem setPaletteLabel: @"Checksum"];
        [toolbarItem setToolTip: @"Checksum algorithm to use"];
        [toolbarItem setView: view_checksum];
        [toolbarItem setMinSize:NSMakeSize(106, NSHeight([view_checksum frame]))];
        [toolbarItem setMaxSize:NSMakeSize(106, NSHeight([view_checksum frame]))];

	} else {
        toolbarItem = nil;
    }
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar {
    return @[AddToolbarIdentifier, RemoveToolbarIdentifier, 
                            RecalculateToolbarIdentifier, NSToolbarSeparatorItemIdentifier, 
                            ChecksumToolbarIdentifier, NSToolbarFlexibleSpaceItemIdentifier, 
                            SaveToolbarIdentifier, StopToolbarIdentifier];
    
}


- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
    return @[AddToolbarIdentifier, RecalculateToolbarIdentifier, 
                            StopToolbarIdentifier, SaveToolbarIdentifier, ChecksumToolbarIdentifier, 
                            NSToolbarPrintItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, 
                            NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, 
                            NSToolbarSeparatorItemIdentifier, RemoveToolbarIdentifier];
}

@end
