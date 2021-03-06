//
//  AppService.m
//  WildFireChat
//
//  Created by Heavyrain Lee on 2019/10/22.
//  Copyright © 2019 WildFireChat. All rights reserved.
//

#import "AppService.h"
#import <WFChatClient/WFCChatClient.h>
#import "AFNetworking.h"
#import "WFCConfig.h"

static AppService *sharedSingleton = nil;

@implementation AppService 
+ (AppService *)sharedAppService {
    if (sharedSingleton == nil) {
        @synchronized (self) {
            if (sharedSingleton == nil) {
                sharedSingleton = [[AppService alloc] init];
            }
        }
    }

    return sharedSingleton;
}

- (void)login:(NSString *)user password:(NSString *)password success:(void(^)(NSString *userId, NSString *token, BOOL newUser))successBlock error:(void(^)(int errCode, NSString *message))errorBlock {
    
    [self post:@"/login" data:@{@"mobile":user, @"code":password, @"clientId":[[WFCCNetworkService sharedInstance] getClientId], @"platform":@(Platform_iOS)} success:^(NSDictionary *dict) {
        if([dict[@"code"] intValue] == 0) {
            NSString *userId = dict[@"result"][@"userId"];
            NSString *token = dict[@"result"][@"token"];
            BOOL newUser = [dict[@"result"][@"register"] boolValue];
            successBlock(userId, token, newUser);
        } else {
            errorBlock([dict[@"code"] intValue], dict[@"message"]);
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1, error.description);
    }];
}

- (void)sendCode:(NSString *)phoneNumber success:(void(^)(void))successBlock error:(void(^)(NSString *message))errorBlock {
    
    [self post:@"/send_code" data:@{@"mobile":phoneNumber} success:^(NSDictionary *dict) {
        if([dict[@"code"] intValue] == 0) {
            successBlock();
        } else {
            errorBlock(@"error");
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(error.localizedDescription);
    }];
}


- (void)pcScaned:(NSString *)sessionId success:(void(^)(void))successBlock error:(void(^)(int errorCode, NSString *message))errorBlock {
    NSString *path = [NSString stringWithFormat:@"/scan_pc/%@", sessionId];
    [self post:path data:nil success:^(NSDictionary *dict) {
        if([dict[@"code"] intValue] == 0) {
            successBlock();
        } else {
            errorBlock([dict[@"code"] intValue], @"Network error");
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1, error.localizedDescription);
    }];
}

- (void)pcConfirmLogin:(NSString *)sessionId success:(void(^)(void))successBlock error:(void(^)(int errorCode, NSString *message))errorBlock {
    NSString *path = @"/confirm_pc";
    NSDictionary *param = @{@"im_token":@"", @"token":sessionId, @"user_id":[WFCCNetworkService sharedInstance].userId};
    [self post:path data:param success:^(NSDictionary *dict) {
        if([dict[@"code"] intValue] == 0) {
            successBlock();
        } else {
            errorBlock([dict[@"code"] intValue], @"Network error");
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1, error.localizedDescription);
    }];
}

- (void)getGroupAnnouncement:(NSString *)groupId
                     success:(void(^)(WFCUGroupAnnouncement *))successBlock
                      error:(void(^)(int error_code))errorBlock {
    if (successBlock) {
        NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"wfc_group_an_%@", groupId]];
    
        WFCUGroupAnnouncement *an = [[WFCUGroupAnnouncement alloc] init];
        an.data = data;
        an.groupId = groupId;
        
        successBlock(an);
    }
    
    NSString *path = @"/get_group_announcement";
    NSDictionary *param = @{@"groupId":groupId};
    [self post:path data:param success:^(NSDictionary *dict) {
        if([dict[@"code"] intValue] == 0 || [dict[@"code"] intValue] == 12) {
            WFCUGroupAnnouncement *an = [[WFCUGroupAnnouncement alloc] init];
            an.groupId = groupId;
            if ([dict[@"code"] intValue] == 0) {
                an.author = dict[@"result"][@"author"];
                an.text = dict[@"result"][@"text"];
                an.timestamp = [dict[@"result"][@"timestamp"] longValue];
            }
            
            [[NSUserDefaults standardUserDefaults] setValue:an.data forKey:[NSString stringWithFormat:@"wfc_group_an_%@", groupId]];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            successBlock(an);
        } else {
            errorBlock([dict[@"code"] intValue]);
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1);
    }];
}

- (void)updateGroup:(NSString *)groupId
       announcement:(NSString *)announcement
            success:(void(^)(long timestamp))successBlock
              error:(void(^)(int error_code))errorBlock {
    
    NSString *path = @"/put_group_announcement";
    NSDictionary *param = @{@"groupId":groupId, @"author":[WFCCNetworkService sharedInstance].userId, @"text":announcement};
    [self post:path data:param success:^(NSDictionary *dict) {
        if([dict[@"code"] intValue] == 0) {
            WFCUGroupAnnouncement *an = [[WFCUGroupAnnouncement alloc] init];
            an.groupId = groupId;
            an.author = [WFCCNetworkService sharedInstance].userId;
            an.text = announcement;
            an.timestamp = [dict[@"result"][@"timestamp"] longValue];
            
            
            [[NSUserDefaults standardUserDefaults] setValue:an.data forKey:[NSString stringWithFormat:@"wfc_group_an_%@", groupId]];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            successBlock(an.timestamp);
        } else {
            errorBlock([dict[@"code"] intValue]);
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1);
    }];
    
    
}

- (void)post:(NSString *)path data:(id)data success:(void(^)(NSDictionary *dict))successBlock error:(void(^)(NSError * _Nonnull error))errorBlock {
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"application/json"];
    
    [manager POST:[APP_SERVER_ADDRESS stringByAppendingPathComponent:path]
       parameters:data
         progress:nil
          success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
              NSDictionary *dict = responseObject;
              
              dispatch_async(dispatch_get_main_queue(), ^{
                  successBlock(dict);
              });
          }
          failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                errorBlock(error);
            });
          }];
}

- (void)uploadLogs:(void(^)(void))successBlock error:(void(^)(NSString *errorMsg))errorBlock {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSMutableArray<NSString *> *logFiles = [[WFCCNetworkService getLogFilesPath]  mutableCopy];
        
        NSMutableArray *uploadedFiles = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"mars_uploaded_files"] sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
            return [obj1 compare:obj2];
        }] mutableCopy];
        
        //日志文件列表需要删除掉已上传记录，避免重复上传。
        //但需要上传最后一条已经上传日志，因为那个日志文件可能在上传之后继续写入了，所以需要继续上传
        if (uploadedFiles.count) {
            [uploadedFiles removeLastObject];
        }
        
        if (![uploadedFiles isKindOfClass:[NSMutableArray class]]) {
            uploadedFiles = [[NSMutableArray alloc] init];
        }
        
        [logFiles removeObjectsInArray:uploadedFiles];
        
        
        __block NSString *errorMsg = nil;
        
        for (NSString *logFile in logFiles) {
            AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
            manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"application/json"];
            
            NSString *url = [APP_SERVER_ADDRESS stringByAppendingFormat:@"/logs/%@/upload", [WFCCNetworkService sharedInstance].userId];
            
             dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            
            __block BOOL success = NO;

            [manager POST:url parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
                NSData *logData = [NSData dataWithContentsOfFile:logFile];
                
                NSString *fileName = [[NSURL URLWithString:logFile] lastPathComponent];
                
                [formData appendPartWithFileData:logData name:@"file" fileName:fileName mimeType:@"application/octet-stream"];
                
            } progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                
                if ([responseObject isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *dict = (NSDictionary *)responseObject;
                    if([dict[@"code"] intValue] == 0) {
                        NSLog(@"上传成功");
                        success = YES;
                    }
                }
                if (!success) {
                    errorMsg = @"服务器响应错误";
                }
                dispatch_semaphore_signal(sema);
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                NSLog(@"上传失败：%@", error);
                dispatch_semaphore_signal(sema);
                errorMsg = error.localizedFailureReason;
            }];
            
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            
            if (success) {
                [uploadedFiles addObject:logFile];
                [[NSUserDefaults standardUserDefaults] setObject:uploadedFiles forKey:@"mars_uploaded_files"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            } else {
                errorBlock(errorMsg);
                return;
            }
        }
        
        successBlock();
    });
    
}
@end
