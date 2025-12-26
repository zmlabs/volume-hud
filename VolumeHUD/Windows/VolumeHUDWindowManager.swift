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
                    self?.showPreview()
                } else {
                    self?.hidePreview()
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

    private func showPreview() {
        hideTask?.cancel()

        if let window = hudWindow {
            if !window.isVisible {
                window.showWithAnimation()
            }
        } else {
            hudWindow = VolumeHUDWindow()
            hudWindow?.showWithAnimation()
        }
    }

    private func hidePreview() {
        resetHideTask()
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
