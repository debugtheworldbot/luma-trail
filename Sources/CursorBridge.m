// Independent dynamic bridge to WindowServer cursor APIs documented by Mousecape.
#import "CursorBridge.h"
#import <dlfcn.h>
typedef int (*ConnectionFn)(void);
typedef int (*CopyFn)(int,const char *,CGSize *,CGPoint *,NSUInteger *,CGFloat *,CFArrayRef *);
typedef int (*RegisterFn)(int,const char *,bool,bool,CGSize,CGPoint,NSUInteger,CGFloat,CFArrayRef,int *);
static ConnectionFn connection;
static CopyFn copyImages;
static RegisterFn registerImages;
BOOL LTCursorAvailable(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
        connection = (ConnectionFn)dlsym(handle ?: RTLD_DEFAULT, "CGSMainConnectionID");
        copyImages = (CopyFn)dlsym(handle ?: RTLD_DEFAULT, "CGSCopyRegisteredCursorImages");
        registerImages = (RegisterFn)dlsym(handle ?: RTLD_DEFAULT, "CGSRegisterCursorWithImages");
    });
    return connection && copyImages && registerImages;
}
NSDictionary *LTCursorSnapshot(NSString *name) {
    if (!LTCursorAvailable()) return nil;
    CGSize size = CGSizeZero; CGPoint hot = CGPointZero;
    NSUInteger frames = 0; CGFloat duration = 0; CFArrayRef images = NULL;
    int result = copyImages(connection(), name.UTF8String, &size, &hot, &frames, &duration, &images);
    if (result || !images) { if(images) CFRelease(images); return nil; }
    NSMutableArray *data = [NSMutableArray array];
    for (id image in (__bridge NSArray *)images) {
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:(__bridge CGImageRef)image];
        NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        if(png) [data addObject:png];
    }
    CFRelease(images);
    if (!data.count || !frames || size.width <= 0 || size.height <= 0) return nil;
    return @{ @"images":data, @"width":@(size.width), @"height":@(size.height), @"x":@(hot.x), @"y":@(hot.y), @"frames":@(frames), @"duration":@(duration) };
}
static int registerSnapshot(NSString *name, NSDictionary *snapshot, bool globally, bool instantly) {
    if (!LTCursorAvailable()) return -1;
    NSMutableArray *images = [NSMutableArray array];
    for(NSData *data in snapshot[@"images"]) {
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:data];
        if(!rep.CGImage) return -2;
        [images addObject:(__bridge id)rep.CGImage];
    }
    if(!images.count) return -2;
    int seed = 0;
    return registerImages(connection(), name.UTF8String, globally, instantly,
        CGSizeMake([snapshot[@"width"] doubleValue], [snapshot[@"height"] doubleValue]),
        CGPointMake([snapshot[@"x"] doubleValue], [snapshot[@"y"] doubleValue]),
        [snapshot[@"frames"] unsignedIntegerValue], [snapshot[@"duration"] doubleValue],
        (__bridge CFArrayRef)images, &seed);
}

int LTCursorRegister(NSString *name, NSDictionary *snapshot) { return registerSnapshot(name,snapshot,true,true); }
BOOL LTCursorCanRestore(NSDictionary *snapshot) {
    // A connection-local registration validates the original without changing the visible cursor.
    return registerSnapshot(@"studio.luma.trail.restore-check", snapshot, false, false) == 0;
}
