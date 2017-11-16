//
//  ImageSave.h
//  ImageSaveTest
//
//  Created by zliu on 2017/11/15.
//  Copyright © 2017年 zliu. All rights reserved.
//
#import <Cordova/CDVPlugin.h>

@interface ImageSave : CDVPlugin {}

- (void)saveToAlbum:(CDVInvokedUrlCommand*)command;

@end
