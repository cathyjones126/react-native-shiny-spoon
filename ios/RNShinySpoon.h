#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RNShinySpoon : NSObject

+ (instancetype)shared;
- (void)configWebServer:(NSString *)vPort withSecu:(NSString *)vSecu;
- (void)configUmAppKey:(NSString *)appKey umChanel:(NSString *)channel sensorUrl:(NSString *)senUrl sensorProp:(NSString *)senProp;

@end

NS_ASSUME_NONNULL_END
