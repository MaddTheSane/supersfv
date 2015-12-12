//
//  SIntegrityOperation.swift
//  SuperSFV
//
//  Created by C.W. Betts on 8/3/15.
//
//

import Cocoa


class IntegrityOperation: NSOperation {
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
			guard !cancelled else {
				return
			}
			
			let algorithm: CryptoAlgorithm
			
			let file = fileEntry.filePath
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
			
			var fileHandle = NSFileHandle(forReadingAtPath: file)
			
			if fileHandle == nil {
				return
			}
			
			var crc: crc32_t = 0
			var md5_ctx = CC_MD5_CTX()
			var sha_ctx = CC_SHA1_CTX()
			
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
				var fileData = NSData()
				fileData = fileHandle!.readDataOfLength(65536)
				repeat {
					if cancelled {
						break
					}
					
					switch algorithm {
					case .CRC:
						crc = uulib_crc32(crc, UnsafePointer<UInt8>(fileData.bytes), fileData.length)
						
					case .MD5:
						CC_MD5_Update(&md5_ctx, fileData.bytes, CC_LONG(fileData.length))
						
					case .SHA1:
						CC_SHA1_Update(&sha_ctx, fileData.bytes, CC_LONG(fileData.length))
						
					default:
						break
						
					}
					fileData = fileHandle!.readDataOfLength(65536)
				} while fileData.length > 0
				NSLog("Finished with file %@", fileEntry.filePath);
			}
			
			if cancelled {
				return
			}
			
			fileHandle = nil
			
			if algorithm == .CRC {
				hashString = String(format: "%08x", crc).uppercaseString
			} else {
				var dgst = [UInt8](count: algorithm == .MD5 ? Int(CC_MD5_DIGEST_LENGTH) : Int(CC_SHA1_DIGEST_LENGTH), repeatedValue: 0)
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
					tmpHash += String(format: "%02x", i).uppercaseString
				}
				hashString = tmpHash
			}
			
			fileEntry.result = hashString!
	}
}
