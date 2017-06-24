//
//  SIntegrityOperation.swift
//  SuperSFV
//
//  Created by C.W. Betts on 8/3/15.
//
//

import Cocoa


final class IntegrityOperation: Operation {
	enum CryptoAlgorithm : Int32 {
		case Unknown = -1
		case CRC = 0
		case MD5
		case SHA1
	}
	private(set) var hashString: String?
	private var fileEntry: FileEntry
	private var target: NSObject
	private var cryptoAlgorithm : CryptoAlgorithm

	init(fileEntry entry: FileEntry, target object: NSObject, algorithm: CryptoAlgorithm = .Unknown) {
		fileEntry = entry
		target = object
		cryptoAlgorithm = algorithm
		
		super.init()
	}

	override func main() {
		print("Running for file \(fileEntry.filePath)")
		guard !isCancelled else {
			return
		}
		
		let algorithm: CryptoAlgorithm
		
		let expectedHash = fileEntry.expected
		if cryptoAlgorithm == .Unknown {
			switch expectedHash.characters.count {
			case 8:
				algorithm = .CRC
				
			case 32:
				algorithm = .MD5
				
			case 40:
				algorithm = .SHA1
				
			default:
				algorithm = .CRC
			}
		} else {
			algorithm = cryptoAlgorithm
		}
		
		var crc: crc32_t = 0
		var md5_ctx = CC_MD5_CTX()
		var sha_ctx = CC_SHA1_CTX()
		
		do {
			guard let fileHandle = try? FileHandle(forReadingFrom: fileEntry.fileURL) else {
				return
			}
			
			switch algorithm {
			case .CRC:
				crc = uulib_crc32(0, nil, 0)
				
			case .MD5:
				CC_MD5_Init(&md5_ctx)
				
			case .SHA1:
				CC_SHA1_Init(&sha_ctx);
				
			default:
				break
			}
			autoreleasepool() {
				var fileData = fileHandle.readData(ofLength: 65536)
				repeat {
					guard !isCancelled else {
						return
					}
					
					switch algorithm {
					case .CRC:
						crc = fileData.withUnsafeBytes({ (f: UnsafePointer<UInt8>) -> crc32_t in
							return uulib_crc32(crc, f, fileData.count)
						})
						
					case .MD5:
						fileData.withUnsafeBytes({ (f: UnsafePointer<UInt8>) -> Void in
							CC_MD5_Update(&md5_ctx, f, CC_LONG(fileData.count))
						})
						
					case .SHA1:
						fileData.withUnsafeBytes({ (f: UnsafePointer<UInt8>) -> Void in
							CC_SHA1_Update(&sha_ctx, f, CC_LONG(fileData.count))
						})
						
					default:
						break
						
					}
					fileData = fileHandle.readData(ofLength: 65536)
				} while fileData.count > 0
				NSLog("Finished with file %@", fileEntry.filePath);
			}
			
			guard !isCancelled else {
				return
			}
		}
		
		if algorithm == .CRC {
			hashString = String(format: "%08X", crc)
		} else {
			var dgst = [UInt8](repeating: 0, count: algorithm == .MD5 ? Int(CC_MD5_DIGEST_LENGTH) : Int(CC_SHA1_DIGEST_LENGTH))
			switch algorithm {
			case .SHA1:
				CC_SHA1_Final(&dgst, &sha_ctx)
				
			case .MD5:
				CC_MD5_Final(&dgst, &md5_ctx)
				
			default:
				break
			}
			
			var tmpHash = ""
			for i in dgst {
				tmpHash += String(format: "%02X", i)
			}
			hashString = tmpHash
		}
		
		fileEntry.result = hashString!
	}
}
