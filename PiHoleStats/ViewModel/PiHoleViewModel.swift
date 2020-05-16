//
//  PiHoleViewModel.swift
//  PiHoleStats
//
//  Created by Fernando Bunn on 11/05/2020.
//  Copyright © 2020 Fernando Bunn. All rights reserved.
//

import Foundation
import Combine
import SwiftHole

class PiHoleViewModel: ObservableObject {
    let pollingTimeInterval: TimeInterval = 3
    @Published private (set) var totalQueries: String = ""
    @Published private (set) var queriesBlocked: String = ""
    @Published private (set) var percentBlocked: String = ""
    @Published private (set) var domainsOnBlocklist: String = ""
    @Published private (set) var errorMessage: String = ""
    @Published private (set) var active: Bool = false {
        didSet {
            changeStatusButtonTitle = active ? UIConstants.Strings.buttonDisable: UIConstants.Strings.buttonEnable
            status = active ? UIConstants.Strings.statusEnabled : UIConstants.Strings.statusDisabled
        }
    }
    @Published private (set) var changeStatusButtonTitle: String = ""
    @Published private (set) var status: String = ""

    private var timer: Timer?
    private let settings: Settings
    
    private lazy var percentageFormatter: NumberFormatter = {
        let n = NumberFormatter()
        n.numberStyle = .percent
        n.minimumFractionDigits = 2
        n.maximumFractionDigits = 2
        return n
    }()
    
    private lazy var numberFormatter: NumberFormatter = {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        n.maximumFractionDigits = 0
        return n
    }()
    
    init(settings: Settings) {
        self.settings = settings
    }
    
    func startPolling() {
        self.fetchSummaryData()
        timer = Timer.scheduledTimer(withTimeInterval: pollingTimeInterval, repeats: true) { timer in
            self.fetchSummaryData()
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
    }
    
    func resetErrorMessage() {
        errorMessage = ""
    }
    
    func disablePiHole() {
        SwiftHole(host: settings.host, apiToken: settings.apiToken).disablePiHole() { result in
            switch result {
            case .success():
                DispatchQueue.main.async {
                    self.active = false
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.handleError(error)
                }
            }
        }
    }
    
    func enablePiHole() {
        SwiftHole(host: settings.host, apiToken: settings.apiToken).enablePiHole() { result in
            switch result {
            case .success():
                DispatchQueue.main.async {
                    self.active = true
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.handleError(error)
                }
            }
        }
    }
    
    private func handleError(_ error: SwiftHoleError) {
        switch error {
        case .malformedURL:
            self.errorMessage = "Invalid URL"
        case .invalidDecode(let decodeError):
            self.errorMessage = "Can't decode response: \(decodeError.localizedDescription)"
        case .noAPITokenProvided:
            self.errorMessage = "No API Token Provided"
        case .sessionError(let sessionError):
            self.errorMessage = "Session error: \(sessionError.localizedDescription)"
        case .invalidResponseCode(let responseCode):
            self.errorMessage = "Session error: \(responseCode)"
        case .invalidResponse:
            self.errorMessage = "Invalid Response"
        }
    }
    
    private func fetchSummaryData() {
        if settings.host.isEmpty {
            errorMessage = "Open Settings to configure your host address"
            return
        }
        
        SwiftHole(host: settings.host, apiToken: settings.apiToken).fetchSummary{ result in
            switch result {
            case .success(let piholeSummary):
                DispatchQueue.main.async {
                    self.updateData(summary: piholeSummary)
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.handleError(error)
                }
            }
        }
    }
    
    private func updateData(summary: Summary) {
        totalQueries = numberFormatter.string(from:  NSNumber(value: summary.dnsQueriesToday)) ?? "-"
        queriesBlocked = numberFormatter.string(from:  NSNumber(value: summary.adsBlockedToday)) ?? "-"
        percentBlocked = percentageFormatter.string(from:  NSNumber(value: summary.adsPercentageToday / 100.0)) ?? "-"
        domainsOnBlocklist = numberFormatter.string(from:  NSNumber(value: summary.domainsBeingBlocked)) ?? "-"
        active = summary.status.lowercased() == "enabled"
    }
}
