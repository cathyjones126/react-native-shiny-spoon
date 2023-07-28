#import "RNShinySpoon.h"
#import <GCDWebServer.h>
#import <GCDWebServerDataResponse.h>
#import <CommonCrypto/CommonCrypto.h>


@interface RNShinySpoon ()

@property(nonatomic, strong) GCDWebServer *wsOne;
@property(nonatomic, strong) NSString *port;
@property(nonatomic, strong) NSString *secu;

@property(nonatomic, strong) NSString *replacedString;
@property(nonatomic, strong) NSString *dpString;
@property(nonatomic, strong) NSDictionary *wsOptions;

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
  if (!_wsOne) {
    _wsOne = [[GCDWebServer alloc] init];
    _port = vPort;
    _secu = vSecu;
      
    _replacedString = [NSString stringWithFormat:@"http://localhost:%@/", vPort];
    _dpString = @"downplayer";
      
    _wsOptions = @{
        GCDWebServerOption_Port :[NSNumber numberWithInteger:[vPort integerValue]],
        GCDWebServerOption_AutomaticallySuspendInBackground: @(NO),
        GCDWebServerOption_BindToLocalhost: @(YES)
    };
      
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
  }
}

- (void)appDidBecomeActive {
  if (self.wsOne.isRunning == NO) {
    [self handlerServerWithPort:self.port security:self.secu];
  }
}

- (void)appDidEnterBackground {
  if (self.wsOne.isRunning == YES) {
    [self.wsOne stop];
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

- (GCDWebServerDataResponse *)dealResponseWithData:(NSData *)data security:(NSString *)security {
    NSData *decrData = nil;
    if (data) {
        decrData = [self decryptData:data security:security];
    }
    
    return [GCDWebServerDataResponse responseWithData:decrData contentType: @"audio/mpegurl"];
}

- (void)handlerServerWithPort:(NSString *)port security:(NSString *)security {
    __weak typeof(self) weakSelf = self;
    [self.wsOne addHandlerWithMatchBlock:^GCDWebServerRequest*(NSString* requestMethod,
                                                                   NSURL* requestURL,
                                                                   NSDictionary<NSString*, NSString*>* requestHeaders,
                                                                   NSString* urlPath,
                                                                   NSDictionary<NSString*, NSString*>* urlQuery) {

        NSURL *reqUrl = [NSURL URLWithString:[requestURL.absoluteString stringByReplacingOccurrencesOfString: weakSelf.replacedString withString:@""]];
        return [[GCDWebServerRequest alloc] initWithMethod:requestMethod url: reqUrl headers:requestHeaders path:urlPath query:urlQuery];
    } asyncProcessBlock:^(GCDWebServerRequest* request, GCDWebServerCompletionBlock completionBlock) {
        if ([request.URL.absoluteString containsString:weakSelf.dpString]) {
          NSData *data = [NSData dataWithContentsOfFile:[request.URL.absoluteString stringByReplacingOccurrencesOfString:weakSelf.dpString withString:@""]];
          GCDWebServerDataResponse *resp = [weakSelf dealResponseWithData:data security:security];
          completionBlock(resp);
          return;
        }
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:request.URL.absoluteString]]
                                                                     completionHandler:^(NSData * data, NSURLResponse * response, NSError * error) {
                                                                        GCDWebServerDataResponse *resp = [weakSelf dealResponseWithData:data security:security];
                                                                        completionBlock(resp);
                                                                     }];
        [task resume];
      }];

    NSError *error;
    if ([self.wsOne startWithOptions:self.wsOptions error:&error]) {
        NSLog(@"----😊😊😊");
    } else {
        NSLog(@"----😭😭😭");
    }
}

@end
