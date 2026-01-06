//
//  HUDLayout.swift
//  BetterOSD
//
//  Created by yu on 2026/1/5.
//

import AppKit

enum HUDLayout {
    static let contentSize = CGSize(width: 280, height: 200)
    static let windowInset: CGFloat = 48
    static var windowSize: CGSize {
        CGSize(
            width: contentSize.width + windowInset * 2,
            height: contentSize.height + windowInset * 2
        )
    }
}
