//
//  BGNetworkConnector.m
//  BGNetwork
//
//  Created by user on 15/8/18.
//  Copyright (c) 2015年 lcg. All rights reserved.
//

#import "BGNetworkConnector.h"
#import "BGAFHTTPClient.h"
#import "BGAFRequestSerializer.h"
#import "BGAFResponseSerializer.h"
#import "BGNetworkUtil.h"

@interface BGNetworkConnector ()<BGAFRequestSerializerDelegate, BGAFResponseSerializerDelegate>
@property (nonatomic, strong) BGAFHTTPClient *httpClient;
@property (nonatomic, weak) id<BGNetworkConnectorDelegate> delegate;
@end

@implementation BGNetworkConnector
- (instancetype)initWithBaseURL:(NSString *)baseURL{
    return [self initWithBaseURL:baseURL delegate:nil];
}

- (instancetype)initWithBaseURL:(NSString *)baseURL delegate:(id<BGNetworkConnectorDelegate>)delegate{
    if(self = [super init]){
        //AFHTTPClient
        _httpClient = [[BGAFHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:baseURL]];
        AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
        //是否允许CA不信任的证书通过
        policy.allowInvalidCertificates = YES;
        //是否验证主机名
        policy.validatesDomainName = YES;
        _httpClient.securityPolicy = policy;
        
        //请求的序列化器
        BGAFRequestSerializer *requestSerializer = [BGAFRequestSerializer serializer];
        requestSerializer.delegate = self;
        
        //响应的序列化器
        BGAFResponseSerializer *responseSerializer = [BGAFResponseSerializer serializer];
        responseSerializer.delegate = self;
        
        //设置
        _httpClient.requestSerializer = requestSerializer;
        _httpClient.responseSerializer = responseSerializer;
        
        //设置代理
        _delegate = delegate;
    }
    return self;
}

#pragma mark - 发送请求
- (NSURLSessionDataTask *)sendGETRequest:(NSString *)methodName parameters:(NSDictionary *)paramters success:(void (^)(NSURLSessionDataTask *, NSData *))successBlock failed:(void (^)(NSURLSessionDataTask *, NSError *))failedBlock{
    return [self.httpClient GET:methodName parameters:paramters success:successBlock failure:failedBlock];
}

- (NSURLSessionDataTask *)sendPOSTRequest:(NSString *)methodName parameters:(NSDictionary *)paramters success:(void (^)(NSURLSessionDataTask *, NSData *))successBlock failed:(void (^)(NSURLSessionDataTask *, NSError *))failedBlock{
    return [self.httpClient POST:methodName parameters:paramters success:successBlock failure:failedBlock];
}

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request
                                         progress:(void (^)(NSProgress *downloadProgress)) downloadProgressBlock
                                      destination:(NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                                completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler {
    NSURLSessionDownloadTask *task = [self.httpClient downloadTaskWithRequest:request progress:downloadProgressBlock destination:destination completionHandler:completionHandler];
    [task resume];
    return task;
}

- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData
                                                progress:(void (^)(NSProgress *downloadProgress)) downloadProgressBlock
                                             destination:(NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                                       completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler {
    NSURLSessionDownloadTask *task = [self.httpClient downloadTaskWithResumeData:resumeData progress:downloadProgressBlock destination:destination completionHandler:completionHandler];
    [task resume];
    return task;
}

- (NSURLSessionDataTask *)POST:(NSString *)URLString
                    parameters:(id)parameters
     constructingBodyWithBlock:(void (^)(id <AFMultipartFormData> formData))block
                      progress:(nullable void (^)(NSProgress * _Nonnull))uploadProgress
                       success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                       failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure {
    return [self.httpClient POST:URLString parameters:parameters constructingBodyWithBlock:block progress:uploadProgress success:success failure:failure];
}

#pragma mark - BGAFRequestSerializerDelegate
- (NSURLRequest *)requestSerializer:(BGAFRequestSerializer *)requestSerializer request:(NSURLRequest *)request withParameters:(id)parameters error:(NSError *__autoreleasing *)error{
    NSParameterAssert(request);
    // NOTE:MutableRequest
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    
    // NOTE:RequestHeader
    NSDictionary *httpRequestHeaderDic = [_delegate allHTTPHeaderFieldsWithNetworkConnector:self request:request];
    [httpRequestHeaderDic enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
        if (![request valueForHTTPHeaderField:field]) {
            [mutableRequest setValue:value forHTTPHeaderField:field];
        }
    }];
    
    if (![mutableRequest valueForHTTPHeaderField:@"Content-Type"]) {
        [mutableRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }
    
    //NOTE:URL QueryString
    NSString *queryString = [_delegate queryStringForURLWithNetworkConnector:self parameters:parameters request:request];
    if(queryString){
        mutableRequest.URL = [NSURL URLWithString:[[mutableRequest.URL absoluteString] stringByAppendingFormat:mutableRequest.URL.query ? @"&%@" : @"?%@", queryString]];
    }
    
    //NOTE:HTTP GET or POST method
    if ([requestSerializer.HTTPMethodsEncodingParametersInURI containsObject:[[request HTTPMethod] uppercaseString]]) {
        //GET请求
    }
    else{
        //NOTE:HTTP Body Data
        NSData *bodyData = [_delegate dataOfHTTPBodyWithNetworkConnector:self parameters:parameters request:request error:error];
        if(bodyData){
            [mutableRequest setHTTPBody:bodyData];
        }
    }
    
    return [mutableRequest copy];
}

#pragma mark - BGAFResponseSerializerDelegate
- (id)responseSerializer:(BGAFResponseSerializer *)responseSerializer response:(NSHTTPURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error{
    return data;
}

#pragma mark - cancel request
- (void)cancelRequest:(NSString *)url{
    [self.httpClient cancelTasksWithUrl:url];
}

@end
