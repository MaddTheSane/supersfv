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

#include <openssl/md5.h>
#include <openssl/sha.h>
#include "crc32.h"

#define SuperSFVToolbarIdentifier    @"SuperSFV Toolbar Identifier"
#define AddToolbarIdentifier         @"Add Toolbar Identifier"
#define RemoveToolbarIdentifier      @"Remove Toolbar Identifier"
#define RecalculateToolbarIdentifier @"Recalculate Toolbar Identifier"
#define ChecksumToolbarIdentifier    @"Checksum Toolbar Identifier"
#define StopToolbarIdentifier        @"Stop Toolbar Identifier"
#define SaveToolbarIdentifier        @"Save Toolbar Identifier"

static inline void RunOnMainThreadSync(dispatch_block_t theBlock)
{
    if ([NSThread isMainThread]) {
        theBlock();
    } else {
        dispatch_sync(dispatch_get_main_queue(), theBlock);
    }
}

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
    pendingFiles = [[AIQueue alloc] init];
    [NSThread detachNewThreadSelector:@selector(fileAddingThread) toTarget:self withObject:nil];
    
    continueProcessing = YES;
    
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
	pendingFiles = nil;
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
    [oPanel beginSheetForDirectory:NSHomeDirectory()
                              file:nil
                    modalForWindow:window_main
                     modalDelegate:self
                    didEndSelector:@selector(didEndOpenSheet:returnCode:contextInfo:)
                       contextInfo:NULL];
}

- (void)didEndOpenSheet:(NSOpenPanel *)openPanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSOKButton)
        [self processFiles:[openPanel filenames]];
}

// Hmm... Is this OK?
- (IBAction)recalculateClicked:(id)sender
{
    NSMutableArray *t = [[NSMutableArray alloc] initWithCapacity:1];
	[t addObjectsFromArray:records];
	[records removeAllObjects];
    for (id i in t)
        [self processFiles:@[[i properties][@"filepath"]]];
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
    [sPanel setRequiredFileType:@"sfv"];
    
    [sPanel beginSheetForDirectory:NSHomeDirectory()
                              file:nil
                    modalForWindow:window_main
                     modalDelegate:self
                    didEndSelector:@selector(didEndSaveSheet:returnCode:contextInfo:)
                       contextInfo:NULL];
}

- (void)didEndSaveSheet:(NSSavePanel *)savePanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSOKButton) {
        if ([records count]) {
            // shameless plug to start out with
            NSString *output = [NSString stringWithFormat:@"; Created using SuperSFV v%@ on Mac OS X", [self _applicationVersion]];
            
            NSEnumerator *e = [records objectEnumerator];
            SPFileEntry *entry;
            while (entry = [e nextObject]) {
                if ((![[entry properties][@"result"] isEqualToString:@"Missing"])
                    && (![[entry properties][@"result"] isEqualToString:@""])) {

                    output = [output stringByAppendingFormat:@"\n%@ %@", 
                                [[entry properties][@"filepath"] lastPathComponent],
                                [entry properties][@"result"]];
                }
            }
            
            [output writeToFile:[savePanel filename] atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        }
    }
}

- (IBAction)stopClicked:(id)sender
{
    continueProcessing = NO;
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

#pragma mark Runloop
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    [self processFiles:@[filename]];
    return YES;
}

// this probably needs to be rewritten to be more efficient, and clean
- (void)addFiles:(NSTimer *)timer
{
	@autoreleasepool {
		SPFileEntry *content;
    int do_endProgress = 0; // we use this to make sure we only call endProgress when needed
    
		while ((content = [pendingFiles dequeue])) {
        if (!continueProcessing)
            break;
        
        [popUpButton_checksum setEnabled:NO]; // so they can't screw with it
        
        int bytes, algorithm;
        u8 data[1024], *dgst; // buffers
        
        NSString *file = [content properties][@"filepath"],
                 *hash = [content properties][@"expected"],
                 *result;
        
        NSFileManager *dm = [NSFileManager defaultManager];
        NSDictionary *fileAttributes = [dm attributesOfItemAtPath:file error:NULL];
        

        algorithm = (![hash isEqualToString:@""]) ? ([hash length] == 8) ? 0 : ([hash length] == 32) ? 1 : ([hash length] == 40) ? 2 : 0 : [popUpButton_checksum indexOfSelectedItem];
       
        FILE *inFile = fopen([file cStringUsingEncoding:NSUTF8StringEncoding], "rb");
        
        if (inFile == NULL)
            break;
        
            RunOnMainThreadSync(^{
                textField_status.stringValue = [NSString stringWithFormat:@"Performing %@ on %@", [popUpButton_checksum itemTitleAtIndex:algorithm],
                                                [file lastPathComponent]];
                progressBar_progress.minValue = 0;
                progressBar_progress.maxValue = [fileAttributes[NSFileSize] unsignedLongLongValue];
                [progressBar_progress setDoubleValue:0.0];
                
                if (progressBar_progress.isHidden)
                    progressBar_progress.hidden = NO;
                
                if (textField_status.isHidden)
                    textField_status.hidden = NO;
                
                if (!button_stop.isEnabled)
                    button_stop.enabled = YES;
            });
        
        do_endProgress++; // don't care about doing endProgress unless the progress has been init-ed
        
        crc32_t crc;
        MD5_CTX md5_ctx;
        SHA_CTX sha_ctx;
        
        if (!algorithm) {
            crc = crc32(0L,Z_NULL,0);
        } else if (algorithm == 1) {
            MD5_Init(&md5_ctx);
        } else { // algorithm == 2
            SHA1_Init(&sha_ctx);
        }
        
        while ((bytes = fread (data, 1, 1024, inFile)) != 0) {
            if (!continueProcessing)
                break;
            
            switch (algorithm) {
                case 0:
                    crc = crc32(crc, data, bytes);
                    break;
                case 1:
                    MD5_Update(&md5_ctx, data, bytes);
                    break;
                case 2:
                    SHA1_Update(&sha_ctx, data, bytes);
                    break;
            }
            RunOnMainThreadSync(^{
                [self updateProgress:@[@([progressBar_progress doubleValue]+(double)bytes), @""]];
            });
        }
        
        fclose(inFile);
        
        if (!continueProcessing)
            break;

        if (!algorithm) {
                result = [[NSString stringWithFormat:@"%08x", crc] uppercaseString];
        } else {
            result = @"";
                dgst = (u8 *) calloc (((algorithm == 1)?32:40), sizeof(u8));
                
                if (algorithm == 1)
                    MD5_Final(dgst,&md5_ctx);
                else if (algorithm == 2)
                    SHA1_Final(dgst,&sha_ctx);
                
                int i;
                for (i = 0; i < ((algorithm == 1)?16:20); i++)
                    result = [[result stringByAppendingFormat:@"%02x", dgst[i]] uppercaseString];
                
                free(dgst);
        }
        
        SPFileEntry *newEntry = [[SPFileEntry alloc] init];
        
        if (![hash isEqualToString:@""])
            [newEntry setProperties:[[NSMutableDictionary alloc] 
                        initWithObjects:@[[[hash uppercaseString] isEqualToString:result]?[NSImage imageNamed:@"button_ok"]:[NSImage imageNamed:@"button_cancel"],
                            file, [hash uppercaseString], result] 
                                forKeys:[newEntry defaultKeys]]];
        else
            [newEntry setProperties:[[NSMutableDictionary alloc] 
                        initWithObjects:@[[NSImage imageNamed:@"button_ok"],
                            file, result, result]
                                forKeys:[newEntry defaultKeys]]];
        
        [records addObject:newEntry];
            RunOnMainThreadSync(^{
                [self updateUI];
            });
		}
    // 4 times I had to add this LAME! C'mon Apple, get yer thread on!
    if (!continueProcessing) {
        [pendingFiles dump];
        RunOnMainThreadSync(^{
            [self updateUI];
        });
        continueProcessing = YES;
    }
    
    if (do_endProgress) {
        RunOnMainThreadSync(^{
            [self endProgress];
        });
    }
    
    }
}

// adds files to the tableview, which means it also starts hashing them and all the other fun stuff
- (void)fileAddingThread
{
	NSTimer *fileAddingTimer;
	
	@autoreleasepool {
		fileAddingTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                           target:self
                                                         selector:@selector(addFiles:)
                                                         userInfo:nil
                                                          repeats:YES];
		
		CFRunLoopRun();
		
		[fileAddingTimer invalidate]; 
	}
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

// updates the general UI, i.e the toolbar items, and reloads the data for our tableview
- (void)updateUI
{
    [button_recalculate setEnabled:([records count] > 0)];
    [button_remove setEnabled:([records count] > 0)];
    [button_save setEnabled:([records count] > 0)];
    [textField_fileCount setIntValue:[records count]];
    
    // other 'stats' .. may be a bit sloppy
    int error_count = 0, failure_count = 0, verified_count = 0;
    
    NSEnumerator *e = [records objectEnumerator];
    SPFileEntry *entry;
    while (entry = [e nextObject]) {
        if ([[entry properties][@"result"] isEqualToString:@"Missing"] ||
            [[entry properties][@"expected"] isEqualToString:@"Unknown (not recognized)"]) {
                error_count++;
                continue;
        }
        
        if (![[entry properties][@"expected"] isEqualToString:[entry properties][@"result"]]) {
            failure_count++;
            continue;
        }
        
        if ([[entry properties][@"expected"] isEqualToString:[entry properties][@"result"]]) {
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
        SPFileEntry *newEntry = [[SPFileEntry alloc] init];
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
            [newEntry setProperties:[[NSMutableDictionary alloc] 
                        initWithObjects:@[[NSImage imageNamed: @"button_cancel.png"], file, @"", @""] 
                                forKeys:[newEntry defaultKeys]]];
            
            [pendingFiles enqueue:newEntry];
        }
    }
}

- (void)parseSFVFile:(NSString *) filepath
{
    NSArray *contents = [[NSString stringWithContentsOfFile:filepath usedEncoding:NULL error:NULL] componentsSeparatedByString:@"\n"];
    
    for (__strong NSString *entry in contents) {
        int errc = 0; // error count
        NSString *newPath = nil;
        NSString *hash = nil;
        SPFileEntry *newEntry = [[SPFileEntry alloc] init];
        
        entry = [entry stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([entry isEqualToString:@""])
            continue;
        if ([[entry substringWithRange:NSMakeRange(0, 1)] isEqualToString:@";"])
            continue; // skip the line if it's a comment
        
        NSRange r = [entry rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" "] options:NSBackwardsSearch];
        newPath = [[filepath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[entry substringToIndex:r.location]];
        hash = [entry substringFromIndex:(r.location+1)]; // +1 so we don't capture the space
         
        // file doesn't exist...
        if (![[NSFileManager defaultManager] fileExistsAtPath:newPath]) {
            [newEntry setProperties:[[NSMutableDictionary alloc] 
                        initWithObjects:@[[NSImage imageNamed: @"error.png"], newPath, hash, @"Missing"] 
                                forKeys:[newEntry defaultKeys]]];
            errc++;
        }
        
        // length doesn't match CRC32, MD5 or SHA-1 respectively
        if ([hash length] != 8 && [hash length] != 32 && [hash length] != 40) {
            [newEntry setProperties:[[NSMutableDictionary alloc] 
                        initWithObjects:@[[NSImage imageNamed: @"error.png"],newPath, 
                                            @"Unknown (not recognized)",[newEntry properties][@"result"]] 
                                forKeys:[newEntry defaultKeys]]];
            errc++;
        }
        
        // if theres an error, then we don't need to continue with this entry
        if (errc) {
            [records addObject:newEntry];
            [self updateUI];
            continue;
        }
        // assume it'll fail until proven otherwise
        [newEntry setProperties:[NSMutableDictionary dictionaryWithObjects:@[[NSImage imageNamed: @"button_cancel.png"], newPath, hash, @""] 
                                forKeys:[newEntry defaultKeys]]];
        
        [pendingFiles enqueue:newEntry];
    }
}

// expects an NSArray containing:
// (NSNumber *)currentProgress, (NSString *)description
- (void)updateProgress:(NSArray *)args
{
    if (![args[1] isEqualToString:@""])
        [textField_status setStringValue:args[1]];
    [progressBar_progress setDoubleValue:[args[0] doubleValue]];
}

// expects an NSArray containing:
// (NSString *)description, (NSNumber *)minValue, (NSNumber *)maxValue
- (void)initProgress:(NSArray *)args
{
    if (![args[0] isEqualToString:@""])
        [textField_status setStringValue:args[0]];
    [progressBar_progress setMinValue:[args[1] doubleValue]];
    [progressBar_progress setMaxValue:[args[2] doubleValue]];
    [progressBar_progress setDoubleValue:0.0];

    if ([progressBar_progress isHidden])
        [progressBar_progress setHidden:NO];
    
    if ([textField_status isHidden])
        [textField_status setHidden:NO];
    
    if (![button_stop isEnabled])
        [button_stop setEnabled:YES];
}

// resets the progress bar and it's progress text to it's initial state
- (void)endProgress
{
    [textField_status setStringValue:@""];
    [textField_status setHidden:YES];
    
    [progressBar_progress setHidden:YES];
    [progressBar_progress setMinValue:0.0];
    [progressBar_progress setMaxValue:0.0];
    [progressBar_progress setDoubleValue:0.0];
    
    [button_stop setEnabled:NO];
    [popUpButton_checksum setEnabled:YES];
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
    if ([key isEqualToString:@"filepath"])
        return [[newEntry properties][@"filepath"] lastPathComponent];
    return [newEntry properties][key];
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
		int i;
		for (i = 0; i < [tableView_fileList numberOfColumns]; i++)
			if (allColumns[i] != tableColumn)
				[tableView_fileList setIndicatorImage:nil inTableColumn:allColumns[i]];
            
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
	NSMutableArray *sorted = [[NSMutableArray alloc] initWithCapacity:1];
	[sorted addObjectsFromArray:[records sortedArrayUsingDescriptors:@[descriptor]]];
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
        [toolbarItem setImage: [NSImage imageNamed: @"edit_add"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(addClicked:)];
        [toolbarItem setAutovalidates: NO];
        
    } else if ([itemIdent isEqual: RemoveToolbarIdentifier]) {
        
        toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdent];
        
        [toolbarItem setLabel: @"Remove"];
        [toolbarItem setPaletteLabel: @"Remove"];
        [toolbarItem setToolTip: @"Remove selected items or prompt to remove all items if none are selected"];
        [toolbarItem setImage: [NSImage imageNamed: @"edit_remove"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(removeClicked:)];
        [toolbarItem setAutovalidates: NO];
        
    } else if ([itemIdent isEqual: RecalculateToolbarIdentifier]) {
        
        toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdent];

        [toolbarItem setLabel: @"Recalculate"];
        [toolbarItem setPaletteLabel: @"Recalculate"];
        [toolbarItem setToolTip: @"Recalculate checksums"];
        [toolbarItem setImage: [NSImage imageNamed: @"reload"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(recalculateClicked:)];
        [toolbarItem setAutovalidates: NO];
        
    } else if ([itemIdent isEqual: StopToolbarIdentifier]) {
        
        toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdent];
        
        [toolbarItem setLabel: @"Stop"];
        [toolbarItem setPaletteLabel: @"Stop"];
        [toolbarItem setToolTip: @"Stop calculating checksums"];
        [toolbarItem setImage: [NSImage imageNamed: @"stop"]];
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
