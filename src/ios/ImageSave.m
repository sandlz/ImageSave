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
@property(nonatomic, strong)NSString *cacheDirName;
@property(nonatomic, strong)NSMutableArray *errorImageList;
@property(nonatomic, strong)NSMutableDictionary *callbackDic;
@property(nonatomic)NSUInteger successCount;
@property(nonatomic)NSUInteger errorCount;
@property(nonatomic)BOOL hasPermission;

@property(nonatomic, strong)NSFileManager *fileManager;
@property(nonatomic, strong)NSString *cacheDirPath;

@property(nonatomic, strong)PHAssetCollection *createdCollection;

@property (nonatomic ,strong)CDVInvokedUrlCommand  *command;

@end

@implementation ImageSave

- (void)saveToAlbum:(CDVInvokedUrlCommand*)command {
    self.command = command;
    NSString* jsonString = [command.arguments objectAtIndex:0];
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    NSArray *imageList    = [dic objectForKey:@"imageList"];
    self.imageList = [NSArray arrayWithArray:imageList];
    self.albumName     = [dic objectForKey:@"albumName"];
    self.cacheDirName = [dic objectForKey:@"cacheDirName"];
    self.hasPermission = NO;
    [self.commandDelegate runInBackground:^{
        [self initData];
        [self checkPhotoPermissions];
    }];
    
}

#pragma mark - Init Data

- (void)initData {
    self.successCount = 0;
    self.errorCount = 0;
    self.errorImageList = [[NSMutableArray alloc] init];
    self.callbackDic = [[NSMutableDictionary alloc] init];
    self.fileManager = [NSFileManager defaultManager];
    NSString *libDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    // get cached file dir
    self.cacheDirPath = [NSString stringWithFormat:@"%@/files/%@/",libDir,self.cacheDirName];
    self.createdCollection = [self createCustomAssetCollection:self.albumName];
}

#pragma mark - Success Callback

- (void)callbackSuccess: (NSMutableDictionary *) dic {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dic];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.command.callbackId];
}

#pragma mark - Error Callback

- (void)callbackError: (NSMutableDictionary *) dic {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dic];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.command.callbackId];
}

#pragma mark - Save Image

- (void)handleSavePhotoToAlbum {
    NSUInteger imageLength = self.imageList.count;
    for (int i =0 ; i< imageLength; i++) {
        NSDictionary *dic = [self.imageList objectAtIndex:i];
        NSString *imageUrl = [dic objectForKey:@"imageUrl"];
        NSString *cacheFileName = [dic objectForKey:@"cacheFileName"];
        
        NSString *cacheFilePath = [self getLocalFileFullPathByFileName:cacheFileName];
        // check cacheFile is exist
        BOOL isExist = [self checkFilesExist:cacheFilePath];
        NSData *data = nil;
        if (isExist) {
            // Local
            data = [self getImageDataFromLocal: cacheFilePath];
        } else {
            // Network
            data = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageUrl]];
        }
        [self saveImage:data imageUrl:imageUrl];
    }
}

#pragma mark - Save Image with NSData

- (void)saveImage:(NSData *)data imageUrl:(NSString *)url {
    if (data == nil) {
        return;
    }
    
    UIImage *uiImage = [[UIImage alloc] initWithData:data];
    if (self.createdCollection == nil) {
        NSLog(@"create album faied");
        return;
    }
    
    // save image to custom album
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetCollectionChangeRequest *request = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:self.createdCollection];
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

#pragma mark - Handle Save State

- (void)handleSaveStatus {
    if (self.successCount == self.imageList.count) {
        // all success
        [self.callbackDic setObject:@"全部成功" forKey:@"message"];
        [self.callbackDic setObject:@(100) forKey:@"code"];
        [self callbackSuccess:self.callbackDic];
        
    } else if (self.errorCount > 0 && self.successCount > 0 && (self.successCount + self.errorCount) == self.imageList.count) {
        // part success, part error
        [self.callbackDic setObject:@"部分成功,部分失败" forKey:@"message"];
        [self.callbackDic setObject:@(101) forKey:@"code"];
        [self.callbackDic setObject:self.errorImageList forKey:@"errorList"];
        [self callbackSuccess:self.callbackDic];
        
    } else if (self.errorCount == self.imageList.count) {
        // all error
        [self.callbackDic setObject:@"全部失败" forKey:@"message"];
        [self.callbackDic setObject:@(110) forKey:@"code"];
        [self callbackError:self.callbackDic];
    }
}

#pragma mark - Check Photo Permission

- (void)checkPhotoPermissions {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusNotDetermined) {
        // not sure ,block's content will called when authored
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                // call save method
                self.hasPermission = YES;
                [self handleSavePhotoToAlbum];
            }
        }];
        
        // allow
    } else if (status == PHAuthorizationStatusAuthorized) {
        // call save method
        self.hasPermission = YES;
        [self handleSavePhotoToAlbum];
    } else {
        // Denied or Restricted
        // open setting view
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSelector:@selector(openSetting) withObject:nil afterDelay:3.0];
        });
        self.hasPermission = NO;
        [self.callbackDic setObject:@"无访问相册权限" forKey:@"message"];
        [self.callbackDic setObject:@(120) forKey:@"code"];
        [self callbackError:self.callbackDic];
    }
}

#pragma mark - Open Setting View

- (void)openSetting {
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url];
    }
}


#pragma mark -  Use Photo.framework create album

- (PHAssetCollection *)createCustomAssetCollection: (NSString *)albumName
{
    // get app name
    if (nil == albumName) {
        albumName = [NSBundle mainBundle].infoDictionary[(NSString *)kCFBundleNameKey];
    }
    NSError *error = nil;
    
    // check app exist the album. if exist, do nothing
    /**
     *     Param one -  enum：
     *     PHAssetCollectionTypeAlbum      = 1, custom album
     *     PHAssetCollectionTypeSmartAlbum = 2, system album
     *     PHAssetCollectionTypeMoment     = 3, date ordered album
     *
     *     Param two - enum：PHAssetCollectionSubtype
     
     *     example：PHAssetCollectionTypeSmartAlbum system album PHAssetCollectionSubtypeSmartAlbumUserLibrary user album
     *     PHAssetCollectionSubtypeAlbumRegular normal album
     */
    PHFetchResult<PHAssetCollection *> *result = [PHAssetCollection fetchAssetCollectionsWithType:(PHAssetCollectionTypeAlbum)
                                                                                          subtype:(PHAssetCollectionSubtypeAlbumRegular)
                                                                                          options:nil];
    for (PHAssetCollection *collection in result) {
        if ([collection.localizedTitle isEqualToString:albumName]) {
            // exist the album
            return collection;
        }
    }
    // need creat album
    __block NSString *createdCustomAssetCollectionIdentifier = nil;
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        PHAssetCollectionChangeRequest *collectionChangeRequest = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:albumName];
        createdCustomAssetCollectionIdentifier = collectionChangeRequest.placeholderForCreatedAssetCollection.localIdentifier;
    } error:&error];
    // block end. album created
    if (error) {
        NSLog(@"create album failed");
    }
    return [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[createdCustomAssetCollectionIdentifier] options:nil].firstObject;
}

# pragma mark - Get custom album list

- (void)getAllImageDataFromCustomAlbum:(PHAssetCollection *)collection {
    // get all PHAsset
    NSMutableArray *array = [NSMutableArray array];
    PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsInAssetCollection:collection options:nil];
    if (assets.count == 0) {
        //        [self handleSavePhotoToAlbumWithAlbumDataArray:[NSArray array]];
        return;
    }
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.synchronous = NO;
    for (PHAsset *asset in assets) {
        @autoreleasepool {
            // get image data from PHAsset
            [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options
                                                        resultHandler:^(NSData *imageData,NSString *dataUTI,UIImageOrientation orientation, NSDictionary *info) {
                                                            [array addObject:imageData];
                                                            //                                                            if (array.count == assets.count) {
                                                            //                                                                [self handleSavePhotoToAlbumWithAlbumDataArray:array];
                                                            //
                                                            //                                                            }
                                                        }];
        }
    }
}

# pragma mark - Check Library Dir is exist file

- (BOOL)checkFilesExist:(NSString *)localFilePath {
    return [self.fileManager fileExistsAtPath:localFilePath];
}

# pragma mark - Get file full path

- (NSString *)getLocalFileFullPathByFileName:(NSString *)fileName {
    return [NSString stringWithFormat:@"%@%@",self.cacheDirPath,fileName];
}

# pragma mark - Get data from local file path

- (NSData*)getImageDataFromLocal:(NSString *)localFilePath {
    if (nil != localFilePath && [self checkFilesExist:localFilePath]) {
        return [self.fileManager contentsAtPath:localFilePath];
    }
    return nil;
}

# pragma mark - Get File List From Cache Dir

- (NSArray *)getFileListFromCacheDir {
    // list the cached file
    NSArray *dirContents = [self.fileManager contentsOfDirectoryAtPath:self.cacheDirPath error:nil];
    return dirContents;
}

@end
