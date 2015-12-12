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

#import "SPIntegrityOperation.h"
#import "SuperSFV-Swift.h"

#include <CommonCrypto/CommonCrypto.h>
#include "crc32.h"

@implementation SPIntegrityOperation
@synthesize hashString = hash;

- (id)initWithFileEntry:(FileEntry *)entry target:(NSObject *)object
{
    return [self initWithFileEntry:entry target:object algorithm:-1];
}

- (id)initWithFileEntry:(FileEntry *)entry target:(NSObject *)object algorithm:(SPCryptoAlgorithm)algorithm
{
    if (self = [super init])
    {
        fileEntry = entry;
        target = object;
        cryptoAlgorithm = algorithm;
    }
    
    return self;
}

-(void)main
{
    NSLog(@"Running for file %@", fileEntry.filePath);

	if (![self isCancelled])
	{
        SPCryptoAlgorithm algorithm;
        uint8_t *dgst; // buffers
        
        NSURL *url = fileEntry.fileURL;
        NSString *expectedHash = fileEntry.expected;

        if (cryptoAlgorithm == SPCryptoAlgorithmUnknown) {
            switch ([expectedHash length]) {
                case 8:
                    algorithm = SPCryptoAlgorithmCRC;
                    break;
                case 32:
                    algorithm = SPCryptoAlgorithmMD5;
                    break;
                case 40:
                    algorithm = SPCryptoAlgorithmSHA1;
                    break;
                default:
                    algorithm = SPCryptoAlgorithmCRC;
                    break;
            }
        } else {
            algorithm = cryptoAlgorithm;
        }
		
		NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingFromURL:url error:NULL];
		
        if (fileHandle == NULL)
            return;
        
//        [target performSelectorOnMainThread:@selector(initProgress:)
//                               withObject:[NSArray arrayWithObjects:
//                                           [NSString stringWithFormat:@"Performing %@ on %@", @"CRC32", //TODO: [popUpButton_checksum itemTitleAtIndex:algorithm],
//                                            [file lastPathComponent]],
//                                           [NSNumber numberWithDouble:0.0],
//                                           [fileAttributes objectForKey:NSFileSize],
//                                           nil]
//                            waitUntilDone:YES];

        union HashCtx_t {
            crc32_t crc;
            CC_MD5_CTX md5_ctx;
            CC_SHA1_CTX sha_ctx;
        } hashCtx;
        
        switch (algorithm) {
            case SPCryptoAlgorithmCRC:
                hashCtx.crc = crc32(0L,Z_NULL,0);
                break;
                
            case SPCryptoAlgorithmMD5:
                CC_MD5_Init(&hashCtx.md5_ctx);
                break;
                
            case SPCryptoAlgorithmSHA1:
                CC_SHA1_Init(&hashCtx.sha_ctx);
                break;
                
            default:
                break;
        }
		
        @autoreleasepool {
            NSData *fileData;
            
            while ((fileData = [fileHandle readDataOfLength:65536]).length > 0) {
                if ([self isCancelled])
                    break;
                
                switch (algorithm) {
                    case SPCryptoAlgorithmCRC:
                        hashCtx.crc = crc32(hashCtx.crc, fileData.bytes, fileData.length);
                        break;
                    case SPCryptoAlgorithmMD5:
                        CC_MD5_Update(&hashCtx.md5_ctx, fileData.bytes, (CC_LONG)fileData.length);
                        break;
                    case SPCryptoAlgorithmSHA1:
                        CC_SHA1_Update(&hashCtx.sha_ctx, fileData.bytes, (CC_LONG)fileData.length);
                        break;
                        
                    default:
                        NSLog(@"We shouldn't get here...");
                        break;
                }
            }
            NSLog(@"Finished with file %@", fileEntry.filePath);
        }
        fileHandle = nil;

        if ([self isCancelled])
            return;
        
        if (algorithm == SPCryptoAlgorithmCRC) {
            hash = [[NSString stringWithFormat:@"%08x", hashCtx.crc] uppercaseString];
        } else {
            hash = @"";
            dgst = (uint8_t *) calloc (((algorithm == SPCryptoAlgorithmMD5)?32:40), sizeof(uint8_t));
            
            switch (algorithm) {
                case SPCryptoAlgorithmSHA1:
                    CC_SHA1_Final(dgst,&hashCtx.sha_ctx);
                    break;
                    
                case SPCryptoAlgorithmMD5:
                    CC_MD5_Final(dgst,&hashCtx.md5_ctx);
                    break;
                    
                default:
                    break;
            }
            
            for (int i = 0; i < ((algorithm == SPCryptoAlgorithmMD5)?16:20); i++)
                hash = [[hash stringByAppendingFormat:@"%02x", dgst[i]] uppercaseString];
            
            free(dgst);
        }
        
        fileEntry.result = hash;
        
        /* SPFileEntry *newEntry = [[SPFileEntry alloc] init];
        NSDictionary *newDict;

        if (![expectedHash isEqualToString:@""])
            newDict = [[NSMutableDictionary alloc]
                       initWithObjects:[NSArray arrayWithObjects:[[expectedHash uppercaseString] isEqualToString:result]?[NSImage imageNamed:@"button_ok"]:[NSImage imageNamed:@"button_cancel"],
                                        file, [expectedHash uppercaseString], result, nil]
                       forKeys:[newEntry defaultKeys]];
        else
            newDict = [[NSMutableDictionary alloc]
                       initWithObjects:[NSArray arrayWithObjects:[NSImage imageNamed:@"button_ok"],
                                        file, result, result, nil]
                       forKeys:[newEntry defaultKeys]];

        [newEntry setProperties:newDict];
        [newDict release];

        // TODO: Make it possible to update records with the result
        //        [records addObject:newEntry];
        [target addRecordObject:newEntry];
        [newEntry release];
         */
	}
}

@end
