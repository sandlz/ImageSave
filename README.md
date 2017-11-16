# cordova-plugin-imagesave

保存照片到相册

- 支持自定义相册
- 支持权限

支持平台

- IOS
- Android

## 用法

### 返回码定义

| Code | State | Message |
| --- | --- | --- |
| 100 | Success | 全部成功 |
| 101 | Success | 部分成功 && 部分失败 |
| 110 | Error | 全部失败 |
| 120 | Error | 权限错误(无法保存到相册) |
| 130 | Error | 其他异常 |


### 调用

```
{
    imageList: imageList,
    albumName: albumName
}
```

imageList： 支持本地 与 网络图片地址

albumName：自定义相册名称

Example:

```
var imageList = [
'http://www.xxx.com/xxx/xxx.png',
'file://xxxx/xxx.jpg'
];

var albumName = 'Custom Album';

```


```
if (window.plugins && window.plugins.ImageSave) {
    window.plugins.ImageSave.saveToAlbum(JSON.stringify({
        imageList: imageList,
        albumName: albumName}), function (data) {
            PublicUtils.showToast("下载成功，请到相册中查看", function () {

            });
        }, function (error) {
            PublicUtils.showToast("下载失败...", function () {

            });
        });
} else {
    console.log("未安装 相册插件");
}
```

## 回调

成功

```
function (data) {
    // data : {code: 100, message: 'xxxx'}
}
```


失败

```
function (error) {
    // error : {code: 100, message: 'xxxx'}
}
```


