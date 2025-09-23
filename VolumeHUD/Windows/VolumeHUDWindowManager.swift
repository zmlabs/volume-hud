//
//  VolumeHUDWindowManager.swift
//  VolumeHUD
//
//  Created by yu on 2025/9/23.
//

import AppKit
import Combine
import Foundation

class VolumeHUDWindowManager {
    private let volumeMonitor = VolumeMonitor.shared

    private var hudWindow: VolumeHUDWindow?
    private var cancellables = Set<AnyCancellable>()
    private var hideTask: Task<Void, Never>?

    init() {
        setupVolumeMonitoring()
    }

    private func setupVolumeMonitoring() {
        volumeMonitor.volumeChangePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.showHUD()
            }
            .store(in: &cancellables)
    }

    private func showHUD() {
        resetHideTask()

        if let window = hudWindow {
            if !window.isVisible {
                window.showWithAnimation()
            }
        } else {
            hudWindow = VolumeHUDWindow()
            hudWindow?.showWithAnimation()
        }
    }

    private func resetHideTask() {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))

            if !Task.isCancelled {
                self?.hideHUD()
            }
        }
    }

    private func hideHUD() {
        guard let window = hudWindow, window.isVisible else { return }

        window.hideWithAnimation()
    }

    deinit {
        hideTask?.cancel()
        hudWindow?.orderOut(nil)
    }
}
