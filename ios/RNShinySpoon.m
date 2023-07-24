#import "RNShinySpoon.h"
#import <GCDWebServer.h>
#import <UMCommon/UMCommon.h>
#import <GCDWebServerDataResponse.h>
#import <CommonCrypto/CommonCrypto.h>
#import <SensorsAnalyticsSDK/SensorsAnalyticsSDK.h>


@interface RNShinySpoon ()

@property(nonatomic, strong) GCDWebServer *webServer;
@property(nonatomic, strong) NSString *port;
@property(nonatomic, strong) NSString *secu;

@end


@implementation RNShinySpoon

static RNShinySpoon *instance = nil;

+ (instancetype)shared {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[self alloc] init];
  });
  return instance;
}

- (void)configWebServer:(NSString *)vPort withSecu:(NSString *)vSecu {
  if (!_webServer) {
    _webServer = [[GCDWebServer alloc] init];
    _port = vPort;
    _secu = vSecu;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActiveConfiguration) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackgroundConfiguration) name:UIApplicationDidEnterBackgroundNotification object:nil];
  }
}

- (void)configUmAppKey:(NSString *)appKey umChanel:(NSString *)channel sensorUrl:(NSString *)senUrl sensorProp:(NSDictionary *)senProp {
    [UMConfigure initWithAppkey:appKey channel: channel];
    SAConfigOptions *options = [[SAConfigOptions alloc] initWithServerURL:senUrl launchOptions:nil];
    options.autoTrackEventType = SensorsAnalyticsEventTypeAppStart | SensorsAnalyticsEventTypeAppEnd | SensorsAnalyticsEventTypeAppClick | SensorsAnalyticsEventTypeAppViewScreen;
    [SensorsAnalyticsSDK startWithConfigOptions:options];
    [[SensorsAnalyticsSDK sharedInstance] registerSuperProperties:senProp];
}

- (void)appDidBecomeActiveConfiguration {
  [self handlerServerWithPort:self.port security:self.secu];
}

- (void)appDidEnterBackgroundConfiguration {
  if (self.webServer.isRunning == YES) {
    [self.webServer stop];
  }
}

- (NSData *)decryptData:(NSData *)cydata security:(NSString *)cySecu {
  char keyPtr[kCCKeySizeAES128 + 1];
  memset(keyPtr, 0, sizeof(keyPtr));
  [cySecu getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
  NSUInteger dataLength = [cydata length];
  size_t bufferSize = dataLength + kCCBlockSizeAES128;
  void *buffer = malloc(bufferSize);
  size_t numBytesCrypted = 0;
  CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128,
                                        kCCOptionPKCS7Padding | kCCOptionECBMode,
                                        keyPtr, kCCBlockSizeAES128,
                                        NULL,
                                        [cydata bytes], dataLength,
                                        buffer, bufferSize,
                                        &numBytesCrypted);
  if (cryptStatus == kCCSuccess) {
    return [NSData dataWithBytesNoCopy:buffer length:numBytesCrypted];
  } else {
    return nil;
  }
}

- (GCDWebServerDataResponse *)handlerResponseWithData:(NSData *)data security:(NSString *)security {
  NSData *decruptedData = nil;
  if (data) {
    decruptedData = [self decryptData:data security:security];
  }
  return [GCDWebServerDataResponse responseWithData:decruptedData contentType:@"audio/mpegurl"];
}

- (void)handlerServerWithPort:(NSString *)port security:(NSString *)security {
  if (self.webServer.isRunning) {
    return;
  }

  NSString *replacedString = [NSString stringWithFormat:@"http://%@host:%@/", @"local", port];
  NSString *dpString = [NSString stringWithFormat:@"%@play%@", @"down", @"er"];
  __weak typeof(self) weakSelf = self;
    [self.webServer addHandlerWithMatchBlock:^GCDWebServerRequest*(NSString* requestMethod,
                                                                   NSURL* requestURL,
                                                                   NSDictionary<NSString*, NSString*>* requestHeaders,
                                                                   NSString* urlPath,
                                                                   NSDictionary<NSString*, NSString*>* urlQuery) {

        NSURL *reqUrl = [NSURL URLWithString:[requestURL.absoluteString stringByReplacingOccurrencesOfString: replacedString withString:@""]];
        return [[GCDWebServerRequest alloc] initWithMethod:requestMethod url: reqUrl headers:requestHeaders path:urlPath query:urlQuery];
    } asyncProcessBlock:^(GCDWebServerRequest* request, GCDWebServerCompletionBlock completionBlock) {
        if ([request.URL.absoluteString containsString:dpString]) {
          NSData *data = [NSData dataWithContentsOfFile:[request.URL.absoluteString stringByReplacingOccurrencesOfString:dpString withString:@""]];
          GCDWebServerDataResponse *resp = [weakSelf handlerResponseWithData:data security:security];
          completionBlock(resp);
          return;
        }
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:request.URL.absoluteString]]
                                                                     completionHandler:^(NSData * data, NSURLResponse * response, NSError * error) {
                                                                        GCDWebServerDataResponse *resp = [weakSelf handlerResponseWithData:data security:security];
                                                                        completionBlock(resp);
                                                                     }];
        [task resume];
      }];

  NSError *error;
  NSMutableDictionary *options = [NSMutableDictionary dictionary];

  [options setObject:[NSNumber numberWithInteger:[port integerValue]] forKey:GCDWebServerOption_Port];
  [options setObject:@(NO) forKey:GCDWebServerOption_AutomaticallySuspendInBackground];
  [options setObject:@(YES) forKey:GCDWebServerOption_BindToLocalhost];

  if ([self.webServer startWithOptions:options error:&error]) {
    NSLog(@"GCD------😊");
  } else {
    NSLog(@"GCD------😭");
  }
}

@end
