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

private var applicationVersion: String {
	let version = NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as? String
	return version ?? ""
}

class SSuperSFV : NSObject, NSApplicationDelegate, NSToolbarDelegate, NSTableViewDataSource, NSTableViewDelegate {
	@IBOutlet weak var buttonAdd: NSButton?
	@IBOutlet weak var buttonCloseLicense: NSButton!
	@IBOutlet weak var button_contact: NSButton?
	@IBOutlet weak var button_easterEgg: NSButton!
	@IBOutlet weak var button_recalculate: NSButton?
	@IBOutlet weak var button_remove: NSButton?
	@IBOutlet weak var button_save: NSButton?
	@IBOutlet weak var button_showLicense: NSButton!
	@IBOutlet weak var button_stop: NSButton?
	@IBOutlet weak var panel_license: NSPanel!
	@IBOutlet weak var popUpButton_checksum: NSPopUpButton!
	@IBOutlet weak var progressBar_progress: NSProgressIndicator!
	@IBOutlet weak var textField_errorCount: NSTextField!
	@IBOutlet weak var textField_failedCount: NSTextField!
	@IBOutlet weak var textField_fileCount: NSTextField!
	@IBOutlet weak var textField_status: NSTextField!
	@IBOutlet weak var textField_verifiedCount: NSTextField!
	@IBOutlet weak var textField_version: NSTextField!
	@IBOutlet weak var scrollViewCredits: NSScrollView!
	@IBOutlet weak var scrollViewLicense: NSScrollView!
	@IBOutlet weak var viewChecksum: NSView!
	@IBOutlet weak var windowAbout: NSWindow!
	@IBOutlet weak var windowMain: NSWindow!
	
	@IBOutlet weak var tableViewFileList: NSTableView!
	
	var textViewCredits: NSTextView {
		return scrollViewCredits.contentView.documentView as! NSTextView
	}
	var textViewLicense: NSTextView {
		return scrollViewLicense.contentView.documentView as! NSTextView
	}
	
	private let queue = NSOperationQueue()
	private var records = [FileEntry]()
	private var updateProgressTimer: NSTimer?
	
	override class func initialize() {
		var dictionary = [String: AnyObject]()
		dictionary["checksum_algorithm"] = "CRC32"; // default for most SFV programs
		NSUserDefaultsController.sharedUserDefaultsController().initialValues = dictionary
	}
	
	func applicationWillFinishLaunching(notification: NSNotification) {
		setupToolbar()
		
		// selecting items in our table view and pressing the delete key
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "removeSelectedRecords:", name: "RM_RECORD_FROM_LIST", object: nil)
		
		// register for drag and drop on the table view
		tableViewFileList.registerForDraggedTypes([NSFilenamesPboardType])
		
		// make the window pertee and show it
		button_stop?.enabled = false
		updateUI()
		
		windowMain.center()
		windowMain.makeKeyAndOrderFront(nil)
	}
	
	func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool {
		return true
	}
	
	func application(sender: NSApplication, openFile filename: String) -> Bool {
		processFiles([filename])
		return true
	}
	
	func application(sender: NSApplication, openFiles filenames: [String]) {
		processFiles(filenames)
	}
	
	/// remove selected records from our table view
	@objc private func removeSelectedRecords(sender: AnyObject?) {
		let rows = tableViewFileList.selectedRowIndexes
		
		var current_index = rows.lastIndex
		while current_index != NSNotFound {
			records.removeAtIndex(current_index)
			current_index = rows.indexLessThanIndex(current_index)
		}
		
		updateUI()
	}
	
	// MARK: IBActions
	@IBAction func addClicked(sender: AnyObject) {
		let oPanel = NSOpenPanel()
		oPanel.prompt = "Add"
		oPanel.title = "Add files or folder contents"
		oPanel.allowsMultipleSelection = true
		oPanel.canChooseFiles = true
		oPanel.canChooseDirectories = true
		oPanel.beginSheetModalForWindow(windowMain) { (result) -> Void in
			if result == NSModalResponseOK {
				let urls = oPanel.URLs
				self.processFiles(urls.map({ (aURL) -> String in
					return aURL.path!
				}))
			}
		}
	}
	
	@IBAction func recalculateClicked(sender: AnyObject?) {
		let t = records
		records.removeAll(keepCapacity: true)
		processFiles(t.map({ return $0.filePath }))
		updateUI()
	}
	
	@IBAction func removeClicked(sender: AnyObject?) {
		if tableViewFileList.numberOfSelectedRows == 0 && records.count > 0 {
			let alert = NSAlert()
			alert.messageText = "Confirm Removal"
			alert.informativeText = "You sure you want to ditch all of the entries? They're so cute!"
			alert.addButtonWithTitle("Removal All")
			alert.addButtonWithTitle("Cancel")
			
			alert.beginSheetModalForWindow(windowMain, completionHandler: { (returnCode) -> Void in
				if returnCode == NSAlertFirstButtonReturn {
					self.records.removeAll(keepCapacity: false)
					self.updateUI()
				}
			})
		} else {
			removeSelectedRecords(nil)
		}
	}
	
	@IBAction func saveClicked(sender: AnyObject?) {
		if records.count == 0 {
			NSBeep()
			return
		}
		
		let sPanel = NSSavePanel()
		sPanel.prompt = "Save"
		sPanel.title = "Save"
		sPanel.allowedFileTypes = ["sfv"]

		sPanel.beginSheetModalForWindow(windowMain) { (result) -> Void in
			if result == NSModalResponseOK {
				// shameless plug to start out with
				var output = "; Created using SuperSFV v\(applicationVersion) on Mac OS X\n"

				for entry in self.records {
					switch entry.status {
					case .Valid, .Invalid:
						output += "\(entry.filePath.lastPathComponent) \(entry.result)\n"
					default:
						continue
					}
				}
				
				do {
					try (output as NSString).writeToURL(sPanel.URL!, atomically: false, encoding: NSUTF8StringEncoding)
				} catch _ {
					
				}
			}
		}
	}
	
	@IBAction func stopClicked(sender: AnyObject?) {
		queue.cancelAllOperations()
	}
	
	@IBAction func showLicense(sender: AnyObject?) {
		if let licenseURL = NSBundle.mainBundle().URLForResource("License", withExtension: "txt") {
			textViewLicense.string = (try! NSString(contentsOfURL: licenseURL, usedEncoding: nil)) as String
		} else {
			//rtf support in the future?
			textViewLicense.string = "License file not found!"
		}
		
		NSApp.beginSheet(panel_license, modalForWindow: windowAbout, modalDelegate: nil, didEndSelector: nil, contextInfo: nil)
	}
	
	@IBAction func closeLicense(sender: AnyObject?) {
		panel_license.orderOut(sender)
		NSApp.endSheet(panel_license, returnCode: 0)
	}
	
	@IBAction func aboutIconClicked(sender: AnyObject?) {
		
	}
	
	@IBAction func showAbout(sender: AnyObject?) {
		// Credits
		var creditsURL = NSBundle.mainBundle().URLForResource("Credits", withExtension: "rtf")
		if creditsURL == nil {
			// just in case we add images later on.
			creditsURL = NSBundle.mainBundle().URLForResource("Credits", withExtension: "rtfd")
		}
		let creditsString = NSAttributedString(URL: creditsURL!, documentAttributes: nil)!
		textViewCredits.textStorage?.setAttributedString(creditsString)
		
		// Version
		textField_version.stringValue = applicationVersion
		
		// die you little blue bastard for attempting to thwart my easter egg
		button_easterEgg.focusRingType = .None
		
		// Center n show eet
		windowAbout.center()
		windowAbout.makeKeyAndOrderFront(nil)
	}
	
	@IBAction func contactClicked(sender: AnyObject?) {
		NSWorkspace.sharedWorkspace().openURL(NSURL(string: "mailto:reikonmusha@gmail.com")!)
	}
	
	func parseSFVFile(filePath: String) {
		let contents = (try! NSString(contentsOfFile: filePath, usedEncoding: nil)).componentsSeparatedByString("\n")
		for entry1 in contents {
			var errc = 0 //error count
			var newPath = ""
			var hash = ""

			let entry = entry1.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
			if entry == "" {
				continue
			}
			if entry.characters[entry.characters.startIndex] == ";" {
				continue; // skip the line if it's a comment
			}
			guard let r = entry.rangeOfCharacterFromSet(NSCharacterSet(charactersInString: " "), options: .BackwardsSearch) else {
				continue
			}
			newPath = filePath.stringByDeletingLastPathComponent.stringByAppendingPathComponent(entry[entry.startIndex..<r.startIndex])
			hash = entry[r.endIndex.successor() ..< entry.endIndex]
			
			let newEntry = FileEntry(path: newPath, expectedHash: hash)
			
			// file doesn't exist...
			if !NSFileManager.defaultManager().fileExistsAtPath(newPath) {
				newEntry.status = .FileNotFound
				newEntry.result = "Missing"
				errc++
			}
			
			// length doesn't match CRC32, MD5 or SHA-1 respectively
			if hash.characters.count != 8 && hash.characters.count != 32 && hash.characters.count != 40 {
				newEntry.status = .UnknownChecksum;
				newEntry.expected = "Unknown";
				errc++;
			}
			
			// if theres an error, then we don't need to continue with this entry
			if errc != 0 {
				records.append(newEntry)
				updateUI()
				continue;
			}
			// assume it'll fail until proven otherwise
			newEntry.status = .Invalid;
			
			queueEntry(newEntry)
		}
	}
	
	/// process files dropped on the tableview, icon, or are manually opened
	func processFiles(fileNames: [String]) {
		let fm = NSFileManager()
		var isDir: ObjCBool = false

		for file in fileNames {
			if file.lastPathComponent.characters[file.lastPathComponent.characters.startIndex] == "." {
				continue // ignore hidden files
			}
			
			if file.pathExtension.lowercaseString == "sfv" {
				if fm.fileExistsAtPath(file, isDirectory: &isDir) && !isDir {
					parseSFVFile(file)
					continue
				}
			} else {
				// recurse directories (I didn't feel like using NSDirectoryEnumerator)
				if fm.fileExistsAtPath(file, isDirectory: &isDir) && isDir {
					do {
						let dirContents = try fm.contentsOfDirectoryAtPath(file)
						processFiles(dirContents.map({ return file.stringByAppendingPathComponent($0) }))
					} catch _ {
						
					}
					continue
				}
				
				let newEntry = FileEntry(path: file)
				queueEntry(newEntry, algorithm: SPCryptoAlgorithm(rawValue: Int32(popUpButton_checksum.indexOfSelectedItem)) ?? .CRC)
			}
		}
	}
	
	// MARK: private methods
	private func queueEntry(entry: FileEntry, algorithm: SPCryptoAlgorithm = .Unknown) {
		let integrityOp: SPIntegrityOperation
		
		if (algorithm == .Unknown) {
			integrityOp = SPIntegrityOperation(fileEntry: entry, target: self)
		} else {
			integrityOp = SPIntegrityOperation(fileEntry: entry, target: self, algorithm: algorithm);
		}
		queue.addOperation(integrityOp)
		
		/* TODO: Set image indicating "in progress" */
		entry.status = .Checking;
		
		records.append(entry)
		
		/* If this was the first operation added to the queue */
		if (queue.operationCount == 1) {
			startProcessingQueue()
			updateProgressTimer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: "updateProgress:", userInfo: nil, repeats: true)
		}
	}
	
	/// updates the general UI, i.e the toolbar items, and reloads the data for our tableview
	private func updateUI() {
		button_recalculate?.enabled = records.count > 0
		button_remove?.enabled = records.count > 0
		button_save?.enabled = records.count > 0
		textField_fileCount.integerValue = records.count

		// other 'stats' .. may be a bit sloppy
		var error_count = 0; var failure_count = 0; var verified_count = 0
		
		for entry in records {
			switch entry.status {
			case .FileNotFound, .UnknownChecksum:
				error_count++
				continue
				
			case .Valid:
				verified_count++
				continue
				
			default:
				break
			}
			
			if entry.result == "" {
				continue
			}
			
			if entry.expected.compare(entry.result, options: .CaseInsensitiveSearch) != .OrderedSame {
				entry.status = .Invalid
				failure_count++
			} else {
				entry.status = .Valid
				verified_count++
			}
		}
		
		textField_errorCount.integerValue = error_count
		textField_failedCount.integerValue = failure_count
		textField_verifiedCount.integerValue = verified_count
		
		tableViewFileList.reloadData()
		tableViewFileList.scrollRowToVisible(records.count - 1)
	}
	
	private func startProcessingQueue() {
		progressBar_progress.indeterminate = true
		progressBar_progress.hidden = false
		progressBar_progress.startAnimation(self)
		button_stop?.enabled = true
		popUpButton_checksum.enabled = false
		textField_status.hidden = false
	}
	
	private func stopProcessingQueue() {
		progressBar_progress.stopAnimation(self)
		progressBar_progress.hidden = true
		button_stop?.enabled = false
		popUpButton_checksum.enabled = true
		textField_status.hidden = true
		textField_status.stringValue = ""
	}
	
	/// Called periodically for updating the UI
	@objc private func updateProgress(timer: NSTimer) {
		if queue.operationCount == 0 {
			timer.invalidate()
			updateProgressTimer = nil
			stopProcessingQueue()
		}
		
		self.updateUI()
		textField_status.integerValue = queue.operationCount
	}

	// MARK: TableView delegate
	
	func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
		guard let key = tableColumn?.identifier else {
			return nil
		}
		let newEntry = records[row]
		
		switch key {
		case "filepath":
			return newEntry.filePath.lastPathComponent
			
		case "status":
			return FileEntry.imageForStatus(newEntry.status)
			
		case "expected":
			if newEntry.status == .UnknownChecksum {
				return "Unknown (not recognized)"
			}
			return newEntry.expected
			
		case "result":
			if newEntry.status == .FileNotFound {
				return "Missing"
			}
			return newEntry.result
			
		default:
			break
		}
		
		return nil
	}
	
	func numberOfRowsInTableView(tableView: NSTableView) -> Int {
		return records.count
	}
	
	func tableView(tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableViewDropOperation) -> NSDragOperation {
		return .Every
	}
	
	func tableView(tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableViewDropOperation) -> Bool {
		let pboard = info.draggingPasteboard()
		guard let files = pboard.propertyListForType(NSFilenamesPboardType) as? NSArray as? [String] else {
			return false
		}
		
		processFiles(files)
		
		return true
	}
	
	func tableView(tableView: NSTableView, didClickTableColumn tableColumn: NSTableColumn) {
		guard tableView === tableViewFileList else {
			return
		}
		
		let allColums = tableViewFileList.tableColumns
		for aColumn in allColums {
			if aColumn !== tableColumn {
				tableViewFileList.setIndicatorImage(nil, inTableColumn: aColumn)
			}
		}
		
		tableViewFileList.highlightedTableColumn = tableColumn
		
		if tableViewFileList.indicatorImageInTableColumn(tableColumn) != NSImage(named: "NSAscendingSortIndicator") {
			tableViewFileList.setIndicatorImage(NSImage(named: "NSAscendingSortIndicator"), inTableColumn: tableColumn)
			sortWithDescriptor(NSSortDescriptor(key: tableColumn.identifier, ascending: true))
		} else {
			tableViewFileList.setIndicatorImage(NSImage(named: "NSDescendingSortIndicator"), inTableColumn: tableColumn)
			sortWithDescriptor(NSSortDescriptor(key: tableColumn.identifier, ascending: false))
		}
	}
	
	func sortWithDescriptor(descriptor: NSSortDescriptor) {
		let sorted = NSMutableArray(array: records)
		sorted.sortUsingDescriptors([descriptor])
		records.removeAll(keepCapacity: true)
		records.extend(sorted as NSArray as! [FileEntry])
		updateUI()
	}
	
	// MARK: Toolbar delegate
	private func setupToolbar() {
		let toolbar = NSToolbar(identifier: SuperSFVToolbarIdentifier)
		toolbar.allowsUserCustomization = true
		toolbar.autosavesConfiguration = true
		toolbar.displayMode = .IconOnly
		//toolbar.sizeMode = NSToolbarSizeModeSmall;

		toolbar.delegate = self
		windowMain.toolbar = toolbar
	}
	
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

		case RemoveToolbarIdentifier:
			toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem!.label = "Remove"
			toolbarItem!.paletteLabel = "Remove"
			toolbarItem!.toolTip = "Remove selected items or prompt to remove all items if none are selected"
			toolbarItem!.image = NSImage(named: "edit_remove")
			toolbarItem!.target = self
			toolbarItem!.action = "removeClicked:"
			toolbarItem!.autovalidates = false

		case RecalculateToolbarIdentifier:
			toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem!.label = "Recalculate"
			toolbarItem!.paletteLabel = "Recalculate"
			toolbarItem!.toolTip = "Recalculate checksums"
			toolbarItem!.image = NSImage(named: "reload")
			toolbarItem!.target = self
			toolbarItem!.action = "recalculateClicked:"
			toolbarItem!.autovalidates = false

		case StopToolbarIdentifier:
			toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem!.label = "Stop"
			toolbarItem!.paletteLabel = "Stop"
			toolbarItem!.toolTip = "Stop calculating checksums"
			toolbarItem!.image = NSImage(named: "stop")
			toolbarItem!.target = self
			toolbarItem!.action = "stopClicked:"
			toolbarItem!.autovalidates = false

		case SaveToolbarIdentifier:
			toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem!.label = "Save"
			toolbarItem!.paletteLabel = "Save"
			toolbarItem!.toolTip = "Save current state"
			toolbarItem!.image = NSImage(named: "1downarrow")
			toolbarItem!.target = self
			toolbarItem!.action = "saveClicked:"
			toolbarItem!.autovalidates = false

		case ChecksumToolbarIdentifier:
			toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem!.label = "Checksum"
			toolbarItem!.paletteLabel = "Checksum"
			toolbarItem!.toolTip = "Checksum algorithm to use"
			toolbarItem!.view = viewChecksum
			toolbarItem!.minSize = NSSize(width: 106, height: viewChecksum.frame.height)
			toolbarItem!.maxSize = NSSize(width: 106, height: viewChecksum.frame.height)
			
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
