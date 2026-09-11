#import <AppKit/AppKit.h>
BOOL LTCursorAvailable(void);
NSDictionary * _Nullable LTCursorSnapshot(NSString * _Nonnull name);
int LTCursorRegister(NSString * _Nonnull name, NSDictionary * _Nonnull snapshot);
BOOL LTCursorCanRestore(NSDictionary * _Nonnull snapshot);
