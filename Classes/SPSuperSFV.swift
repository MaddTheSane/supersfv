//
//  SPSuperSFV.swift
//  SuperSFV
//
//  Created by C.W. Betts on 8/2/15.
//
//

import Cocoa

private let SuperSFVToolbarIdentifier		= "SuperSFV Toolbar Identifier"
private let AddToolbarIdentifier			= "Add Toolbar Identifier"
private let RemoveToolbarIdentifier			= "Remove Toolbar Identifier"
private let RecalculateToolbarIdentifier	= "Recalculate Toolbar Identifier"
private let ChecksumToolbarIdentifier		= "Checksum Toolbar Identifier"
private let StopToolbarIdentifier			= "Stop Toolbar Identifier"
private let SaveToolbarIdentifier			= "Save Toolbar Identifier"


class SSuperSFV : NSObject, NSApplicationDelegate, NSToolbarDelegate, NSTableViewDataSource, NSTableViewDelegate {
	@IBOutlet weak var windowMain: NSWindow!

	
	
	private let queue = NSOperationQueue()
	private var records = [FileEntry]()
	
	func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool {
		return true
	}
	
	// MARK: private methods
	private func queueEntry(entry: FileEntry, algorithm: SPCryptoAlgorithm) {
		
	}
	
	private func updateUI() {
		
	}
	
	private func startProcessingQueue() {
		
	}
	
	private func stopProcessingQueue() {
		
	}
	
	// MARK: Toolbar
	func setupToolbar() {
		let toolbar = NSToolbar(identifier: SuperSFVToolbarIdentifier)
		toolbar.allowsUserCustomization = true
		toolbar.autosavesConfiguration = true
		toolbar.displayMode = .IconOnly
		//toolbar.sizeMode = NSToolbarSizeModeSmall;

		toolbar.delegate = self
		windowMain.toolbar = toolbar
		
	}
/*

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL)flag
	{
	
	NSToolbarItem *toolbarItem;
	
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

*/
	
	func toolbar(toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: String, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		var toolbarItem: NSToolbarItem? = nil
		switch itemIdentifier {
		case AddToolbarIdentifier:
			toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem!.label = "Add"
			toolbarItem!.paletteLabel = "Add"
			toolbarItem!.toolTip = "Add a file or the contents of a folder"
			toolbarItem!.image = NSImage(named: "edit_add")
			toolbarItem!.target = self
			toolbarItem!.action = "addClicked:"
			toolbarItem!.autovalidates = false

		default:
			break
		}
		
		
		return toolbarItem
	}
	
	func toolbarDefaultItemIdentifiers(toolbar: NSToolbar) -> [String] {
		return [AddToolbarIdentifier, RemoveToolbarIdentifier,
		RecalculateToolbarIdentifier, NSToolbarSeparatorItemIdentifier,
		ChecksumToolbarIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		SaveToolbarIdentifier, StopToolbarIdentifier]
	}
	
	func toolbarAllowedItemIdentifiers(toolbar: NSToolbar) -> [String] {
		return [AddToolbarIdentifier, RecalculateToolbarIdentifier,
		StopToolbarIdentifier, SaveToolbarIdentifier, ChecksumToolbarIdentifier,
		NSToolbarPrintItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier,
		NSToolbarSeparatorItemIdentifier, RemoveToolbarIdentifier]
	}
}
