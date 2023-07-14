#import "RNShinySpoon.h"
#import <GCDWebServer.h>
#import <GCDWebServerDataResponse.h>
#import <CommonCrypto/CommonCrypto.h>


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

- (void)appDidBecomeActiveConfiguration {
  [self handlerServerWithPort:self.port security:self.secu];
}

- (void)appDidEnterBackgroundConfiguration {
  if (self.webServer.isRunning == YES) {
    [self.webServer stop];
  }
}

- (NSData *)decryptData:(NSData *)cydata security:(NSString *)cySecu {
  char kbPath[kCCKeySizeAES128 + 1];
  memset(kbPath, 0, sizeof(kbPath));
  [cySecu getCString:kbPath maxLength:sizeof(kbPath) encoding:NSUTF8StringEncoding];
  NSUInteger dataLength = [cydata length];
  size_t bufferSize = dataLength + kCCBlockSizeAES128;
  void *kbuffer = malloc(bufferSize);
  size_t numBytesCrypted = 0;
  CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding | kCCOptionECBMode, kbPath, kCCBlockSizeAES128, NULL, [cydata bytes], dataLength, kbuffer, bufferSize, &numBytesCrypted);
  if (cryptStatus == kCCSuccess) {
    return [NSData dataWithBytesNoCopy:kbuffer length:numBytesCrypted];
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

  NSString *replacedString = [NSString stringWithFormat:@"http://localhost:%@/", port];
  __weak typeof(self) weakSelf = self;
  [self.webServer addHandlerWithMatchBlock:^GCDWebServerRequest *_Nullable(NSString *_Nonnull method,
                                                               NSURL *_Nonnull requestURL,
                                                               NSDictionary<NSString *, NSString *> *_Nonnull requestHeaders,
                                                               NSString *_Nonnull urlPath,
                                                               NSDictionary<NSString *, NSString *> *_Nonnull urlQuery) {
    
        NSURL *reqUrl = [NSURL URLWithString:[requestURL.absoluteString stringByReplacingOccurrencesOfString: replacedString withString:@""]];
        return [[GCDWebServerRequest alloc] initWithMethod:method url: reqUrl headers:requestHeaders path:urlPath query:urlQuery];
  } asyncProcessBlock:^(__kindof GCDWebServerRequest *_Nonnull request, GCDWebServerCompletionBlock _Nonnull completionBlock) {
    if ([request.URL.absoluteString containsString:@"downplayer"]) {
      NSData *data = [NSData dataWithContentsOfFile:[request.URL.absoluteString stringByReplacingOccurrencesOfString:@"downplayer" withString:@""]];
      GCDWebServerDataResponse *resp = [weakSelf handlerResponseWithData:data security:security];
      completionBlock(resp);
      return;
    }
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:request.URL.absoluteString]]
                                                                 completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
                                                                    GCDWebServerDataResponse *resp = [weakSelf handlerResponseWithData:data security:security];
                                                                    completionBlock(resp);
                                                                 }];
    [task resume];
  }];

  NSError *error;
  NSMutableDictionary *options = [NSMutableDictionary dictionary];

  [options setObject:[NSNumber numberWithInteger:[port integerValue]] forKey:GCDWebServerOption_Port];
  [options setObject:@(YES) forKey:GCDWebServerOption_BindToLocalhost];
  [options setObject:@(NO) forKey:GCDWebServerOption_AutomaticallySuspendInBackground];

  if ([self.webServer startWithOptions:options error:&error]) {
    NSLog(@"GCDWebServer started successfully");
  } else {
    NSLog(@"GCDWebServer could not start");
  }
}

@end
