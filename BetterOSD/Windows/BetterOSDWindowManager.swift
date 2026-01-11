//
//  BetterOSDWindowManager.swift
//  BetterOSD
//
//  Created by yu on 2025/9/23.
//

import AppKit
import Combine
import Foundation

final class BetterOSDWindowManager {
    private let volumeMonitor = VolumeMonitor.shared
    private let mediaKeyMonitor = MediaKeyMonitor.shared
    private let previewManager = HUDPreviewManager.shared

    private var hudWindow: BetterOSDWindow?
    private var cancellables = Set<AnyCancellable>()
    private var hideTask: Task<Void, Never>?

    init() {
        setupObservers()
    }

    private func setupObservers() {
        mediaKeyMonitor.start()

        let volumeChanges = volumeMonitor.volumeChangePublisher
            .map { _ in () }

        let volumeKeyPresses = mediaKeyMonitor.mediaKeyPublisher
            .filter { $0 == .soundUp || $0 == .soundDown }
            .map { _ in () }

        // Volume changes or volume key presses
        Publishers.Merge(volumeChanges, volumeKeyPresses)
            .throttle(for: .milliseconds(50), scheduler: RunLoop.main, latest: false)
            .sink { [weak self] _ in
                Task { [weak self] in
                    self?.showHUD()
                }
            }
            .store(in: &cancellables)

        previewManager.$isPreviewActive
            .sink { [weak self] isActive in
                Task { [weak self] in
                    if isActive {
                        self?.showHUD(autoHide: false)
                    } else {
                        self?.resetHideTask()
                    }
                }
            }
            .store(in: &cancellables)

        previewManager.$bottomOffset
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { [weak self] in
                    self?.hudWindow?.updatePosition()
                }
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
            hudWindow = BetterOSDWindow()
        }
        if hudWindow?.isVisible == false {
            hudWindow?.showWithAnimation()
        }
    }

    private func resetHideTask() {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
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

    func stop() {
        hideTask?.cancel()
        hudWindow?.orderOut(nil)
        hudWindow = nil
    }

    deinit {
        hideTask?.cancel()
    }
}
