//
//  AppManager.swift
//  Retroactive
//

import Cocoa

enum AppType {
    case aperture
    case iphoto
    case itunes
}

enum iTunesVersion {
    case darkMode
    case appStore
    case coverFlow
}

let placeholderToken = "{name}"
let timeToken = "{timeEstimate}"
let actionDetailToken = "{actionS}"
let mainActionToken = "{actionM}"

extension Bundle {
    var cfBundleVersionInt: Int? {
        get {
            if let bundleVersion = self.infoDictionary?["CFBundleVersion"] as? String, let intVersion = Int(bundleVersion) {
                return intVersion
            }
            return nil
        }
    }
    
    var cfBundleVersionString: String? {
        get {
            return self.infoDictionary?["CFBundleShortVersionString"] as? String
        }
    }
}

extension NSObject {
    func syncMainQueue(closure: (() -> ())) {
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                closure()
            }
        } else {
            closure()
        }
    }
}

class AppManager: NSObject {
    
    static let shared = AppManager()
    
    private override init() {
        super.init()
        if let path = Bundle.main.path(forResource: "SupportPath", ofType: "plist"),
            let loaded = NSDictionary(contentsOfFile: path) as? Dictionary<String, Any> {
            self.configurationDictionary = loaded
        }
        
        self.checkForConfigurationUpdates()
    }
    
    func checkForConfigurationUpdates() {
        guard let support = self.supportPath, let configurationPath = URL(string: support) else { return }
        self.downloadAndParsePlist(plistPath: configurationPath) { (newDictionary) in
            self.configurationDictionary = newDictionary
            self.refreshiTunesURL()
        }
    }
    
    func downloadAndParsePlist(plistPath: URL, completed: @escaping ((Dictionary<String, Any>) -> ())) {
        let task = URLSession.shared.dataTask(with: plistPath) { (data, response, error) in
            if error != nil {
                print("Error loading \(plistPath). \(String(describing: error))")
            }
            do {
                let data = try Data(contentsOf:plistPath)
                if let newDictionary = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? Dictionary<String, Any> {
                    print("Downloaded dictionary \(String(describing: self.configurationDictionary))")
                    completed(newDictionary)
                }
            } catch {
                print("Error loading fetched support data. \(error)")
            }
        }
        
        task.resume()
    }
    
    func refreshUpdateBadge() {
        self.syncMainQueue {
            if self.hasNewerVersion {
                print("update available")
                if let rootVC = AppDelegate.rootVC {
                    rootVC.updateButton.isHidden = false
                }
            }
        }
    }
    
    var hasNewerVersion: Bool {
        get {
            if let versionNumber = Bundle.main.cfBundleVersionInt, let remoteVersion = self.latestBuildNumber {
                print("\(versionNumber), \(remoteVersion)")
                if (versionNumber < remoteVersion) {
                    return true
                }
            }
        return false
        }
    }
    private var configurationDictionary: Dictionary<String, Any>? {
        didSet {
            self.refreshUpdateBadge()
        }
    }
    
    func refreshiTunesURL() {
        if let iTunesPath = iTunesCatalogURL, let iTunesURL = URL(string: iTunesPath), let iTunesID = iTunesDownloadIdentifier, let expectedName = self.iTunesExpectedName {
            self.downloadAndParsePlist(plistPath: iTunesURL) { (dictionary) in
                if let products = dictionary["Products"] as? Dictionary<String, Dictionary<String, Any>>,
                    let relevant = products[iTunesID],
                    let packages = relevant["Packages"] as? [Dictionary<String, Any>] {
                    for dictArray in packages {
                        if let urlString = dictArray["URL"] as? String {
                            if (urlString.contains(expectedName)) {
                                self.configurationDictionary?["iTunes129URL"] = urlString
                                print("Found updated iTunes package: \(String(describing: urlString))")
                                return
                            }
                        }
                    }
                }
            }
        }
    }
    
    var newVersionVisibleTitle: String? {
        return configurationDictionary?["NewVersionVisibleTitle"] as? String
    }

    var newVersionChangelog: String? {
        return configurationDictionary?["NewVersionChangelog"] as? String
    }
    
    var latestZIP: String? {
        return configurationDictionary?["LatestZIP"] as? String
    }
    
    var latestBuildNumber: Int? {
        return configurationDictionary?["LatestBuildNumber"] as? Int
    }
    
    var supportPath: String? {
        return configurationDictionary?["SupportPathURL"] as? String
    }
    
    var releasePage: String? {
        return configurationDictionary?["ReleasePage"] as? String
    }
    
    var sourcePage: String? {
        return configurationDictionary?["SourcePage"] as? String
    }
    
    var newIssuePage: String? {
        return configurationDictionary?["NewIssuePage"] as? String
    }
    
    var issuesPage: String? {
        return configurationDictionary?["IssuesPage"] as? String
    }
    
    var wikiPage: String? {
        return configurationDictionary?["WikiPage"] as? String
    }
    
    var iTunesCatalogURL: String? {
        return configurationDictionary?["iTunes129CatalogURL"] as? String
    }
    
    var iTunesDownloadIdentifier: String? {
        return configurationDictionary?["iTunes129DownloadIdentifier"] as? String
    }
    
    var iTunesExpectedName: String? {
        return configurationDictionary?["iTunes129ExpectedName"] as? String
    }
    
    var apertureDive: String? {
        return configurationDictionary?["ApertureDive"] as? String
    }
    
    var iPhotoDive: String? {
        return configurationDictionary?["iPhotoDive"] as? String
    }
    
    var iTunes129Dive: String? {
        return configurationDictionary?["iTunes129Dive"] as? String
    }
    
    var iTunes126Dive: String? {
        return configurationDictionary?["iTunes126Dive"] as? String
    }

    var iTunes107Dive: String? {
        return configurationDictionary?["iTunes107Dive"] as? String
    }

    var downloadURLOfChosenApp: String? {
        get {
            switch self.chosenApp {
            case .aperture:
                return nil
            case .iphoto:
                return nil
            case .itunes:
                switch choseniTunesVersion {
                case .darkMode:
                    return configurationDictionary?["iTunes129URL"] as? String
                case .appStore:
                    return configurationDictionary?["iTunes126URL"] as? String
                case .coverFlow:
                    return configurationDictionary?["iTunes107URL"] as? String
                case .none:
                    return nil
                }
            default:
                return nil
            }
        }
    }
    
    var chosenApp: AppType? {
        didSet {
            if NSApp.mainWindow?.contentViewController != nil {
                AppDelegate.rootVC?.currentDocumentTitle = AppManager.shared.nameOfChosenApp
            }
            locationOfChosenApp = nil
        }
    }
    var choseniTunesVersion: iTunesVersion?
    
    var fixerUpdateAvailable: Bool = false
    
    var locationOfChosenApp: String?
    var nameOfChosenApp: String {
        get {
            switch self.chosenApp {
            case .aperture:
                return "Aperture"
            case .iphoto:
                return "iPhoto"
            case .itunes:
                return "iTunes"
            default:
                return "Untitled"
            }
        }
    }
    
    var binaryNameOfChosenApp: String {
        get {
            return self.nameOfChosenApp
        }
    }
    
    var compatibleVersionOfChosenApp: [String] {
        get {
            switch self.chosenApp {
            case .aperture:
                return ["3.6"]
            case .iphoto:
                return ["9.6.1", "9.6"]
            case .itunes:
                switch choseniTunesVersion {
                case .darkMode:
                    return ["12.9.5"]
                case .appStore:
                    return ["12.6.5"]
                case .coverFlow:
                    return ["10.7"]
                case .none:
                    return []
                }
            default:
                return []
            }
        }
    }
    
    var existingBundleIDOfChosenApp: String {
        get {
            switch self.chosenApp {
            case .aperture:
                return "com.apple.Aperture"
            case .iphoto:
                return "com.apple.iPhoto"
            case .itunes:
                return "com.apple.iTunes"
            default:
                return ""
            }
        }
    }
    
    var patchedBundleIDOfChosenApp: String {
        get {
            switch self.chosenApp {
            case .aperture:
                return "com.apple.Aperture3"
            case .iphoto:
                return "com.apple.iPhoto9"
            case .itunes:
                switch choseniTunesVersion {
                // These are intentionally left unused
                case .darkMode:
                    return "com.apple.iTunes129"
                case .appStore:
                    return "com.apple.iTunes126"
                case .coverFlow:
                    return "com.apple.iTunes10"
                case .none:
                    return ""
                }
            default:
                return ""
            }
        }
    }
    
    var patchedVersionStringOfChosenApp: String {
        get {
            switch self.chosenApp {
            case .aperture:
                return "99.9"
            case .iphoto:
                return "99.9"
            case .itunes:
                switch choseniTunesVersion {
                case .darkMode:
                    return "13.9.5"
                case .appStore:
                    return "13.6.5"
                case .coverFlow:
                    return "13.7"
                case .none:
                    return ""
                }
            default:
                return ""
            }
        }
    }
    
    var appPathCString: String? {
        guard var appPath = AppManager.shared.locationOfChosenApp else { return "" }
        let appPathCString = (appPath as NSString).fileSystemRepresentation
        appPath = String(cString: appPathCString)
        return appPath
    }
    
    var airdropImage: NSImage? {
        get {
            switch self.chosenApp {
            case .aperture:
                return NSImage(named: "airdrop_guide_aperture")
            case .iphoto:
                return NSImage(named: "airdrop_guide_iphoto")
            default:
                return nil
            }
        }
    }
    
    var appStoreImage: NSImage? {
        get {
            switch self.chosenApp {
            case .aperture:
                return NSImage(named: "appstore_guide_aperture")
            case .iphoto:
                return NSImage(named: "appstore_guide_iphoto")
            default:
                return nil
            }
        }
    }
    
    var cartoonIcon: NSImage? {
        get {
            switch self.chosenApp {
            case .aperture:
                return NSImage(named: "aperture_cartoon")
            case .iphoto:
                return NSImage(named: "iphoto_cartoon")
            case .itunes:
                return NSImage(named: "itunes_cartoon")
            default:
                return nil
            }
        }
    }
    
    var behindTheScenesOfChosenApp: String? {
        get {
            switch self.chosenApp {
            case .aperture:
                return apertureDive
            case .iphoto:
                return iPhotoDive
            case .itunes:
                switch choseniTunesVersion {
                case .darkMode:
                    return iTunes129Dive
                case .appStore:
                    return iTunes126Dive
                case .coverFlow:
                    return iTunes107Dive
                case .none:
                    return nil
                }
            default:
                return nil
            }
        }
    }
    
    var downloadFileNameOfChosenApp: String {
        get {
            if let downloadURL = self.downloadURLOfChosenApp, let url = URL(string: downloadURL) {
                return url.lastPathComponent
            }
            return "blob"
        }
    }
    
    var mountDirNameOfChosenApp: String {
        get {
            if let downloadURL = self.downloadURLOfChosenApp, let url = URL(string: downloadURL) {
                return "\(url.deletingPathExtension().lastPathComponent)Mount"
            }
            return "blobMount"
        }
    }
    
    var extractDirNameOfChosenApp: String {
        get {
            if let downloadURL = self.downloadURLOfChosenApp, let url = URL(string: downloadURL) {
                return "\(url.deletingPathExtension().lastPathComponent)Extract"
            }
            return "blobExtract"
        }
    }
    
    var mainActionOfChosenApp: String {
        get {
            switch self.chosenApp {
            case .itunes:
                return "installing"
            default:
                return "modifying"
            }
        }
    }
    
    var detailActionOfChosenApp: String {
        get {
            switch self.chosenApp {
            case .itunes:
                return "downloading and installing"
            default:
                return "installing support files for"
            }
        }
    }
    
    var timeEstimateStringOfChosenApp: String {
        get {
            switch self.chosenApp {
            case .itunes:
                switch choseniTunesVersion {
                case .darkMode:
                    return "25 minutes"
                case .appStore:
                    return "10 minutes"
                case .coverFlow:
                    return "10 minutes"
                case .none:
                    return "an hour"
                }
            default:
                return "2 minutes"
            }
        }
    }
    
    static func replaceTokenFor(_ string: String) -> String {
        return string.replacingOccurrences(of: placeholderToken, with: AppManager.shared.nameOfChosenApp).replacingOccurrences(of: timeToken, with: AppManager.shared.timeEstimateStringOfChosenApp).replacingOccurrences(of: mainActionToken, with: AppManager.shared.mainActionOfChosenApp).replacingOccurrences(of: actionDetailToken, with: AppManager.shared.detailActionOfChosenApp)
    }
    
}
