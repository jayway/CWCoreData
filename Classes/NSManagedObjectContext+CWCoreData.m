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
#import "CWLog.h"

static NSString * const CWContextWorkingName = @"CWContextWorkingName";


@implementation NSManagedObjectContext (CWCoreData)

static NSManagedObjectContext *CWRootSavingContext;
static NSManagedObjectContext *CWDefaultContext;

static NSMutableDictionary* _managedObjectContexts = nil;

#pragma mark -
#pragma mark Old dangerous threading implementation

+ (NSMutableDictionary *)managedObjectContexts
{
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _managedObjectContexts = [NSMutableDictionary new];
    });
    
    return _managedObjectContexts;
}

+ (NSValue *)threadKey;
{
    return [NSValue valueWithPointer:[NSThread currentThread]];
}

+ (BOOL)hasThreadLocalContext;
{
    return [[NSManagedObjectContext managedObjectContexts] objectForKey:[self threadKey]] != nil;
}

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
+ (NSManagedObjectContext *)threadLocalContext;
{
    NSManagedObjectContext* context = nil;
    @synchronized([self class]) {
        if ([NSThread isMainThread]) {
            return [self CW_defaultContext];
        }
        
        // Threaded context
        NSValue* threadKey = [self threadKey];
        context = [[NSManagedObjectContext managedObjectContexts] objectForKey:threadKey];
        if (!context) {
            CWLogDebug(@"Creating threaded context with main queue context as parent");
            context = [self CW_contextWithParent:CWDefaultContext];
            [context setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
            [[NSManagedObjectContext managedObjectContexts] setObject:context forKey:threadKey];
        }
    }
    return context;
}

+ (void)removeThreadLocalContext;
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

+ (void)threadWillExit:(NSNotification*)notification;
{
    @synchronized([self class]) {
        //NSLog(@"Will remove local NSManagedObjectContext on thread exit");
        [self removeThreadLocalContext];
    }
}

- (BOOL)isThreadLocalContext;
{
    NSArray* keys = [[NSManagedObjectContext managedObjectContexts] allKeysForObject:self];
    return [[NSManagedObjectContext threadKey] isEqual:[keys lastObject]];
}

#pragma mark -

+ (void) CW_initializeDefaultContextWithCoordinator:(NSPersistentStoreCoordinator *)coordinator;
{
    NSAssert(coordinator, @"Provided coordinator cannot be nil!");
    if (!CWDefaultContext)
    {
        NSManagedObjectContext *rootContext = [self CW_contextWithStoreCoordinator:coordinator];
        [self CW_setRootSavingContext:rootContext];
        
        NSManagedObjectContext *defaultContext = [self CW_newMainQueueContext];
        [defaultContext setMergePolicy:NSErrorMergePolicy];
        
        [self CW_setDefaultContext:defaultContext];
        
        [defaultContext setParentContext:rootContext];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            NSManagedObjectContext *context = note.object;
            NSManagedObjectContext *parentContext = context.parentContext;
            if (parentContext == CWDefaultContext)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [parentContext mergeChangesFromContextDidSaveNotification:note];
                });
            }
            else {
                [parentContext mergeChangesFromContextDidSaveNotification:note];
            }
            
            if (parentContext == CWRootSavingContext) {
                [parentContext performBlock:^{
                    NSError *error;
                    if (![parentContext save:&error]) {
                        CWLogError(@"Save error: %@", error);
                    }
                }];
            }
        }];
    }
}

+ (NSManagedObjectContext *) CW_defaultContext
{
    @synchronized(self) {
        NSAssert(CWDefaultContext != nil, @"Default context is nil! Did you forget to initialize the Core Data Stack?");
        return CWDefaultContext;
    }
}

+ (NSManagedObjectContext *) CW_rootSavingContext;
{
    return CWRootSavingContext;
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

#pragma maek - Setters

+ (void) CW_setDefaultContext:(NSManagedObjectContext *)moc
{
    if (CWDefaultContext)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:CWDefaultContext];
    }
    
    CWDefaultContext = moc;
    [CWDefaultContext CW_setWorkingName:@"Default Context"];
    
//    if ((CWDefaultContext != nil) && ([self CW_rootSavingContext] != nil)) {
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(CW_rootContextDidSave:)
//                                                     name:NSManagedObjectContextDidSaveNotification
//                                                   object:[self CW_rootSavingContext]];
//    }
    
    [moc CW_obtainPermanentIDsBeforeSaving];

    CWLogInfo(@"Set default context: %@", CWMainContext);
}

+ (void)CW_setRootSavingContext:(NSManagedObjectContext *)context
{
    if (CWRootSavingContext)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:CWRootSavingContext];
    }
    
    CWRootSavingContext = context;
    
    [CWRootSavingContext performBlock:^{
        [CWRootSavingContext CW_obtainPermanentIDsBeforeSaving];
        [CWRootSavingContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        [CWRootSavingContext CW_setWorkingName:@"Root Saving Context"];
    }];
    
    CWLogInfo(@"Set root saving context: %@", CWRootSavingContext);
}

#pragma mark - Context creation

+ (NSManagedObjectContext *)CW_newMainQueueContext
{
    NSManagedObjectContext *context = [[self alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    CWLogInfo(@"Created new main queue context: %@", context);
    
    return context;
}

+ (NSManagedObjectContext *) CW_newPrivateQueueContext
{
    NSManagedObjectContext *context = [[self alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    CWLogInfo(@"Created new private queue context: %@", context);
    return context;
}

+ (NSManagedObjectContext *) CW_contextWithParent:(NSManagedObjectContext *)parentContext
{
    NSManagedObjectContext *context = [self CW_newPrivateQueueContext];
    [context setParentContext:parentContext];
    [context CW_obtainPermanentIDsBeforeSaving];
    return context;
}

+ (NSManagedObjectContext *) CW_contextWithStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator
{
    NSManagedObjectContext *context = [self CW_newPrivateQueueContext];
    [context performBlockAndWait:^{
        [context setPersistentStoreCoordinator:coordinator];
        CWLogDebug(@"Created new context %@ with store coordinator: %@", [context CW_workingName], coordinator);
    }];
    
    return context;
}

+ (NSManagedObjectContext *)mainThreadContext
{
    static NSManagedObjectContext *context = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [context setParentContext:[NSManagedObjectContext CW_rootSavingContext]];
        [context setMergePolicy:NSErrorMergePolicy];
        [context CW_obtainPermanentIDsBeforeSaving];
    });
    
    return context;
}

#pragma mark - Private methods

- (void) CW_obtainPermanentIDsBeforeSaving
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(CW_contextWillSave:)
                                                 name:NSManagedObjectContextWillSaveNotification
                                               object:self];
}

#pragma mark - Notification Handlers

- (void) CW_contextWillSave:(NSNotification *)notification
{
    NSManagedObjectContext *context = [notification object];
    NSSet *insertedObjects = [context insertedObjects];
    
    if ([insertedObjects count])
    {
        CWLogDebug(@"Context '%@' is about to save: obtaining permanent IDs for %lu new inserted object(s).", [context CW_workingName], (unsigned long)[insertedObjects count]);
        NSError *error = nil;
        BOOL success = [context obtainPermanentIDsForObjects:[insertedObjects allObjects] error:&error];
        if (!success)
        {
            CWLogError(@"Error: %@", error);
        }
    }
}

+ (void)CW_rootContextDidSave:(NSNotification *)notification
{
    if ([notification object] != [self CW_rootSavingContext])
    {
        return;
    }
    
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self CW_rootContextDidSave:notification];
        });
        
        return;
    }
    
    for (NSManagedObject *object in [[notification userInfo] objectForKey:NSUpdatedObjectsKey])
    {
        [[[self CW_defaultContext] objectWithID:[object objectID]] willAccessValueForKey:nil];
    }
    
    [[self CW_defaultContext] mergeChangesFromContextDidSaveNotification:notification];
}

#pragma mark - Debugging

- (void) CW_setWorkingName:(NSString *)workingName
{
    [[self userInfo] setObject:workingName forKey:CWContextWorkingName];
}

- (NSString *) CW_workingName
{
    NSString *workingName = [[self userInfo] objectForKey:CWContextWorkingName];
    
    if ([workingName length] == 0)
    {
        workingName = @"Untitled Context";
    }
    
    return workingName;
}

- (NSString *) CW_description
{
    NSString *onMainThread = [NSThread isMainThread] ? @"the main thread" : @"a background thread";
    
    __block NSString *workingName;
    
    [self performBlockAndWait:^{
        workingName = [self CW_workingName];
    }];
    
    return [NSString stringWithFormat:@"<%@ (%p): %@> on %@", NSStringFromClass([self class]), self, workingName, onMainThread];
}

- (NSString *) CW_parentChain
{
    NSMutableString *familyTree = [@"\n" mutableCopy];
    NSManagedObjectContext *currentContext = self;
    do
    {
        [familyTree appendFormat:@"- %@ (%p) %@\n", [currentContext CW_workingName], currentContext, (currentContext == self ? @"(*)" : @"")];
    }
    while ((currentContext = [currentContext parentContext]));
    
    return [NSString stringWithString:familyTree];
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
                            format:@"%@ (%@) should be unique, but exist as %lu objects", entityName, predicate, (unsigned long)[objects count]];
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
