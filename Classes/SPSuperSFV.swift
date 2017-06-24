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

let kRemoveRecordFromList = "RM_RECORD_FROM_LIST"

private var applicationVersion: String {
	let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
	return version ?? "unknown"
}

@NSApplicationMain
class SPSuperSFV : NSObject, NSApplicationDelegate {
	@IBOutlet weak var buttonAdd: NSButton?
	@IBOutlet weak var buttonCloseLicense: NSButton!
	@IBOutlet weak var buttonContact: NSButton?
	@IBOutlet weak var easterEggButton: NSButton!
	@IBOutlet weak var buttonRecalculate: NSButton?
	@IBOutlet weak var buttonRemove: NSButton?
	@IBOutlet weak var buttonSave: NSButton?
	@IBOutlet weak var buttonShowLicense: NSButton!
	@IBOutlet weak var buttonStop: NSButton?
	@IBOutlet weak var licensePanel: NSPanel!
	@IBOutlet weak var checksumPopUp: NSPopUpButton!
	@IBOutlet weak var progressBar: NSProgressIndicator!
	@IBOutlet weak var errorCountField: NSTextField!
	@IBOutlet weak var failedCountField: NSTextField!
	@IBOutlet weak var fileCountField: NSTextField!
	@IBOutlet weak var statusField: NSTextField!
	@IBOutlet weak var verifiedCountField: NSTextField!
	@IBOutlet weak var versionField: NSTextField!
	@IBOutlet weak var scrollViewCredits: NSScrollView!
	@IBOutlet weak var scrollViewLicense: NSScrollView!
	@IBOutlet weak var viewChecksum: NSView!
	@IBOutlet weak var windowAbout: NSWindow!
	@IBOutlet weak var windowMain: NSWindow!
	
	@IBOutlet weak var tableViewFileList: SPTableView!
	
	var textViewCredits: NSTextView {
		return scrollViewCredits.contentView.documentView as! NSTextView
	}
	var textViewLicense: NSTextView {
		return scrollViewLicense.contentView.documentView as! NSTextView
	}
	
	fileprivate let queue: OperationQueue = {
		let aqueue = OperationQueue()
	
		aqueue.name = "SPDecoder Queue"
		
		return aqueue
	}()
	fileprivate var records = [FileEntry]()
	fileprivate var updateProgressTimer: Timer?
	fileprivate var baseURL = URL(fileURLWithPath: NSHomeDirectory())
	
	override init() {
		var dictionary = [String: Any]()
		dictionary["checksum_algorithm"] = "CRC32"; // default for most SFV programs
		NSUserDefaultsController.shared().initialValues = dictionary
		UserDefaults.standard.register(defaults: dictionary)
		super.init()
	}
	
	func applicationWillFinishLaunching(_ notification: Notification) {
		setupToolbar()
		
		// selecting items in our table view and pressing the delete key
		NotificationCenter.default.addObserver(self, selector: #selector(SPSuperSFV.removeSelectedRecords(_:)), name: NSNotification.Name(rawValue: kRemoveRecordFromList), object: nil)
		
		// register for drag and drop on the table view
		tableViewFileList.register(forDraggedTypes: [NSFilenamesPboardType])
		
		// make the window pertee and show it
		buttonStop?.isEnabled = false
		updateUI()
		
		windowMain.center()
		windowMain.makeKeyAndOrderFront(nil)
	}
	
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		return true
	}
	
	func application(_ sender: NSApplication, openFile filename: String) -> Bool {
		processFiles([filename])
		return true
	}
	
	func application(_ sender: NSApplication, openFiles filenames: [String]) {
		processFiles(filenames)
	}
	
	/// remove selected records from our table view
	@objc private func removeSelectedRecords(_ sender: AnyObject?) {
		let rows = tableViewFileList.selectedRowIndexes
		
		for row in rows.reversed() {
			records.remove(at: row)
		}
		
		updateUI()
	}
	
	// MARK: IBActions
	@IBAction func addClicked(_ sender: AnyObject) {
		let oPanel = NSOpenPanel()
		oPanel.prompt = NSLocalizedString("Add", comment: "Add");
		oPanel.title = NSLocalizedString("Add files or folder contents", comment: "Add files or folder contents") 
		oPanel.allowsMultipleSelection = true
		oPanel.canChooseFiles = true
		oPanel.canChooseDirectories = true
		oPanel.beginSheetModal(for: windowMain) { (result) -> Void in
			if result == NSModalResponseOK {
				let urls = oPanel.urls
				self.processFileURLs(urls)
			}
		}
	}
	
	@IBAction func recalculateClicked(_ sender: AnyObject?) {
		let t = records.map({ return $0.fileURL })
		records.removeAll(keepingCapacity: true)
		processFileURLs(t)
		updateUI()
	}
	
	@IBAction func removeClicked(_ sender: AnyObject?) {
		if tableViewFileList.numberOfSelectedRows == 0 && records.count > 0 {
			let alert = NSAlert()
			alert.messageText = NSLocalizedString("Confirm Removal", comment: "Confirm Removal")
			alert.informativeText = NSLocalizedString("Are you sure you want to remove all entries?", comment: "You sure you want to ditch all of the entries? They're so cute!")
			alert.addButton(withTitle: NSLocalizedString("Remove All", comment: "Remove All"))
			alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel"))
			
			alert.beginSheetModal(for: windowMain, completionHandler: { (returnCode) -> Void in
				if returnCode == NSAlertFirstButtonReturn {
					self.records.removeAll(keepingCapacity: false)
					self.updateUI()
				}
			})
		} else {
			removeSelectedRecords(nil)
		}
	}
	
	@IBAction func saveClicked(_ sender: AnyObject?) {
		if records.count == 0 {
			NSBeep()
			return
		}
		
		let sPanel = NSSavePanel()
		sPanel.allowedFileTypes = ["sfv"]

		sPanel.beginSheetModal(for: windowMain) { (result) -> Void in
			if result == NSModalResponseOK {
				// shameless plug to start out with
				var output = "; Created using SuperSFV v\(applicationVersion) on Mac OS X\n"

				for entry in self.records {
					switch entry.status {
					case .valid, .invalid:
						output += "\((entry.filePath as NSString).lastPathComponent) \(entry.result)\n"
					default:
						continue
					}
				}
				
				do {
					try (output).write(to: sPanel.url!, atomically: false, encoding: String.Encoding.utf8)
				} catch _ {
					
				}
			}
		}
	}
	
	@IBAction func stopClicked(_ sender: AnyObject?) {
		queue.cancelAllOperations()
	}
	
	@IBAction func showLicense(_ sender: AnyObject?) {
		if let licenseURL = Bundle.main.url(forResource: "License", withExtension: "txt") {
			var usedEnc = String.Encoding.utf8
			textViewLicense.string = (try! String(contentsOf: licenseURL, usedEncoding: &usedEnc))
		} else {
			//TODO: rtf support in the future?
			textViewLicense.string = NSLocalizedString("License file not found!", comment: "License file not found!")
		}
		
		windowAbout.beginSheet(licensePanel, completionHandler: nil)
	}
	
	@IBAction func closeLicense(_ sender: AnyObject?) {
		licensePanel.orderOut(sender)
		windowAbout.endSheet(licensePanel)
	}
	
	@IBAction func aboutIconClicked(_ sender: AnyObject?) {
		
	}
	
	@IBAction func showAbout(_ sender: AnyObject?) {
		// Credits
		var creditsURL = Bundle.main.url(forResource: "Credits", withExtension: "rtf")
		if creditsURL == nil {
			// just in case we add images later on.
			creditsURL = Bundle.main.url(forResource: "Credits", withExtension: "rtfd")
		}
		let creditsString = NSAttributedString(url: creditsURL!, documentAttributes: nil)!
		textViewCredits.textStorage?.setAttributedString(creditsString)
		
		// Version
		versionField.stringValue = applicationVersion
		
		// die you little blue bastard for attempting to thwart my easter egg
		easterEggButton.focusRingType = .none
		
		// Center n show eet
		windowAbout.center()
		windowAbout.makeKeyAndOrderFront(nil)
	}
	
	@IBAction func contactClicked(_ sender: AnyObject?) {
		NSWorkspace.shared().open(URL(string: "mailto:reikonmusha@gmail.com")!)
	}
	
	@objc(parseSFVFileAtFileURL:) func parseSFVFile(_ fileURL: URL) {
		let thisBaseURL = fileURL.deletingLastPathComponent()
		baseURL = thisBaseURL
		do {
			let rawContents = try NSString(contentsOf: fileURL, usedEncoding: nil)
			let contents = rawContents.components(separatedBy: CharacterSet.newlines)
			for entry1 in contents {
				var errc = 0 //error count
				
				let entry = entry1.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
				if entry == "" {
					continue
				}
				if entry.characters.first == ";" {
					continue; // skip the line if it's a comment
				}
				guard let r = entry.rangeOfCharacter(from: CharacterSet(charactersIn: " "), options: .backwards) else {
					continue
				}
				let newURL = URL(string: entry[entry.startIndex..<r.lowerBound], relativeTo: fileURL)!
				//let newURL = thisBaseURL.URLByAppendingPathComponent(entry[entry.startIndex..<r.startIndex])
				let hash = entry[r.upperBound ..< entry.endIndex]
				
				let newEntry = FileEntry(fileURL: newURL, expectedHash: hash)
				
				// file doesn't exist...
				if !(newURL as NSURL).checkResourceIsReachableAndReturnError(nil) {
					newEntry.status = .fileNotFound
					newEntry.result =  NSLocalizedString("Missing", comment: "Missing")
					errc += 1
				}
				
				// length doesn't match CRC32, MD5 or SHA-1 respectively
				if hash.characters.count != 8 && hash.characters.count != 32 && hash.characters.count != 40 {
					newEntry.status = .unknownChecksum
					newEntry.expected = NSLocalizedString("Unknown", comment: "Unknown")
					errc += 1;
				}
				
				// if theres an error, then we don't need to continue with this entry
				if errc != 0 {
					records.append(newEntry)
					updateUI()
					continue;
				}
				// assume it'll fail until proven otherwise
				newEntry.status = .invalid;
				
				queueEntry(newEntry)
			}
		} catch _ {
			NSBeep()
		}
		
	}
	
	@objc(parseSFVFileAtFilePath:) func parseSFVFile(_ filePath: String) {
		let contents = (try! NSString(contentsOfFile: filePath, usedEncoding: nil)).components(separatedBy: "\n")
		for entry1 in contents {
			var errc = 0 //error count

			let entry = entry1.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
			if entry == "" {
				continue // skip blank lines
			}
			if entry.characters.first == ";" {
				continue // skip the line if it's a comment
			}
			guard let r = entry.rangeOfCharacter(from: CharacterSet(charactersIn: " "), options: .backwards) else {
				continue
			}
			let newPath = ((filePath as NSString).deletingLastPathComponent as NSString).appendingPathComponent(entry[entry.startIndex..<r.lowerBound])
			let hash = entry[r.upperBound ..< entry.endIndex]
			
			let newEntry = FileEntry(path: newPath, expectedHash: hash)
			
			// file doesn't exist...
			if !FileManager.default.fileExists(atPath: newPath) {
				newEntry.status = .fileNotFound
				newEntry.result = NSLocalizedString("Missing", comment: "Missing")
				errc += 1
			}
			
			// length doesn't match CRC32, MD5 or SHA-1 respectively
			if hash.characters.count != 8 && hash.characters.count != 32 && hash.characters.count != 40 {
				newEntry.status = .unknownChecksum;
				newEntry.expected = NSLocalizedString("Unknown", comment: "Unknown")
				errc += 1;
			}
			
			// if theres an error, then we don't need to continue with this entry
			if errc != 0 {
				records.append(newEntry)
				updateUI()
				continue;
			}
			// assume it'll fail until proven otherwise
			newEntry.status = .invalid;
			
			queueEntry(newEntry)
		}
	}
	
	/// process files dropped on the tableview, icon, or are manually opened
	func processFileURLs(_ fileURLs: [URL], fileManager fm: FileManager = FileManager.default) {

		for url in fileURLs {
			if !url.isFileURL {
				continue
			}
			let lastPathComp = url.lastPathComponent
				if lastPathComp.characters.first == "." {
					continue // ignore hidden files
				}
			let pathExt = url.pathExtension
			if pathExt.lowercased() == "sfv" {
				let isDirDict = try? url.resourceValues(forKeys: [.fileResourceTypeKey])
				if let aDir = isDirDict?.fileResourceType, aDir != URLFileResourceType.directory {
					parseSFVFile(url)
					continue
				}
			}
			let isDirDict = try? url.resourceValues(forKeys: [URLResourceKey.fileResourceTypeKey])
			if let aDir = isDirDict?.fileResourceType, aDir == URLFileResourceType.directory {
				do {
					let dirContents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [], options: [])
					processFileURLs(dirContents, fileManager: fm)
				} catch _ {}
				continue
			}
			let newEntry = FileEntry(fileURL: url)
			queueEntry(newEntry, algorithm: SPCryptoAlgorithm(rawValue: Int32(checksumPopUp.indexOfSelectedItem)) ?? .CRC)
		}
	}
	
	/// process files dropped on the tableview, icon, or are manually opened
	fileprivate func processFiles(_ fileNames: [String]) {
		
		processFileURLs(fileNames.map({ (aPath) -> URL in
			return URL(fileURLWithPath: aPath)
		}))
	}
	
	// MARK: private methods
	fileprivate func queueEntry(_ entry: FileEntry, algorithm: SPCryptoAlgorithm = .unknown) {
		let integrityOp = SPIntegrityOperation(fileEntry: entry, target: self, algorithm: algorithm)
		
		queue.addOperation(integrityOp)
		
		/* TODO: Set image indicating "in progress" */
		entry.status = .checking;
		
		records.append(entry)
		
		/* If this was the first operation added to the queue */
		if (queue.operationCount == 1) {
			startProcessingQueue()
			updateProgressTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(SPSuperSFV.updateProgress(_:)), userInfo: nil, repeats: true)
		}
	}
	
	/// updates the general UI, i.e the toolbar items, and reloads the data for our tableview
	fileprivate func updateUI() {
		buttonRecalculate?.isEnabled = records.count > 0
		buttonRemove?.isEnabled = records.count > 0
		buttonSave?.isEnabled = records.count > 0
		fileCountField.integerValue = records.count

		// other 'stats' .. may be a bit sloppy
		var error_count = 0; var failure_count = 0; var verified_count = 0
		
		for entry in records {
			switch entry.status {
			case .fileNotFound, .unknownChecksum:
				error_count += 1
				continue
				
			case .valid:
				verified_count += 1
				continue
				
			default:
				break
			}
			
			if entry.result == "" {
				continue
			}
			
			if entry.expected.compare(entry.result, options: .caseInsensitive) != .orderedSame {
				entry.status = .invalid
				failure_count += 1
			} else {
				entry.status = .valid
				verified_count += 1
			}
		}
		
		errorCountField.integerValue = error_count
		failedCountField.integerValue = failure_count
		verifiedCountField.integerValue = verified_count
		
		tableViewFileList.reloadData()
		tableViewFileList.scrollRowToVisible(records.count - 1)
	}
	
	fileprivate func startProcessingQueue() {
		progressBar.isIndeterminate = true
		progressBar.isHidden = false
		progressBar.startAnimation(self)
		buttonStop?.isEnabled = true
		checksumPopUp.isEnabled = false
		statusField.isHidden = false
	}
	
	fileprivate func stopProcessingQueue() {
		progressBar.stopAnimation(self)
		progressBar.isHidden = true
		buttonStop?.isEnabled = false
		checksumPopUp.isEnabled = true
		statusField.isHidden = true
		statusField.stringValue = ""
	}
	
	/// Called periodically for updating the UI
	@objc fileprivate func updateProgress(_ timer: Timer) {
		if queue.operationCount == 0 {
			timer.invalidate()
			updateProgressTimer = nil
			stopProcessingQueue()
		}
		
		self.updateUI()
		statusField.integerValue = queue.operationCount
	}
}

// MARK: TableView delegate
extension SPSuperSFV: NSTableViewDataSource, NSTableViewDelegate {
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		guard let key = tableColumn?.identifier else {
			return nil
		}
		let newEntry = records[row]
		
		switch key {
		case "filepath":
			return newEntry.fileURL.lastPathComponent
			
		case "status":
			return FileEntry.image(forStatus: newEntry.status)
			
		case "expected":
			if newEntry.status == .unknownChecksum {
				return NSLocalizedString("Unknown (not recognized)", comment: "Unknown (not recognized)")
			}
			return newEntry.expected
			
		case "result":
			if newEntry.status == .fileNotFound {
				return NSLocalizedString("Missing", comment: "Missing")
			}
			return newEntry.result
			
		default:
			break
		}
		
		return nil
	}
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return records.count
	}
	
	func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableViewDropOperation) -> NSDragOperation {
		return .every
	}
	
	func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableViewDropOperation) -> Bool {
		let pboard = info.draggingPasteboard()
		guard let files = pboard.propertyList(forType: NSFilenamesPboardType) as? NSArray as? [String] else {
			return false
		}
		
		processFiles(files)
		
		return true
	}
	
	func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
		guard tableView === tableViewFileList else {
			return
		}
		
		let allColums = tableViewFileList.tableColumns
		for aColumn in allColums {
			if aColumn !== tableColumn {
				tableViewFileList.setIndicatorImage(nil, in: aColumn)
			}
		}
		
		tableViewFileList.highlightedTableColumn = tableColumn
		
		if tableViewFileList.indicatorImage(in: tableColumn) != NSImage(named: "NSAscendingSortIndicator") {
			tableViewFileList.setIndicatorImage(NSImage(named: "NSAscendingSortIndicator"), in: tableColumn)
			sortWithDescriptor(NSSortDescriptor(key: tableColumn.identifier, ascending: true))
		} else {
			tableViewFileList.setIndicatorImage(NSImage(named: "NSDescendingSortIndicator"), in: tableColumn)
			sortWithDescriptor(NSSortDescriptor(key: tableColumn.identifier, ascending: false))
		}
	}
	
	func sortWithDescriptor(_ descriptor: NSSortDescriptor) {
		let sorted = NSMutableArray(array: records)
		sorted.sort(using: [descriptor])
		records.removeAll(keepingCapacity: true)
		records.append(contentsOf: sorted as NSArray as! [FileEntry])
		updateUI()
	}
}

// MARK: Toolbar delegate
extension SPSuperSFV: NSToolbarDelegate {
	fileprivate func setupToolbar() {
		let toolbar = NSToolbar(identifier: SuperSFVToolbarIdentifier)
		toolbar.allowsUserCustomization = true
		toolbar.autosavesConfiguration = true
		toolbar.displayMode = .iconOnly
		//toolbar.sizeMode = NSToolbarSizeModeSmall;

		toolbar.delegate = self
		windowMain.toolbar = toolbar
	}
	
	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: String, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		var toolbarItem: NSToolbarItem? = nil
		switch itemIdentifier {
		case AddToolbarIdentifier:
			toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem!.label = NSLocalizedString("Add", comment: "Add")
			toolbarItem!.paletteLabel = NSLocalizedString("Add", comment: "Add")
			toolbarItem!.toolTip = NSLocalizedString("Add a file or the contents of a folder", comment: "Add a file or the contents of a folder")
			toolbarItem!.image = NSImage(named: "edit_add")
			toolbarItem!.target = self
			toolbarItem!.action = #selector(SPSuperSFV.addClicked(_:))
			toolbarItem!.autovalidates = false

		case RemoveToolbarIdentifier:
			toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem!.label = NSLocalizedString("Remove", comment: "Remove") 
			toolbarItem!.paletteLabel = NSLocalizedString("Remove", comment: "Remove")
			toolbarItem!.toolTip = NSLocalizedString("Remove selected items or prompt to remove all items if none are selected", comment: "Remove selected items or prompt to remove all items if none are selected")
			toolbarItem!.image = NSImage(named: "edit_remove")
			toolbarItem!.target = self
			toolbarItem!.action = #selector(SPSuperSFV.removeClicked(_:))
			toolbarItem!.autovalidates = false

		case RecalculateToolbarIdentifier:
			toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem!.label = "Recalculate"
			toolbarItem!.paletteLabel = "Recalculate"
			toolbarItem!.toolTip = "Recalculate checksums"
			toolbarItem!.image = NSImage(named: "reload")
			toolbarItem!.target = self
			toolbarItem!.action = #selector(SPSuperSFV.recalculateClicked(_:))
			toolbarItem!.autovalidates = false

		case StopToolbarIdentifier:
			toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem!.label = NSLocalizedString("Stop", comment: "Stop")
			toolbarItem!.paletteLabel = NSLocalizedString("Stop", comment: "Stop")
			toolbarItem!.toolTip = NSLocalizedString("Stop calculating checksums", comment: "Stop calculating checksums")
			toolbarItem!.image = NSImage(named: "stop")
			toolbarItem!.target = self
			toolbarItem!.action = #selector(SPSuperSFV.stopClicked(_:))
			toolbarItem!.autovalidates = false

		case SaveToolbarIdentifier:
			toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem!.label = NSLocalizedString("Save", comment: "Save")
			toolbarItem!.paletteLabel = NSLocalizedString("Save", comment: "Save")
			toolbarItem!.toolTip = NSLocalizedString("Save current state", comment: "Save current state")
			toolbarItem!.image = NSImage(named: "1downarrow")
			toolbarItem!.target = self
			toolbarItem!.action = #selector(SPSuperSFV.saveClicked(_:))
			toolbarItem!.autovalidates = false

		case ChecksumToolbarIdentifier:
			toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem!.label = NSLocalizedString("Checksum", comment: "Checksum")
			toolbarItem!.paletteLabel = NSLocalizedString("Checksum", comment: "Checksum")
			toolbarItem!.toolTip = NSLocalizedString("Checksum algorithm to use", comment: "Checksum algorithm to use")
			toolbarItem!.view = viewChecksum
			toolbarItem!.minSize = NSSize(width: 106, height: viewChecksum.frame.height)
			toolbarItem!.maxSize = NSSize(width: 106, height: viewChecksum.frame.height)
			
		default:
			break
		}
		
		return toolbarItem
	}
	
	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [String] {
		return [AddToolbarIdentifier, RemoveToolbarIdentifier,
		RecalculateToolbarIdentifier, NSToolbarSeparatorItemIdentifier,
		ChecksumToolbarIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		SaveToolbarIdentifier, StopToolbarIdentifier]
	}
	
	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [String] {
		return [AddToolbarIdentifier, RecalculateToolbarIdentifier,
		StopToolbarIdentifier, SaveToolbarIdentifier, ChecksumToolbarIdentifier,
		NSToolbarPrintItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier,
		NSToolbarSeparatorItemIdentifier, RemoveToolbarIdentifier]
	}
	
	override func validateToolbarItem(_ theItem: NSToolbarItem) -> Bool {
		return true
	}
}
