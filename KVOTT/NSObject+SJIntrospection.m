//
//  NSObject+SJIntrospection.m
//  KVOTT
//
//  Created by shejun.zhou on 15/12/26.
//  Copyright © 2015年 shejun.zhou. All rights reserved.
//

#import "NSObject+SJIntrospection.h"
#import <objc/runtime.h>

@interface NSString (SJIntrospection)

+ (NSString *)decodeType:(const char *)cString;

@end


@implementation NSString (SJIntrospection)
/**
 * https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
 * http://www.cnblogs.com/tangbinblog/archive/2012/08/24/2654154.html
 * http://blog.csdn.net/jeff_njut/article/details/38844003
 */
+ (NSString *)decodeType:(const char *)cString {
    if (!strcmp(cString, @encode(id))) return @"id";
    if (!strcmp(cString, @encode(void))) return @"void";
    if (!strcmp(cString, @encode(float))) return @"float";
    if (!strcmp(cString, @encode(int))) return @"int";
    if (!strcmp(cString, @encode(BOOL))) return @"BOOL";
    if (!strcmp(cString, @encode(char *))) return @"char *";
    if (!strcmp(cString, @encode(double))) return @"double";
    if (!strcmp(cString, @encode(Class))) return @"class";
    if (!strcmp(cString, @encode(SEL))) return @"SEL";
    if (!strcmp(cString, @encode(unsigned int))) return @"unsigned int";
    
    //@TODO: do handle bitmasks
    NSString *result = [NSString stringWithCString:cString encoding:NSUTF8StringEncoding];
    if ([[result substringToIndex:1] isEqualToString:@"@"] &&
        [result rangeOfString:@"?"].location == NSNotFound) {
        result = [[result substringWithRange:NSMakeRange(2, result.length - 3)] stringByAppendingString:@"*"];
    } else if ([[result substringToIndex:1] isEqualToString:@"^"]) {
        result = [NSString stringWithFormat:@"%@ *", [NSString decodeType:[[result substringFromIndex:1] cStringUsingEncoding:NSUTF8StringEncoding]]];
    }
    return result;
}

@end

static void getSuper(Class class, NSMutableString *result) {
    [result appendFormat:@" -> %@", NSStringFromClass(class)];
    if ([class superclass]) {
        getSuper([class superclass], result);
    }
}

#pragma mark - SNObject SJIntrospection

@implementation NSObject (SJIntrospection)

/**  */
+ (NSArray *)classes {
    unsigned int count = 0;
    Class *classList = objc_copyClassList(&count);
    NSMutableArray *classes = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        [classes addObject:NSStringFromClass(classList[i])];
    }
    return  [classes sortedArrayUsingSelector:@selector(compare:)];
}

/**  */
+ (NSArray *)properties {
    unsigned int count = 0;
    objc_property_t *propertyList = class_copyPropertyList([self class], &count);
    NSMutableArray *properties = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        [properties addObject:[self formattedPropery:propertyList[i]]];
    }
    free(propertyList);
    return properties.count ? [properties copy] : nil;
}

/**  */
+ (NSArray *)instanceVariables {
    unsigned int count = 0;
    Ivar *ivarList = class_copyIvarList([self class], &count);
    NSMutableArray *ivars = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        NSString *type = [NSString decodeType:ivar_getTypeEncoding(ivarList[i])];
        NSString *name = [NSString stringWithCString:ivar_getName(ivarList[i]) encoding:NSUTF8StringEncoding];
        NSString *ivarDescription = [NSString stringWithFormat:@"%@:%@", type, name];
        [ivars addObject:ivarDescription];
    }
    free(ivarList);
    return ivars.count ? [ivars copy] : nil;
}

/**  */
+ (NSArray *)classMethods {
    
    return [self methodsForClass:[self class] typeFormat:@"+"];
}

/**  */
+ (NSArray *)instanceMethods {
    
    return [self methodsForClass:[self class] typeFormat:@"-"];
}

/**  */
+ (NSArray *)protocols {
    unsigned int count = 0;
    Protocol * const *protocolList = class_copyProtocolList([self class], &count);
    NSMutableArray *protocols = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        unsigned int adoptedCount = 0;
        Protocol * const * adotedProtocolList = protocol_copyProtocolList(protocolList[i], &adoptedCount);
        NSString *protocolName = [NSString stringWithCString:protocol_getName(protocolList[i]) encoding:NSUTF8StringEncoding];
        NSMutableArray *adoptedProtocolNames = [NSMutableArray array];
        for (int idx = 0; idx < adoptedCount; idx++) {
            NSString *adoptedProtocolName = [NSString stringWithCString:protocol_getName(adotedProtocolList[idx]) encoding:NSUTF8StringEncoding];
            [adoptedProtocolNames addObject:adoptedProtocolName];
        }
        NSString *protocolDescriiption = protocolName;
        if (adoptedProtocolNames.count) {
            protocolDescriiption = [NSString stringWithFormat:@"%@ <%@>", protocolName, [adoptedProtocolNames componentsJoinedByString:@", "]];
        }
        [protocols addObject:protocolDescriiption];
        free((__bridge void *)(*adotedProtocolList));
    }
    free((__bridge void *)(*protocolList));
    return protocols.count ? [protocols copy] : nil;
}

/**  */
+ (NSDictionary *)descriptionForProtocol:(Protocol *)proto {
    NSMutableDictionary *methodsAndProperties = [NSMutableDictionary dictionary];
    NSArray *requiredMethods = [[[self class] formattedMethodsForProtocol:proto required:YES instance:NO] arrayByAddingObjectsFromArray:[[self class] formattedMethodsForProtocol:proto required:YES instance:YES]];
    NSArray *optionalMethods = [[[self class] formattedMethodsForProtocol:proto required:NO instance:NO] arrayByAddingObjectsFromArray:[[self class] formattedMethodsForProtocol:proto required:NO instance:YES]];
    
    unsigned int count = 0;
    NSMutableArray *propertyDescriptions = [NSMutableArray array];
    objc_property_t *properties = protocol_copyPropertyList(proto, &count);
    for (int i = 0; i < count; i++) {
        [propertyDescriptions addObject:[self formattedPropery:properties[i]]];
    }
    
    if (requiredMethods.count) {
        [methodsAndProperties setObject:requiredMethods forKey:@"required"];
    }
    if (optionalMethods.count) {
        [methodsAndProperties setObject:optionalMethods forKey:@"optional"];
    }
    if (propertyDescriptions.count) {
        [methodsAndProperties setObject:propertyDescriptions forKey:@"properties"];
    }
    free(properties);
    return methodsAndProperties.count ? [methodsAndProperties copy] : nil;
}

/**  */
+ (NSString *)parentClassHierarchy{
    NSMutableString *classes = [NSMutableString string];
    getSuper([self class], classes);
    return classes;
}


#pragma mark - Private

+ (NSArray *)methodsForClass:(Class)class typeFormat:(NSString *)type {
    unsigned int count;
    Method *methods = class_copyMethodList(class, &count);
    NSMutableArray *result = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        NSString *methodDescription = [NSString stringWithFormat:@"%@ (%@)%@",
                                       type,
                                       [NSString decodeType:method_copyReturnType(methods[i])],
                                       NSStringFromSelector(method_getName(methods[i]))];
        
        NSInteger args = method_getNumberOfArguments(methods[i]);
        NSMutableArray *selParts = [[methodDescription componentsSeparatedByString:@":"] mutableCopy];
        int offset = 2; //1-st arg is object (@), 2-nd is SEL (:)
        
        for (int idx = offset; idx < args; idx++) {
            NSString *returnType = [NSString decodeType:method_copyArgumentType(methods[i], idx)];
            selParts[idx - offset] = [NSString stringWithFormat:@"%@:(%@)arg%d",
                                      selParts[idx - offset],
                                      returnType,
                                      idx - 2];
        }
        [result addObject:[selParts componentsJoinedByString:@" "]];
    }
    free(methods);
    return result.count ? [result copy] : nil;
}

+ (NSArray *)formattedMethodsForProtocol:(Protocol *)proto required:(BOOL)required instance:(BOOL)instance {
    unsigned int methodCount;
    struct objc_method_description *methods = protocol_copyMethodDescriptionList(proto, required, instance, &methodCount);
    NSMutableArray *methodsDescription = [NSMutableArray array];
    for (int i = 0; i < methodCount; i++) {
        [methodsDescription addObject:
         [NSString stringWithFormat:@"%@ (%@)%@",
          instance ? @"-" : @"+",
#warning return correct type
          @"void",
          NSStringFromSelector(methods[i].name)]];
    }
    
    free(methods);
    return  [methodsDescription copy];
}

+ (NSString *)formattedPropery:(objc_property_t)prop {
    unsigned int attrCount;
    objc_property_attribute_t *attrs = property_copyAttributeList(prop, &attrCount);
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    for (int idx = 0; idx < attrCount; idx++) {
        NSString *name = [NSString stringWithCString:attrs[idx].name encoding:NSUTF8StringEncoding];
        NSString *value = [NSString stringWithCString:attrs[idx].value encoding:NSUTF8StringEncoding];
        [attributes setObject:value forKey:name];
    }
    free(attrs);
    NSMutableString *property = [NSMutableString stringWithFormat:@"@property "];
    NSMutableArray *attrsArray = [NSMutableArray array];
    [attrsArray addObject:[attributes objectForKey:@"N"] ? @"nonatomic" : @"atomic"];
    
    if ([attributes objectForKey:@"&"]) {
        [attrsArray addObject:@"strong"];
    } else if ([attributes objectForKey:@"C"]) {
        [attrsArray addObject:@"copy"];
    } else if ([attributes objectForKey:@"W"]) {
        [attrsArray addObject:@"weak"];
    } else {
        [attrsArray addObject:@"assign"];
    }
    if ([attributes objectForKey:@"R"]) {[attrsArray addObject:@"readonly"];}
    if ([attributes objectForKey:@"G"]) {
        [attrsArray addObject:[NSString stringWithFormat:@"getter=%@", [attributes objectForKey:@"G"]]];
    }
    if ([attributes objectForKey:@"S"]) {
        [attrsArray addObject:[NSString stringWithFormat:@"setter=%@", [attributes objectForKey:@"G"]]];
    }
    
    [property appendFormat:@"(%@) %@ %@",
     [attrsArray componentsJoinedByString:@", "],
     [NSString decodeType:[[attributes objectForKey:@"T"] cStringUsingEncoding:NSUTF8StringEncoding]],
     [NSString stringWithCString:property_getName(prop) encoding:NSUTF8StringEncoding]];
    return [property copy];
}

@end
