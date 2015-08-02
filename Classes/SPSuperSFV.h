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

#import <Cocoa/Cocoa.h>
#import "SPTableView.h"

@interface SPSuperSFV : NSObject <NSApplicationDelegate, NSToolbarDelegate, NSTableViewDataSource, NSTableViewDelegate>
{
    IBOutlet NSButton *button_add;
    IBOutlet NSButton *button_closeLicense;
    IBOutlet NSButton *button_contact;
    IBOutlet NSButton *button_easterEgg;
    IBOutlet NSButton *button_recalculate;
    IBOutlet NSButton *button_remove;
    IBOutlet NSButton *button_save;
    IBOutlet NSButton *button_showLicense;
    IBOutlet NSButton *button_stop;
    IBOutlet NSPanel *panel_license;
    IBOutlet NSPopUpButton *popUpButton_checksum;
    IBOutlet NSProgressIndicator *progressBar_progress;
    IBOutlet NSTextField *textField_errorCount;
    IBOutlet NSTextField *textField_failedCount;
    IBOutlet NSTextField *textField_fileCount;
    IBOutlet NSTextField *textField_status;
    IBOutlet NSTextField *textField_verifiedCount;
    IBOutlet NSTextField *textField_version;
    IBOutlet NSTextView *textView_credits;
    IBOutlet NSTextView *textView_license;
    IBOutlet NSView *view_checksum;
    IBOutlet NSWindow *window_about;
    IBOutlet NSWindow *window_main;

    NSMutableArray *records;
    NSImageCell *cell;
    NSOperationQueue *queue;
    NSTimer *updateProgressTimer;
}

@property (weak) IBOutlet SPTableView *tableView_fileList;
- (IBAction)aboutIconClicked:(id)sender;
- (IBAction)addClicked:(id)sender;
- (IBAction)closeLicense:(id)sender;
- (IBAction)contactClicked:(id)sender;
- (IBAction)recalculateClicked:(id)sender;
- (IBAction)removeClicked:(id)sender;
- (IBAction)saveClicked:(id)sender;
- (IBAction)showAbout:(id)sender;
- (IBAction)showLicense:(id)sender;
- (IBAction)stopClicked:(id)sender;

- (void)parseSFVFile:(NSString *) filepath;
- (void)processFiles:(NSArray<NSString*> *) filenames;
- (IBAction)removeSelectedRecords:(id) sender;
@property (readonly, copy) NSString *_applicationVersion;

- (void)sortWithDescriptor:(NSSortDescriptor*)descriptor;

- (void)setup_toolbar;

@end
