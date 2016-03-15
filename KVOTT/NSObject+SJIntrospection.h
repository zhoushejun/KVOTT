//
//  NSObject+SJIntrospection.h
//  KVOTT
//
//  Created by shejun.zhou on 15/12/26.
//  Copyright © 2015年 shejun.zhou. All rights reserved.
//

/**
 @file       NSObject+SJIntrospection.h
 @abstract  封装了打印一个类的方法、属性、协议等常用调试方法
 @author    shejun.zhou
 @version   1.0 15/12/26 Creation
 */
#import <Foundation/Foundation.h>

@interface NSObject (SJIntrospection)

/**  */
+ (NSArray *)classes;

/**  */
+ (NSArray *)properties;

/**  */
+ (NSArray *)instanceVariables;

/**  */
+ (NSArray *)classMethods;

/**  */
+ (NSArray *)instanceMethods;

/**  */
+ (NSArray *)protocols;

/**  */
+ (NSDictionary *)descriptionForProtocol:(Protocol *)proto;

/**  */
+ (NSString *)parentClassHierarchy;

@end
