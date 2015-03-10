//
//  NSManagedObjectContext+CWAdditions.h
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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

typedef NS_ENUM(NSInteger, NSManagedObjectContextCWSaveFailureOption) {
    NSManagedObjectContextCWSaveFailureOptionNone,		// Do nothing on save error
    NSManagedObjectContextCWSaveFailureOptionThreadDefault,   // Rollback on main thread, reset on background threads.
    NSManagedObjectContextCWSaveFailureOptionRollback,  // Rollback context and objects on error
    NSManagedObjectContextCWSaveFailureOptionReset,     // Reset context, invalidating objects on error
    NSManagedObjectContextCWSaveFailureOptionRemove     // Remove context, invalidating objects on error
} ;

/*!
 * @abstract Convinience category for accessing a default thread local NSManagedObjectContext.
 *
 * @discussion Thread local contexts are created when first requested, and removed automatically
 *             when the thread exits.
 *             Saving a thread local context will automatically merge it's changes to any other
 *             currently existing thread local context.
 */
@interface NSManagedObjectContext (CWCoreData)

/*!
 * @abstract Query if the current thread has thread local context.
 */
+(BOOL)hasThreadLocalContext;

/*!
 * @abstract Get the current thread's thread local context. Lazily create the context if it do not exist.
 */
+(NSManagedObjectContext*)threadLocalContext;

/*!
 * @abstract Explicitly remove this thread's local context.
 */
+(void)removeThreadLocalContext;


@property (NS_NONATOMIC_IOSONLY, getter=isThreadLocalContext, readonly) BOOL threadLocalContext;

/*!
 * @abstract Call save:, 
 */
-(BOOL)saveWithFailureOption:(NSManagedObjectContextCWSaveFailureOption)option error:(NSError**)error;

-(id)insertNewUniqueObjectForEntityForName:(NSString*)entityName withPredicate:(NSPredicate*)predicate;
-(id)fetchUniqueObjectForEntityName:(NSString*)entityName withPredicate:(NSPredicate*)predicate;
-(BOOL)deleteUniqueObjectForEntityName:(NSString*)entityName predicate:(NSPredicate*)predicate;

-(NSUInteger)objectCountForEntityName:(NSString*)entityName withPredicate:(NSPredicate*)predicate;
-(NSArray*)objectsForEntityName:(NSString*)entityName withPredicate:(NSPredicate*)predicate sortDescriptors:(NSArray*)sortDescriptors;

@end
