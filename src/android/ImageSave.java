package com.handsmap.imagesave;

import android.content.Intent;
import android.net.Uri;
import android.os.Environment;
import android.util.Log;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;

public class ImageSave extends CordovaPlugin {

    private String ALBUM_PATH = "";
    private String cacheDirName = "Picture";
    private String albumName = "";

    private final static String TAG = "ImageSave";

    private ArrayList<String> imageList = null;
    private ArrayList<String> errorImageList = null;

    private CallbackContext callbackContext = null;

    private int successCount = 0;
    private int errorCount = 0;

    @Override
    public boolean execute(String action, final JSONArray args, final CallbackContext callbackContext)
            throws JSONException {

        if (action.equals("saveToAlbum")) {
            this.callbackContext = callbackContext;
            String obj = (String) args.get(0);
            JSONObject jsonObj = new JSONObject(obj);
            JSONArray iamgeJsonArr = jsonObj.getJSONArray("imageList");
            albumName = jsonObj.getString("albumName");
            cacheDirName = jsonObj.getString("cacheDirName");
            initData(iamgeJsonArr);
            return true;
        }
        return false;
    }

    private void initData(JSONArray iamgeJsonArr) {
        if (null == errorImageList) {
            errorImageList = new ArrayList<>();
        } else {
            errorImageList.clear();
        }
        if (null == imageList) {
            imageList = new ArrayList<>();
        } else {
            imageList.clear();
        }
        successCount = 0;
        errorCount = 0;
        if (null == albumName) {
            albumName = "默认相册/";
        } else {
            albumName += "/";
        }
        ALBUM_PATH = Environment.getExternalStorageDirectory() + "/" + albumName;
        checkDir(ALBUM_PATH);
        for (int i = 0; i < iamgeJsonArr.length(); i++) {
            try {
                JSONObject itemJson = iamgeJsonArr.getJSONObject(i);
                String fileFullPath = getLocalFileFullPath(itemJson.getString("cacheFileName"));
                // check album dir exist the file
                String imageFullPath = ALBUM_PATH + itemJson.getString("fileFullName");
                if (!checkFileExists(imageFullPath)) {
                    // album dir doesn't exist copy file
                    if (!checkFileExists(fileFullPath)) {
                        // check local file exist. if not, download it
                        imageList.add(itemJson.getString("imageUrl"));
                    } else {
                        // exist, check album dir exist the file
                        copyFile(fileFullPath, imageFullPath);
                    }
                }
            } catch (JSONException e) {
                e.printStackTrace();
            }
        }
        handleData();
    }

    /**
     * Handle data , Prepare to save image to album
     */
    private void handleData() {
        cordova.getThreadPool().execute(new Runnable() {
            @Override
            public void run() {
                for (int i = 0; i < imageList.size(); i++) {
                    String imageUrl = imageList.get(i);
                    String imageName = getImageName(imageUrl);
                    String imageFormat = getImageFormatName(imageUrl);
                    saveImage(imageUrl, imageName, imageFormat);
                }
                handleSaveStatus();
            }
        });
    }

    /**
     * Success callback
     */
    private void successCallback(JSONObject jsonObject) {
        callbackContext.success(jsonObject);
    }

    /**
     * Error callback
     */
    private void errorCallback(JSONObject jsonObject) {
        callbackContext.error(jsonObject);
    }

    private void handleSaveStatus() {
        if (successCount == imageList.size()) {
            // all success
            JSONObject jsonObject = new JSONObject();
            try {
                jsonObject.put("code", 100);
                jsonObject.put("message", "全部成功");
            } catch (JSONException e) {
                e.printStackTrace();
            }
            successCallback(jsonObject);
        } else if (errorCount > 0 && successCount > 0 && (errorCount + successCount) == imageList.size()) {
            // part success && part error
            JSONObject jsonObject = new JSONObject();
            try {
                jsonObject.put("code", 101);
                jsonObject.put("message", "部分成功，部分失败");
                jsonObject.put("errorList", arrayList2JsonArray(errorImageList));
            } catch (JSONException e) {
                e.printStackTrace();
            }
            successCallback(jsonObject);
        } else if (errorCount == imageList.size()) {
            // all error
            JSONObject jsonObject = new JSONObject();
            try {
                jsonObject.put("code", 110);
                jsonObject.put("message", "全部失败");
            } catch (JSONException e) {
                e.printStackTrace();
            }
            errorCallback(jsonObject);
        }
    }

    /**
     * Save image
     *
     * @param url      "http://www.xxx.com/file/xxx.png/xxx_yyy"
     * @param filename "xxx_yyy"
     * @param format   ".png"
     */
    private void saveImage(String url, String filename, String format) {
        try {
            filename += format;
            String filePath = url;
            Log.d(TAG, ALBUM_PATH);
            File dirFile = new File(ALBUM_PATH);
            if (!dirFile.exists()) {
                dirFile.mkdir();
            }
            File file = new File(ALBUM_PATH + filename);
            if (!file.exists()) {
                file.createNewFile();
            } else {
                // 文件已存在 不处理
                return;
            }
            InputStream is = getImageStreamFromNet(filePath);
            if (null == is) {
                // network image is broken
                errorImageList.add(url);
                errorCount++;
                return;
            }
            FileOutputStream fos = null;
            // check file

            // open stream
            fos = new FileOutputStream(file);
            // write stream
            int ch = 0;
            try {
                while ((ch = is.read()) != -1) {
                    fos.write(ch);
                }
                scanPhotoLibrary(file);
            } catch (IOException e1) {
                e1.printStackTrace();
            } finally {
                successCount++;
                fos.close();
                is.close();
            }
        } catch (Exception e) {
            errorCount++;
            JSONObject jsonObject = new JSONObject();
            try {
                jsonObject.put("code", 130);
                jsonObject.put("message", "其他异常：" + e.getLocalizedMessage());
            } catch (JSONException e1) {
                e1.printStackTrace();
            }
            errorCallback(jsonObject);
            e.printStackTrace();
        }
    }

    /**
     * GET image stream from internet
     *
     * @param path image url
     * @return
     * @throws Exception
     */
    public InputStream getImageStreamFromNet(String path) throws Exception {
        URL url = new URL(path);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setConnectTimeout(5 * 1000);
        conn.setRequestMethod("GET");
        if (conn.getResponseCode() == HttpURLConnection.HTTP_OK) {
            return conn.getInputStream();
        }
        return null;
    }

    /**
     * Scan the photo library
     *
     * @param imageFile
     */
    private void scanPhotoLibrary(File imageFile) {
        Intent mediaScanIntent = new Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE);
        Uri contentUri = Uri.fromFile(imageFile);
        mediaScanIntent.setData(contentUri);
        cordova.getActivity().sendBroadcast(mediaScanIntent);
    }

    /**
     * Get image name
     *
     * @param imageUrl "http://www.xxx.com/file/xxx.png/xxx_yyy"
     *                 !!! xxx_yyy is our real image name. If your url is different with me ,you must change this method
     */
    private String getImageName(String imageUrl) {
        return imageUrl.substring(imageUrl.lastIndexOf("/") + 1);
    }

    /**
     * Get image format
     *
     * @param imageUrl "http://www.xxx.com/file/xxx.png/xxx_yyy"
     *                 !!! If your url is different with me ,you must change this method
     */
    private String getImageFormatName(String imageUrl) {
        return imageUrl.substring(imageUrl.lastIndexOf("/") - 4, imageUrl.lastIndexOf("/"));
    }

    /**
     * ArrayList -> JSONArray
     *
     * @param arrayList
     * @return
     */
    private JSONArray arrayList2JsonArray(ArrayList<String> arrayList) {
        if (null == arrayList || arrayList.size() == 0) {
            return null;
        }
        JSONArray jsonArray = new JSONArray();
        for (int i = 0; i < arrayList.size(); i++) {
            jsonArray.put(arrayList.get(i));
        }
        return jsonArray;
    }

    /**
     * Get local file fullPath
     * @param fileName
     * @return
     */
    private String getLocalFileFullPath(String fileName) {
        return  Environment.getExternalStorageDirectory() + "/" + cacheDirName + "/" + fileName;
    }

    /**
     * Check local file exists
     * @param filePath
     * @return
     */
    private boolean checkFileExists(String filePath) {
        if (null == filePath) {
            return false;
        }
        File file = new File(filePath);
        if (file.exists()) {
            return true;
        }
        return false;
    }

    /**
     * Copy File and rename
     * @param sourceFilePath source file full path
     * @param targetFilePath target file full path
     */
    private void copyFile(String sourceFilePath, String targetFilePath) {
        if (null == sourceFilePath || null == targetFilePath) {
            return;
        }
        try {
            int bytesum = 0;
            int byteread = 0;
            File oldfile = new File(sourceFilePath);
            if (oldfile.exists()) { //文件存在时
                InputStream inStream = new FileInputStream(sourceFilePath); //读入原文件
                FileOutputStream fs = new FileOutputStream(targetFilePath);
                byte[] buffer = new byte[1444];
                int length;
                while ( (byteread = inStream.read(buffer)) != -1) {
                    bytesum += byteread; //字节数 文件大小
                    fs.write(buffer, 0, byteread);
                }
                inStream.close();
                fs.close();
            }
            File targetFile = new File(targetFilePath);
            scanPhotoLibrary(targetFile);
        }
        catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * check dir exist. if not, create it
     * @param dirPath
     */
    private void checkDir(String dirPath) {
        File dir = new File(dirPath);
        if (!dir.exists()) {
            dir.mkdir();
        }
    }

}
