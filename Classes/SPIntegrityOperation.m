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
	@autoreleasepool {

    NSLog(@"Running for file %@", [[fileEntry properties] objectForKey:@"filepath"]);

	if (![self isCancelled])
	{
        SPCryptoAlgorithm algorithm;
        uint8_t *dgst; // buffers
        
        NSString *file = [[fileEntry properties] objectForKey:@"filepath"];
        NSString *expectedHash = [[fileEntry properties] objectForKey:@"expected"];

        NSFileManager *dm = [NSFileManager defaultManager];
        NSDictionary *fileAttributes = [dm attributesOfItemAtPath:file error:NULL];


        if (cryptoAlgorithm == SPCryptoAlgorithmUnknown)
        {
            switch ([expectedHash length])
            {
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
        }
        else
        {
            algorithm = cryptoAlgorithm;
        }
		
		NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:file];
		
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

        crc32_t crc;
        MD5_CTX md5_ctx;
        SHA_CTX sha_ctx;
        
        switch (algorithm) {
            case SPCryptoAlgorithmCRC:
                crc = crc32(0L,Z_NULL,0);
                break;
                
            case SPCryptoAlgorithmMD5:
                MD5_Init(&md5_ctx);
                break;
                
            case SPCryptoAlgorithmSHA1:
                SHA1_Init(&sha_ctx);
                
                break;
                
            default:
                break;
        }
		
		NSData *fileData = nil;
		
        while ((fileData = [fileHandle readDataOfLength:1024]).length > 0) {
            if ([self isCancelled])
                break;
            
            switch (algorithm) {
                case SPCryptoAlgorithmCRC:
                    crc = crc32(crc, fileData.bytes, fileData.length);
                    break;
                case SPCryptoAlgorithmMD5:
                    MD5_Update(&md5_ctx, fileData.bytes, fileData.length);
                    break;
                case SPCryptoAlgorithmSHA1:
                    SHA1_Update(&sha_ctx, fileData.bytes, fileData.length);
                    break;
            }
        }
		fileHandle = nil;
		NSLog(@"Finished with file %@", [[fileEntry properties] objectForKey:@"filepath"]);
        

        if ([self isCancelled])
            return;
        
        if (algorithm == SPCryptoAlgorithmCRC) {
            hash = [[NSString stringWithFormat:@"%08x", crc] uppercaseString];
        } else {
            hash = @"";
            dgst = (uint8_t *) calloc (((algorithm == 1)?32:40), sizeof(uint8_t));
            
            switch (algorithm) {
                case SPCryptoAlgorithmSHA1:
                    SHA1_Final(dgst,&sha_ctx);
                    break;
                    
                case SPCryptoAlgorithmMD5:
                    MD5_Final(dgst,&md5_ctx);
                    break;
                    
                default:
                    break;
            }
            
            for (int i = 0; i < ((algorithm == SPCryptoAlgorithmMD5)?16:20); i++)
                hash = [[[self hashString] stringByAppendingFormat:@"%02x", dgst[i]] uppercaseString];
            
            free(dgst);
        }
        
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
}

@end
