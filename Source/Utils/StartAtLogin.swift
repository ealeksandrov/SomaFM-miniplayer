//
//  StartAtLogin.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Foundation
import ServiceManagement

struct StartAtLogin {
    private static let helperBundleId = (Bundle.main.bundleIdentifier ?? "") + "-helper"

    static var isEnabled: Bool {
        set {
            SMLoginItemSetEnabled(helperBundleId as CFString, newValue)
        }
        get {
            guard let jobs = (SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: AnyObject]]) else {
                return false
            }
            let job = jobs.first { $0["Label"] as? String == helperBundleId }
            return job?["OnDemand"] as? Bool ?? false
        }
    }
}
