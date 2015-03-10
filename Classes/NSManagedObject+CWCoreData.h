//
//  NSManagedObject+CWInvoke.h
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

#import <CoreData/CoreData.h>
#import "NSInvocation+CWVariableArguments.h"

/*!
 * @abstract Convinience category for performing making a NSManagedObject perform selectors 
 *           on different threads using the correct thread local NSManagedObjectContext.
 *
 * @discussion The NSManagedObject must be saved on the origin thread local context before
 *			   it can perform selectors on different threads.
 */
@interface NSManagedObject (CWCoreData)

/*!
 * @abstract Gett the thread local self for this managed object
 */
@property (NS_NONATOMIC_IOSONLY, readonly, strong) id threadLocalSelf;

/*!
 * @abstract Query if the managed object has a temporary object ID.
 */
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL hasTemporaryObjectID;

/*!
 * @abstract Rollback all changes since last fetch or save. Will turn object into a fault.
 */
- (void)rollback;

/*!
 * @abstract Merge all changed values in other managed object into the receiver.
 */
- (void)mergeChangedValuesFromManagedObject:(NSManagedObject*)otherObject;

- (void)performSelector:(SEL)aSelector onThread:(NSThread *)thread withObject:(id)arg waitUntilDone:(BOOL)wait;
- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(id)arg waitUntilDone:(BOOL)wait;

@end


/*!
 * @abstract Comvinience category on NSInvication for handling invocations with 
 *           thread safe managed objects.
 *
 * @discussion Thread safety is ensured by only replace any NSManagedObject target or
 *			   argument with their NSManagedObjectID before passing thread boundries.
 *			   All NSManagedObjectID targets and arguments are then replaced by their
 *			   NSManagedObject from the target threads local managed context.
 *             It is NOT possible to pass unsaved managed objects over thread boundries.
 *             It is NOT possible to send NSManagedObjectID instances withour replacements 
 *             over thread boundries.
 */
@interface NSInvocation (CWCoreData)

-(void)invokeWithManagedObjectsOnMainThreadWaitUntilDone:(BOOL)wait;
-(void)invokeWithManagedObjectsOnThread:(NSThread*)thread waitUntilDone:(BOOL)wait;

-(void)invokeWithManagedObjectsOnDefaultQueueWaitUntilDone:(BOOL)wait;
-(void)invokeWithManagedObjectsOnOperationQueue:(NSOperationQueue*)queue waitUntilDone:(BOOL)wait;

@end