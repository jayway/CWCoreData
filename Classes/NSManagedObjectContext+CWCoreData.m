//
//  NSManagedObjectContext+CWAdditions.m
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

#import "NSManagedObjectContext+CWCoreData.h"
#import "NSPersistentStoreCoordinator+CWCoreData.h"
#import "NSFetchRequest+CWCoreData.h"


@implementation NSManagedObjectContext (CWCoreData)

static NSMutableDictionary* _managedObjectContexts = nil;

+ (NSMutableDictionary*) managedObjectContexts
{
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _managedObjectContexts = [[NSMutableDictionary alloc] initWithCapacity:4];
    });

    return _managedObjectContexts;
}

+ (NSValue*)threadKey;
{
	return [NSValue valueWithPointer:[NSThread currentThread]];
}

+ (BOOL)hasThreadLocalContext;
{
	return [NSManagedObjectContext managedObjectContexts][[self threadKey]] != nil;    
}

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
+ (NSManagedObjectContext *)threadLocalContext;
{
    NSManagedObjectContext* context = nil;
    @synchronized([self class]) {
        NSValue* threadKey = [self threadKey];
        context = [NSManagedObjectContext managedObjectContexts][threadKey];
        
        if (context == nil) {
            NSNotificationCenter* defaultCenter = [NSNotificationCenter defaultCenter];
            NSPersistentStoreCoordinator *coordinator = [NSPersistentStoreCoordinator defaultCoordinator];
            context = [[NSManagedObjectContext alloc] init];
            [context setPersistentStoreCoordinator: coordinator];
			if ([[NSThread currentThread] isMainThread]) {
				[context setMergePolicy:NSErrorMergePolicy];
			} else {
				[context setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
			}


            [defaultCenter addObserver:self
                              selector:@selector(threadWillExit:) 
                                  name:NSThreadWillExitNotification 
                                object:[NSThread currentThread]];
            [NSManagedObjectContext managedObjectContexts][threadKey] = context;
            [defaultCenter addObserver:self 
                              selector:@selector(managedObjectContextDidSave:) 
                                  name:NSManagedObjectContextDidSaveNotification 
                                object:context];
            [context release];
            //NSLog(@"Did create thread local NSManagedObjectContext");
        }
    }
    return context;
}

+(void)removeThreadLocalContext;
{
	if ([self hasThreadLocalContext]) {
        NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter removeObserver:self 
                                      name:NSManagedObjectContextDidSaveNotification 
                                    object:[self threadLocalContext]];
        [[NSManagedObjectContext managedObjectContexts] removeObjectForKey:[self threadKey]];
        [notificationCenter removeObserver:self 
                                      name:NSThreadWillExitNotification 
                                    object:[NSThread currentThread]];
    }
}

+(void)threadWillExit:(NSNotification*)notification;
{
    @synchronized([self class]) {
        //NSLog(@"Will remove local NSManagedObjectContext on thread exit");
        [self removeThreadLocalContext];
    }
}

+(void)managedObjectContextDidSave:(NSNotification*)notification;
{
	for (NSValue* threadKey in [[NSManagedObjectContext managedObjectContexts] allKeys]) {
		NSThread* thread = (NSThread*)[threadKey pointerValue];
        if (thread != [NSThread currentThread]) {
			[self performSelector:@selector(mergeChangesFromContextDidSaveNotification:) 
                         onThread:thread 
                       withObject:notification 
                    waitUntilDone:NO];
        }
    }
}

+(void)mergeChangesFromContextDidSaveNotification:(NSNotification*)notification;
{
    NSDictionary* userInfo = [notification userInfo];
/*    NSInteger insertCount = [[userInfo objectForKey:NSInsertedObjectsKey] count];*/
    //NSInteger updateCount = [[userInfo objectForKey:NSUpdatedObjectsKey] count];
    /*NSInteger deleteCount = [[userInfo objectForKey:NSDeletedObjectsKey] count];*/
    //NSLog(@"Will merge changes to local NSManagedObjectContext (%d inserts, %d updates, %d deletes). ", insertCount, updateCount, deleteCount);
    NSManagedObjectContext* context = [self threadLocalContext];
	[context mergeChangesFromContextDidSaveNotification:notification];
}


-(BOOL)isThreadLocalContext;
{
	NSArray* keys = [[NSManagedObjectContext managedObjectContexts] allKeysForObject:self];
    return [[NSManagedObjectContext threadKey] isEqual:[keys lastObject]];
}

-(BOOL)saveWithFailureOption:(NSManagedObjectContextCWSaveFailureOption)option error:(NSError**)error;
{
	if ([self hasChanges]) {
        NSError* localError = nil;
    	if (![self save:&localError]) {
            if (error) {
            	*error = localError;
            }
            if (option == NSManagedObjectContextCWSaveFailureOptionThreadDefault) {
            	option = [NSThread isMainThread] ? NSManagedObjectContextCWSaveFailureOptionRollback : NSManagedObjectContextCWSaveFailureOptionReset;
            }
        	switch (option) {
            	case NSManagedObjectContextCWSaveFailureOptionRollback:
                    NSLog(@"Did rollback context for error: %@", localError);
                    [self rollback];
                    break;
                case NSManagedObjectContextCWSaveFailureOptionReset:
                    NSLog(@"Did reset context for error: %@", localError);
                    [self reset];
                    break;
                case NSManagedObjectContextCWSaveFailureOptionRemove:
                	if ([self isThreadLocalContext]) {
                        NSLog(@"Did remove context for error: %@", localError);
                    	[NSManagedObjectContext removeThreadLocalContext];
                    } else {
                    	NSLog(@"Could not remove context for error: %@\n%@ is not the thread local context.", localError, self);
                    }
                    break;
            }
            return NO;
        }
    }
    return YES;
}

#pragma mark --- Managing objects

-(id)insertNewUniqueObjectForEntityForName:(NSString*)entityName withPredicate:(NSPredicate*)predicate;
{
    id object = [self fetchUniqueObjectForEntityName:entityName withPredicate:predicate];
    if (object == nil) {
	    return [NSEntityDescription insertNewObjectForEntityForName:entityName
                                             inManagedObjectContext:self];
    }
    return object;
}

-(id)fetchUniqueObjectForEntityName:(NSString*)entityName withPredicate:(NSPredicate*)predicate;
{
	NSArray* objects = [self objectsForEntityName:entityName withPredicate:predicate sortDescriptors:nil];
	if (objects) {
		switch ([objects count]) {
            case 0:
                break;
            case 1:
                return [objects lastObject];
            default:
                [NSException raise:NSInternalInconsistencyException
                            format:@"%@ (%@) should be unique, but exist as %d objects", entityName, predicate, [objects count]];
        }
    }
    return nil;
}

-(BOOL)deleteUniqueObjectForEntityName:(NSString*)entityName predicate:(NSPredicate*)predicate;
{
	id object = [self fetchUniqueObjectForEntityName:entityName withPredicate:predicate];
	if (object != nil) {
		[self deleteObject:object];
		return YES;
	}
	return NO;
}

-(NSUInteger)objectCountForEntityName:(NSString*)entityName withPredicate:(NSPredicate*)predicate;
{
    NSFetchRequest* request = [NSFetchRequest requestForEntityName:entityName
                                                     withPredicate:predicate
                                                   sortDescriptors:nil];
    NSError* error = nil;
    NSUInteger count = [self countForFetchRequest:request error:&error];
	if (error) {
        NSLog(@"%@", error);
    }
    return count;
}

-(NSArray*)objectsForEntityName:(NSString*)entityName withPredicate:(NSPredicate*)predicate sortDescriptors:(NSArray*)sortDescriptors;
{
    NSFetchRequest* request = [NSFetchRequest requestForEntityName:entityName
                                                     withPredicate:predicate
                                                   sortDescriptors:sortDescriptors];
    NSError* error = nil;
    NSArray* objects = [self executeFetchRequest:request error:&error];
    if (error) {
        NSLog(@"%@", error);
    }
    return objects;
}

@end
