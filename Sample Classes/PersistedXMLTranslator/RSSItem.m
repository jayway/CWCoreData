// 
//  RSSItem.m
//  CWCoreData
//  Created by Fredrik Olsson 
//
//  Copyright (c) 2011, Jayway AB All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of Jayway AB nor the names of its contributors may 
//       be used to endorse or promote products derived from this software 
//       without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL JAYWAY AB BE LIABLE FOR ANY DIRECT, INDIRECT, 
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
//  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
//  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
//  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
//  OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
//  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "RSSItem.h"
#import "CWFoundation.h"
#import "CWCoreData.h"

@implementation RSSItem 

@dynamic date;
@dynamic title;
@dynamic URL;
@dynamic preamble;

+(void)showError:(NSError*)error;
{
	[[[[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                 message:[error localizedFailureReason]
                                delegate:nil
                       cancelButtonTitle:@"OK"
                       otherButtonTitles:nil] autorelease] show];
}

+(void)fetchRSSItemsFromURL:(NSURL*)url;
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSError* error = nil;
	NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
	NSLocale *locale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
	[formatter setLocale:locale];
	[formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss zzz"];
	
	[CWXMLTranslator setDefaultDateFormatter:formatter];
	[formatter release];
    NSArray* items = [CWXMLTranslator translateContentsOfURL:url
                                        withTranslationNamed:@"RSSFeed"
                                                    delegate:(id)self
                                                       error:&error];
    if (items) {
        CWLogDebug(@"Fetched %d new RSS items", [items count]);
		[[NSManagedObjectContext threadLocalContext] saveWithFailureOption:NSManagedObjectContextCWSaveFailureOptionThreadDefault
                                                                     error:NULL];
    } else {
    	[self performSelectorOnMainThread:@selector(showError:)
                               withObject:error
                            waitUntilDone:NO];
    }
    [pool release];
}

+(void)fetchRSSItemsInBackgroundFromURL:(NSURL*)url;
{
	[self performSelectorInBackground:@selector(fetchRSSItemsFromURL:) 
                           withObject:url];
}

-(NSString*)localizedDate;
{
    
	static NSDateFormatter* formatter = nil;
    if (formatter == nil) {
        formatter = [[NSDateFormatter alloc] init];
        [formatter setLocale:[NSLocale currentLocale]];
        [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss"];
    }
	return [formatter stringFromDate:self.date];    
}

#pragma mark --- CWXMLTranslatorDelegate conformance

+(id)translator:(CWTranslator*)translator didTranslateObject:(id)anObject fromSourceName:(NSString*)name toKeyPath:(NSString*)key ontoObject:(id)parentObject context:(NSString*)context;
{
	if ([name isEqualToString:@"item"]) {
        NSManagedObjectContext* context = [NSManagedObjectContext threadLocalContext];
        NSPredicate* uniquePredicate = [NSPredicate predicateWithFormat:@"%K == %@", @"URL", [anObject objectForKey:@"URL"]];
		RSSItem* item = [context fetchUniqueObjectForEntityName:@"RSSItem"
                                                  withPredicate:uniquePredicate];
        if (item) {
            // RSSItem already exists
            if ([item.date isEqualToDate:[anObject objectForKey:@"date"]]) {
                // Not updated
        		return nil;
            } else {
                // Updated item
                [item setValuesForKeysWithDictionary:anObject];
                return item;
            }
        } else {
            // Create new item, and return as part of translation.
        	item = [NSEntityDescription insertNewObjectForEntityForName:@"RSSItem"];
            [item setValuesForKeysWithDictionary:anObject];
            return item;
        }
    }
    return anObject;
}


@end
