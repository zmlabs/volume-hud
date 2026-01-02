//
//  VolumeHUDWindowManager.swift
//  VolumeHUD
//
//  Created by yu on 2025/9/23.
//

import AppKit
@preconcurrency import Combine
import Foundation

class VolumeHUDWindowManager {
    private let volumeMonitor = VolumeMonitor.shared

    private var hudWindow: VolumeHUDWindow?
    private var cancellables = Set<AnyCancellable>()
    private var hideTask: Task<Void, Never>?

    init() {
        setupObservers()
    }

    private func setupObservers() {
        // Volume changes
        volumeMonitor.volumeChangePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.showHUD()
            }
            .store(in: &cancellables)

        // Preview state changes
        let previewManager = HUDPreviewManager.shared

        previewManager.$isPreviewActive
            .sink { [weak self] isActive in
                if isActive {
                    self?.showHUD(autoHide: false)
                } else {
                    self?.resetHideTask()
                }
            }
            .store(in: &cancellables)

        previewManager.$bottomOffset
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.hudWindow?.updatePosition()
            }
            .store(in: &cancellables)
    }

    private func showHUD(autoHide: Bool = true) {
        if autoHide {
            resetHideTask()
        } else {
            hideTask?.cancel()
        }

        if hudWindow == nil {
            hudWindow = VolumeHUDWindow()
        }
        if hudWindow?.isVisible == false {
            hudWindow?.showWithAnimation()
        }
    }

    private func resetHideTask() {
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))

            if let self, !Task.isCancelled {
                hideHUD()
            }
        }
    }

    private func hideHUD() {
        guard let window = hudWindow, window.isVisible else { return }

        window.hideWithAnimation()
    }

    deinit {
        hideTask?.cancel()
        if let window = hudWindow {
            Task { @MainActor in
                window.orderOut(nil)
            }
        }
    }
}
