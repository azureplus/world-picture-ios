//
//  AppDelegate.swift
//  NationalGeographic
//
//  Created by Chaosky on 2016/11/15.
//  Copyright © 2016年 ChaosVoid. All rights reserved.
//

import UIKit
import YYCategories
import AVOSCloud
import UserNotifications
import IQKeyboardManagerSwift
import DateTools
import AVFoundation
import Alamofire
import SwiftyJSON
import StoreKit
#if DEBUG
import FLEX
#endif

private let TodayWallpaperLocalNotificationIdentifier = "me.chaosky.UserNotification.TodayWallpaper"
private let kAppLaunchTime = "AppLaunchTime"
private let kLastVersion = "LastVersion"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    
    private var _appLaunchCount: Int = -1
    
    var appLaunchCount: Int {
        get {
            if (_appLaunchCount < 0) {
                _appLaunchCount = UserDefaults.standard.integer(forKey: kAppLaunchTime)
            }
            return _appLaunchCount
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kAppLaunchTime)
        }
    }
    
    lazy var isNewVersionLaunch: Bool = {
        let lastVersion = UserDefaults.standard.string(forKey: kLastVersion)
        let infoDict = Bundle.main.infoDictionary
        let currentVersion = infoDict?["CFBundleShortVersionString"] as? String
        let isNewVersionLaunch = lastVersion != currentVersion
        if isNewVersionLaunch {
            self.appLaunchCount = 1
            UserDefaults.standard.set(currentVersion, forKey: kLastVersion)
        }
        return isNewVersionLaunch
    }()
    
    // MARK: Life Cycle
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        openLog(true)
        
        // URL Cahche
        URLCache.shared.diskCapacity = 100 * 1024 * 1024 // 100M
        URLCache.shared.memoryCapacity = 100 * 1024 * 1024 // 100M
        
        // 第三方服务
        
        // Bugly
        Bugly.start(withAppId: "7baefa5def")
        
        // Setup AVOSCloud
        UnsplashModel.registerSubclass()
        AVOSCloud.setApplicationId("grSsdRxfR1hTUSdSwnOwGLdB", clientKey: "kpmFqpw5azg03HN7vcyGt8KG")
                
        // 分享平台设置
        ShareManager.setupShareSDK()
        
        // 百度语音配置
        SpeechSynthesizerManager.sharedInstance.setupBDSpeech()
        
        // 键盘输入
        IQKeyboardManager.sharedManager().enable = true
        
        
        // App 设置
        
        // 设置样式
        setupAppearance()
        
        // 设置HandOff
        setupUserActivity()
        
        // 启动检测
        checkLaunchState()
        
        // 设置通知
        setupUserNotification()
        
        // 更新版本
        updateAppVersion()
        
        // 处理本地通知
        if let localNotification = launchOptions?[.localNotification] as? UILocalNotification {
            if localNotification.userInfo?["identifier"] as? String == TodayWallpaperLocalNotificationIdentifier {
                self.showTodayWallpaper()
            }
        }
        
        _ = self.isNewVersionLaunch
        
        self.appLaunchCount += 1
        
        if #available(iOS 10.3, *), self.appLaunchCount == 10 {
            SKStoreReviewController.requestReview()
        }
        
        #if DEBUG
            let flexTapGesture = UITapGestureRecognizer(actionBlock: { sender in
                
                if let gesture = sender as? UITapGestureRecognizer{
                    if gesture.state == .recognized {
                        FLEXManager.shared().showExplorer()
                    }
                }
            })
            flexTapGesture.numberOfTouchesRequired = 3
            self.window?.addGestureRecognizer(flexTapGesture)
        #endif
        return true
    }
    
    func checkLaunchState() {
        let hasLaunched = UserDefaults.standard.bool(forKey: NGPHasLaunchedKey)
        
        if !hasLaunched {
            UserDefaults.standard.set(true, forKey: NGPHasLaunchedKey)
            SpeechSynthesizerManager.sharedInstance.speak(sentence: "您好，欢迎使用世界画报，可以通过摇一摇开启或关闭语音朗读")
        }
    }
    
    func setupUserActivity() {
        userActivity = NSUserActivity(activityType: "me.chaosky.NGP.OpenSafari")
        userActivity?.title = "Chaosky 博客"
        userActivity?.becomeCurrent()
        userActivity?.webpageURL = URL(string: "http://chaosky.me")
    }
    
    func openLog(_ isOpen: Bool) {
        if isOpen {
            print("===========================")
            // 打印 Bundle 路径
            print("bundle url: \(Bundle.main.bundleURL)")
            // 沙盒路径
            print("sandbox url: \(UIApplication.shared.documentsURL)")
        }
    }
    
    func setupUserNotification() {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    // 用户允许通知
                    self.createEverydayNotification()
                }
            }
        } else if #available(iOS 8.0, *) {
            // Fallback on earlier versions
            let settings = UIUserNotificationSettings(types: [.alert, .sound, .badge], categories: nil)
            UIApplication.shared.registerUserNotificationSettings(settings)
        }
    }
    
    func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        createEverydayNotification()
    }
    
    func createEverydayNotification() {
        // 创建通知
        if #available(iOS 10.0, *) {
            
            // 1. 创建通知内容
            let content = UNMutableNotificationContent()
            content.title = "每日壁纸"
            content.body = "今日壁纸已经为您准备好！"
            content.sound = UNNotificationSound(named: "notification.caf")
            
            // 2. 创建发送触发
            let dateComponents = DateComponents(hour: 9)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            // 3. 发送请求标识符
            let requestIdentifier = TodayWallpaperLocalNotificationIdentifier
            
            // 4. 创建一个发送请求
            let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
            
            // 将请求添加到发送中心
            UNUserNotificationCenter.current().add(request) { error in
                if error == nil {
                    print("TodayWallpaper Notification scheduled: \(requestIdentifier)")
                }
            }
        }
        else {
            
            if let localNotifications = UIApplication.shared.scheduledLocalNotifications {
                for local in localNotifications {
                    if local.userInfo?["identifier"] as? String == TodayWallpaperLocalNotificationIdentifier {
                        UIApplication.shared.cancelLocalNotification(local)
                        break
                    }
                }
            }
            
            let localNotify = UILocalNotification()
            
            let components = DateComponents(calendar: Calendar.current, hour: 9)
            if let fireDate = components.date {
                print(fireDate)
                localNotify.fireDate = fireDate
            }
            
            localNotify.soundName = "notification.caf"
            localNotify.repeatInterval = .day
            localNotify.applicationIconBadgeNumber += 1
            localNotify.alertBody = "今日壁纸已经为您准备好！"
            localNotify.alertAction = "打开"
            localNotify.hasAction = true
            localNotify.userInfo = ["identifier": TodayWallpaperLocalNotificationIdentifier]
            UIApplication.shared.scheduleLocalNotification(localNotify)
        }
    }
    
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        
        showTodayWallpaper()
        application.applicationIconBadgeNumber -= 1
        
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == TodayWallpaperLocalNotificationIdentifier {
            self.showTodayWallpaper()
        }
        completionHandler()
    }
    
    func setupAppearance() {
        UIApplication.shared.statusBarStyle = .lightContent
        UITabBar.appearance().tintColor = UIColor.white
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white, NSAttributedStringKey.font: UIFont.systemFont(ofSize: 20)]
    }
    
    func showTodayWallpaper() {
        if let currentVC = UIApplication.currentViewController as? TodayPictorialPageViewController {
            currentVC.requestTodayPictorial()
        }
        else {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: { 
                let todayWallpaperVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "TodayPictorialPageViewController")
                UIApplication.currentViewController?.present(todayWallpaperVC, animated: true, completion: nil)
            })
        }
    }
    
    func showTodayGeographic() {
        
        let initDate = NSDate(year: 2013, month: 1, day: 17)!
        let days = initDate.daysAgo()
        
        if days < 178 {
            return
        }
        
        if let currentVC = UIApplication.currentViewController as? AlbumDetailViewController {
            currentVC.albumID = String(days)
            currentVC.requestAlbumDetail()
        }
        else {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: {
                let todayGeographicVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "AlbumDetailViewController") as! AlbumDetailViewController
                todayGeographicVC.albumID = String(days)
                UIApplication.currentViewController?.present(todayGeographicVC, animated: true, completion: nil)
            })
        }
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "ngp" && url.host == "TodayWallpaper" {
            showTodayWallpaper()
            return true
        }
        return true
    }
    
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        application.applicationIconBadgeNumber -= 1
        
        //开启后台处理多媒体事件
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(true)
        //后台播放
        try? audioSession.setCategory(AVAudioSessionCategoryPlayback)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    @available(iOS 9.0, *)
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if shortcutItem.type == "TodayGeographic" {
            self.showTodayGeographic()
        }
        
        if shortcutItem.type == "TodayWallpaper" {
            self.showTodayWallpaper()
        }
    }
    
    func updateAppVersion() {
        
        let reminderDate = UserDefaults.standard.double(forKey: NGPVersionReminderDateKey)
        let nowDate = Date().timeIntervalSince1970
        if nowDate - reminderDate < NGPThreeDaySeconds  {
            return
        }
        
        Alamofire.request("https://itunes.apple.com/CN/lookup?id=1295152519").responseJSON { (response) in
            if let data = response.result.value {
                
                let json = JSON(data)
                let itunesVersion = json["results"][0]["version"].stringValue
                
                let appVersion = JSON(Bundle.main.infoDictionary!)["CFBundleShortVersionString"].stringValue
                
                if itunesVersion.isEmpty || itunesVersion == appVersion {
                    return
                }
                
                let notes = json["results"][0]["releaseNotes"].string
                let url = json["results"][0]["trackViewUrl"].stringValue
                
                let alert = UIAlertController(title: "新版本升级", message: notes, preferredStyle: .alert)
                
                let cancelAction = UIAlertAction(title: "暂不升级", style: .cancel, handler: { (action) in
                    UserDefaults.standard.set(nowDate, forKey: NGPVersionReminderDateKey)
                    UserDefaults.standard.synchronize()
                })
                
                let okAction = UIAlertAction(title: "马上体验", style: .default, handler: { (action) in
                    UIApplication.shared.openURL(URL(string: url)!)
                })
                
                alert.addAction(cancelAction)
                alert.addAction(okAction)
                
                self.window?.rootViewController?.present(alert, animated: true, completion: nil)
            }
        }
        
    }
}

extension UIWindow {
    open override var canBecomeFirstResponder: Bool {
        return true
    }
    
    open override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        
        let enabled = SpeechSynthesizerManager.sharedInstance.isEnabled
        
        let text: String!
        if enabled {
            text = "语音朗读已关闭"
        }
        else {
            text = "语音朗读已开启"
        }
        
        SpeechSynthesizerManager.sharedInstance.speak(promptSentence: text)
        SpeechSynthesizerManager.sharedInstance.isEnabled = !enabled
        print("摇一摇")
        NotificationCenter.default.post(name: NSNotification.Name(NGPVoiceStateChangedNotification), object: nil, userInfo: nil)
    }
}

