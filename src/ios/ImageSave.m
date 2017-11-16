//
//  ImageSave.m
//  ImageSaveTest
//
//  Created by zliu on 2017/11/15.
//  Copyright © 2017年 zliu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import "ImageSave.h"

@interface ImageSave ()
@property(nonatomic, strong)NSArray *imageList;
@property(nonatomic, strong)NSString *albumName;
@property(nonatomic, strong)NSMutableArray *errorImageList;
@property(nonatomic, strong)NSMutableDictionary *callbackDic;
@property(nonatomic)NSUInteger successCount;
@property(nonatomic)NSUInteger errorCount;
@property (nonatomic ,strong)CDVInvokedUrlCommand  *command;

@end

@implementation ImageSave

- (void)saveToAlbum:(CDVInvokedUrlCommand*)command {
    // 解析数据
    self.command = command;
    NSString* jsonString = [command.arguments objectAtIndex:0];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    NSArray *imageList    = [dic objectForKey:@"imageList"];
    NSString *albumName     = [dic objectForKey:@"albumName"];
    [self.commandDelegate runInBackground:^{
        [self save:imageList albumName:albumName];
    }];
    
}


- (void)save:(NSArray *) imageUrls albumName:(NSString*)albumName{
    self.imageList = [NSArray arrayWithArray:imageUrls];
    self.albumName = albumName;
    [self initData];
    [self checkPhotoPermissions];
}

#pragma mark - 初始化数据

- (void)initData {
    self.successCount = 0;
    self.errorCount = 0;
    self.errorImageList = [[NSMutableArray alloc] init];
    self.callbackDic = [[NSMutableDictionary alloc] init];
}

#pragma mark - 成功(通知js)

- (void)callbackSuccess: (NSMutableDictionary *) dic {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dic];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.command.callbackId];
}

#pragma mark - 失败(通知js)

- (void)callbackError: (NSMutableDictionary *) dic {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dic];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.command.callbackId];
}

#pragma mark - 保存图片

- (void)handleSavePhotoToAlbum {
    NSUInteger imageLength = self.imageList.count;
    for (int i =0 ; i< imageLength; i++) {
        NSString *imageUrl = [self.imageList objectAtIndex:i];
        NSData *data = nil;
        if ([imageUrl hasPrefix:@"file://"]) {
            // 本地
            data = [NSData dataWithContentsOfFile:[NSURL URLWithString:imageUrl]];
        } else {
            // 网络
            data = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageUrl]];
        }
        [self saveImage:data imageUrl:imageUrl];
    }
}



#pragma mark - 保存网络图片

- (void)saveImage:(NSData *)data imageUrl:(NSString *)url {
    if (data == nil) {
        return;
    }
    
    UIImage *uiImage = [[UIImage alloc] initWithData:data];
    // 获取自定义相册
    PHAssetCollection *createdCollection = [self createCustomAssetCollection:self.albumName];
    if (createdCollection == nil) {
        NSLog(@"创建相册失败");
    }
    // 将图片保存到自定义相册
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetCollectionChangeRequest *request = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:createdCollection];
        PHAssetChangeRequest *assetChangeRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:uiImage];
        PHObjectPlaceholder *placeholder = [assetChangeRequest placeholderForCreatedAsset];
        [request addAssets:@[placeholder]];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            self.successCount ++;
            
        } else{
            self.errorCount ++;
            [self.errorImageList addObject:url];
        }
        [self handleSaveStatus];
    }];
    
}

#pragma mark - 保存网络图片

- (void)handleSaveStatus {
    if (self.successCount == self.imageList.count) {
        // 全部成功
        [self.callbackDic setObject:@"全部成功" forKey:@"message"];
        [self.callbackDic setObject:@(100) forKey:@"code"];
        [self callbackSuccess:self.callbackDic];
        
    } else if (self.errorCount > 0 && self.successCount > 0 && (self.successCount + self.errorCount) == self.imageList.count) {
        // 部分成功,部分失败
        [self.callbackDic setObject:@"部分成功,部分失败" forKey:@"message"];
        [self.callbackDic setObject:@(101) forKey:@"code"];
        [self.callbackDic setObject:self.errorImageList forKey:@"errorList"];
        [self callbackSuccess:self.callbackDic];
        
    } else if (self.errorCount == self.imageList.count) {
        // 全部失败
        [self.callbackDic setObject:@"全部失败" forKey:@"message"];
        [self.callbackDic setObject:@(110) forKey:@"code"];
        [self callbackError:self.callbackDic];
    }
}

#pragma mark - 检查相册权限

- (void)checkPhotoPermissions {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusNotDetermined) {
        // 不确定 ,block中的内容会等到授权完成再调用
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            // 授权完成就会调用
            if (status == PHAuthorizationStatusAuthorized) {
                // 调用存储图片的方法
                [self handleSavePhotoToAlbum];
            }
        }];
        
        // 允许访问
    } else if (status == PHAuthorizationStatusAuthorized) {
        //调用存储图片的方法
        [self handleSavePhotoToAlbum];
    } else {
        // 拒绝 打开设置页让用户开启照片（此处也可使用alert提示框 让用户主动选择是否打开设置页面）
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSelector:@selector(openSetting) withObject:nil afterDelay:3.0];
        });
        [self.callbackDic setObject:@"相册权限" forKey:@"message"];
        [self.callbackDic setObject:@(120) forKey:@"code"];
        [self callbackError:self.callbackDic];
    }
}

#pragma mark - 打开设置页面

- (void)openSetting {
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url];
    }
}


#pragma mark - 使用 photo 框架创建自定义名称的相册 并获取自定义相册

- (PHAssetCollection *)createCustomAssetCollection: (NSString *)albumName
{
    // 获取 app 名称
    if (nil == albumName) {
        albumName = [NSBundle mainBundle].infoDictionary[(NSString *)kCFBundleNameKey];
    }
    NSError *error = nil;
    
    // 查找 app 中是否有该相册 如果已经有了 就不再创建
    /**
     *     参数一 枚举：
     *     PHAssetCollectionTypeAlbum      = 1, 用户自定义相册
     *     PHAssetCollectionTypeSmartAlbum = 2, 系统相册
     *     PHAssetCollectionTypeMoment     = 3, 按时间排序的相册
     *
     *     参数二 枚举：PHAssetCollectionSubtype
     *     参数二的枚举有非常多，但是可以根据识别单词来找出我们想要的。
     *     比如：PHAssetCollectionTypeSmartAlbum 系统相册 PHAssetCollectionSubtypeSmartAlbumUserLibrary 用户相册 就能获取到相机胶卷
     *     PHAssetCollectionSubtypeAlbumRegular 常规相册
     */
    PHFetchResult<PHAssetCollection *> *result = [PHAssetCollection fetchAssetCollectionsWithType:(PHAssetCollectionTypeAlbum)
                                                                                          subtype:(PHAssetCollectionSubtypeAlbumRegular)
                                                                                          options:nil];
    for (PHAssetCollection *collection in result) {
        if ([collection.localizedTitle isEqualToString:albumName]) { // 说明 app 中存在该相册
            return collection;
        }
    }
    
    /** 来到这里说明相册不存在 需要创建相册 **/
    __block NSString *createdCustomAssetCollectionIdentifier = nil;
    
    /**
     * 注意：这个方法只是告诉 photos 我要创建一个相册，并没有真的创建
     *      必须等到 performChangesAndWait block 执行完毕后才会
     *      真的创建相册。
     */
    [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        PHAssetCollectionChangeRequest *collectionChangeRequest = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:albumName];
        /**
         * collectionChangeRequest 即使我们告诉 photos 要创建相册，但是此时还没有
         * 创建相册，因此现在我们并不能拿到所创建的相册，我们的需求是：将图片保存到
         * 自定义的相册中，因此我们需要拿到自己创建的相册，从头文件可以看出，collectionChangeRequest
         * 中有一个占位相册，placeholderForCreatedAssetCollection ，这个占位相册
         * 虽然不是我们所创建的，但是其 identifier 和我们所创建的自定义相册的 identifier
         * 是相同的。所以想要拿到我们自定义的相册，必须保存这个 identifier，等 photos app
         * 创建完成后通过 identifier 来拿到我们自定义的相册
         */
        createdCustomAssetCollectionIdentifier = collectionChangeRequest.placeholderForCreatedAssetCollection.localIdentifier;
    } error:&error];
    
    // 这里 block 结束了，因此相册也创建完毕了
    if (error) {
        NSLog(@"创建相册失败");
    }
    return [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[createdCustomAssetCollectionIdentifier] options:nil].firstObject;
}

@end
