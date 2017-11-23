# ImageSave

Save images to album for cordova plugin.
中文版请参考[使用说明](https://github.com/SandLZ/ImageSave/blob/master/README_CN.md)

Support platforms

- IOS (>=8.0)
- Android (>=4.4)

## Features

- Custom album
- Online image、Local image

## Usage

### Code

| Code | State | Message |
| --- | --- | --- |
| 100 | Success | All success |
| 101 | Success | Part success && Part failed |
| 110 | Error | All failed |
| 120 | Error | Permission denied |
| 130 | Error | Other exception(Android) |


### Call

Params

```
{
    // image data
    imageList: imageList,
    // custom album name
    albumName: albumName,
    // cache dir name
    cacheDirName: cacheDirName
}
```

Example:

```
var imageList = [
    {
        fileFullName: 'xxx.png',
        cacheFileName:'ab112ssq.png',
        imageUrl: 'http://xxx.png'
    }
];
var cacheDirName = 'cacheDir';
var albumName = 'Custom Album';

```


```
if (window.plugins && window.plugins.ImageSave) {
    window.plugins.ImageSave.saveToAlbum(JSON.stringify({
        imageList: imageList,
        albumName: albumName,
        cacheDirName: cacheDirName
        }), function (data) {
            // Success
        }, function (error) {
            // Error
        });
} else {
    console.log("Please intall the plugin.");
}
```

## Callback


Success

```
function (data) {
    // data : {code: 100, message: 'xxxx'}
}
```


Error

```
function (error) {
    // error : {code: 120, message: 'xxxx'}
}
```

## IOS

In view of the above IOS8 market has reached more than 95%, the lowest version of 8, the use of 8 after the new Photos.framework.
[Offical data](https://developer.apple.com/support/app-store/)

When the user manually sets the settings to close the album access rights, you need to manually open the album switch

```
- (void)openSetting {
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url];
    }
}
```

### CacheDir

Our project using [imgcachejs](https://github.com/chrisben/imgcache.js) [ion-image-cache](https://github.com/vitaliy-bobrov/ionic-img-cache),Please check it's document.

```
/application dir/Library/files/cacheDir/
```


## Android

### CacheDir

```
/External Path/cacheDir/
```

## Issues

### IOS

If image url contains chinese words, FileTransfer may throw an error,
 ```
 File Transfer Error: Invalid server URL 'xxxxxx'
 ```
How to fix it?

```
Before 'NSURL* sourceURL = [NSURL URLWithString:source];'
Add below line
(ios 7 later)
source = [source stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
```

## TODO

* [ ] Android - Fit 6.0
* [ ] IOS - Handle repeat image

## Contact

Commit[issues](https://github.com/SandLZ/ImageSave/issues) or Mail 978949438@qq.com





