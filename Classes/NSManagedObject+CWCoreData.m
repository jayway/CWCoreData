//
//  NSManagedObject+CWInvoke.m
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

#import "CWCoreData.h"
#import "NSOperationQueue+CWDefaultQueue.h"

@implementation NSManagedObject (CWCoreData)

- (id)threadLocalSelf;
{
	NSManagedObjectContext* context = [NSManagedObjectContext threadLocalContext];
    if (self.managedObjectContext == context) {
        return self;
    }
    
    NSError *error = nil;
    
    if ([[self objectID] isTemporaryID])
    {
        if (![self.managedObjectContext obtainPermanentIDsForObjects:@[self] error:&error])
        {
            [NSException raise:NSInternalInconsistencyException format:@"Can not get thread local self for an unsaved managed object from another thread."];
            return nil;
        }
    }
    
    error = nil;
    NSManagedObject *inContext = [context existingObjectWithID:[self objectID] error:&error];
    if (error)
    {
        [NSException raise:NSInternalInconsistencyException format:@"Can not get thread local self for an unsaved managed object from another thread."];
        return nil;
    }
    
    return inContext;
}

- (BOOL)hasTemporaryObjectID;
{
    return [[self objectID] isTemporaryID];
}

- (void)rollback;
{
	[[NSManagedObjectContext threadLocalContext] refreshObject:self 
                                                  mergeChanges:NO];    
}

- (void)mergeChangedValuesFromManagedObject:(NSManagedObject*)otherObject;
{
	NSDictionary* changes = [otherObject changedValues];
    [self setValuesForKeysWithDictionary:changes];
}

- (void)performSelector:(SEL)aSelector onThread:(NSThread *)thread withObject:(id)arg waitUntilDone:(BOOL)wait;
{
    NSInvocation* invocation =  [NSInvocation invocationWithTarget:self
                                                          selector:aSelector
                                                   retainArguments:YES, arg]; 
    [invocation invokeWithManagedObjectsOnThread:thread
                                   waitUntilDone:wait];    
}

- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(id)arg waitUntilDone:(BOOL)wait;
{
	[self performSelector:aSelector onThread:[NSThread mainThread] withObject:arg waitUntilDone:wait];
}

@end


@implementation NSInvocation (CWCoreData)

-(void)replaceManagedObjectsWithObjectIDs;
{
    id target = [self target];
	if ([target isKindOfClass:[NSManagedObject class]]) {
    	[self setTarget:[target objectID]];
    }
    NSMethodSignature* signature = [self methodSignature];
    for (int argIndex = 2; argIndex < [signature numberOfArguments]; argIndex++) {
    	if (strcmp([signature getArgumentTypeAtIndex:argIndex], @encode(id)) == 0) {
        	id arg = nil;
            [self getArgument:&arg atIndex:argIndex];
            if ([arg isKindOfClass:[NSManagedObject class]]) {
                if ([arg hasTemporaryObjectID]) {
                	[NSException raise:NSInvalidArgumentException 
                                format:@"%@ has temporary object ID.", arg];
                }
				arg = [arg objectID];
            	[self setArgument:&arg atIndex:argIndex];
            }
        }
    }
}

-(void)replaceObjectIDsWithManagedObjects;
{
    NSManagedObjectContext* context = [NSManagedObjectContext threadLocalContext];
    id target = [self target];
	if ([target isKindOfClass:[NSManagedObjectID class]]) {
    	[self setTarget:[context objectWithID:target]];
    }
    NSMethodSignature* signature = [self methodSignature];
    for (int argIndex = 2; argIndex < [signature numberOfArguments]; argIndex++) {
    	if (strcmp([signature getArgumentTypeAtIndex:argIndex], @encode(id)) == 0) {
        	id arg = nil;
            [self getArgument:&arg atIndex:argIndex];
            if ([arg isKindOfClass:[NSManagedObjectID class]]) {
				arg = [context objectWithID:arg];
            	[self setArgument:&arg atIndex:argIndex];
            }
        }
    }
}

-(void)invokeInvocationWithManagedObjects:(NSInvocation*)invocation;
{
	[invocation replaceObjectIDsWithManagedObjects];
    [invocation invoke];
}

-(void)invokeWithManagedObjectsOnMainThreadWaitUntilDone:(BOOL)wait;
{
	[self invokeWithManagedObjectsOnThread:[NSThread mainThread] waitUntilDone:wait];    
}

-(void)invokeWithManagedObjectsOnThread:(NSThread*)thread waitUntilDone:(BOOL)wait;
{
    if (thread == [NSThread currentThread]) {
        [self invoke];
    } else {
        [self replaceManagedObjectsWithObjectIDs];
        NSInvocation* invocation = [NSInvocation invocationWithTarget:self
                                                             selector:@selector(invokeInvocationWithManagedObjects:)
                                                      retainArguments:YES, self];
        [invocation invokeOnThread:thread
                     waitUntilDone:wait];
    }
}

-(void)invokeWithManagedObjectsOnDefaultQueueWaitUntilDone:(BOOL)wait;
{
	[self invokeWithManagedObjectsOnOperationQueue:[NSOperationQueue defaultQueue] waitUntilDone:wait];    
}

-(void)invokeWithManagedObjectsOnOperationQueue:(NSOperationQueue*)queue waitUntilDone:(BOOL)wait;
{
    [self replaceManagedObjectsWithObjectIDs];
    NSInvocation* invocation = [NSInvocation invocationWithTarget:self
                                                         selector:@selector(invokeInvocationWithManagedObjects:)
                                                  retainArguments:YES, self];
    [invocation invokeOnOperationQueue:queue 
                         waitUntilDone:wait];
}

@end