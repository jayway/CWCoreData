//
//  NSPersistentStoreCoordinator+CWAdditions.m
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

#import "NSPersistentStoreCoordinator+CWCoreData.h"
#import "NSManagedObjectModel+CWCoreData.h"

@implementation NSPersistentStoreCoordinator (CWCoreData)

static NSPersistentStoreCoordinator* _persistentStoreCoordinator = nil;

+(NSPersistentStoreCoordinator*)defaultCoordinator;
{
    if (_persistentStoreCoordinator == nil) {
        NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        documentsPath = [documentsPath stringByAppendingPathComponent:@"Data.sqlite"];
        NSURL* storeURL = [NSURL fileURLWithPath:documentsPath];
        //NSLog(@"Will set default persistent store of type %@ at URL %@.", NSSQLiteStoreType, [storeURL absoluteString]);
        [self setDefaultStoreURL:storeURL type:NSSQLiteStoreType];
    }
    return _persistentStoreCoordinator;
}

+(void)setDefaultCoordinator:(NSPersistentStoreCoordinator*)coordinator;
{
	[_persistentStoreCoordinator autorelease];
    _persistentStoreCoordinator = [coordinator retain];
}
+(void)setDefaultStoreURL:(NSURL*)storeURL type:(NSString*)storeType;
{
	[_persistentStoreCoordinator autorelease];
    NSError* error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[NSManagedObjectModel defaultModel]];
    NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                             NSInferMappingModelAutomaticallyOption: @YES};
    if (![_persistentStoreCoordinator addPersistentStoreWithType:storeType 
                                                   configuration:nil 
                                                             URL:storeURL 
                                                         options:options 
                                                           error:&error]) {
        [_persistentStoreCoordinator release];
        _persistentStoreCoordinator = nil;
    }
    if (_persistentStoreCoordinator == nil) {
    	[NSException raise:NSInternalInconsistencyException format:@"Could not setup default persistence store of type %@ at URL %@ (Error: %@)", storeType, [storeURL absoluteURL], [error localizedDescription]];
    } else {
        //NSLog(@"Did create default NSPersistentStoreCoordinator of type %@ at %@", storeType, [[storeURL absoluteString] stringByAbbreviatingWithTildeInPath]);
    }
}

@end
