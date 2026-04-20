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
    private let previewManager = HUDPreviewManager.shared

    private var hudWindow: BetterOSDWindow?
    private var cancellables = Set<AnyCancellable>()
    private var hideTask: Task<Void, Never>?

    init() {
        HUDDisplayStateStore.shared.bootstrap(with: VolumeState.readCurrent(from: SystemAudioController.shared).displayState)
        VolumeMonitor.shared.start()
        setupObservers()
    }

    private func setupObservers() {
        MediaKeyMonitor.shared.start()

        HUDDisplayStateStore.shared.publisher
            .throttle(for: .milliseconds(50), scheduler: RunLoop.main, latest: false)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.showHUD()
                }
            }
            .store(in: &cancellables)

        previewManager.$isPreviewActive
            .receive(on: RunLoop.main)
            .sink { [weak self] isActive in
                MainActor.assumeIsolated {
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
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
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
