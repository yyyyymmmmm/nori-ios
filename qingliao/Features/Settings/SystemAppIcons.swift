import SwiftUI
import UIKit

// MARK: - 真机 App 图标（私有 API）
//
// 别人（Muse 等）怎么拿到的：iOS 私有 API
// `+[UIImage _applicationIconImageForBundleIdentifier:format:scale:]`。
// 公开 SDK 没有，App Store 审核不让用；咱们是侧载包，不受审核限制。
// 拿不到（未来 iOS 改掉）时自动回退下面的手绘复刻，不会崩、不会空白。

enum RealAppIcon {
    static func image(for bundleID: String) -> UIImage? {
        let sel = NSSelectorFromString("_applicationIconImageForBundleIdentifier:format:scale:")
        guard let method = class_getClassMethod(UIImage.self, sel) else { return nil }
        let imp = method_getImplementation(method)
        typealias Fn = @convention(c) (AnyClass, Selector, NSString, Int, CGFloat) -> Unmanaged<UIImage>?
        let fn = unsafeBitCast(imp, to: Fn.self)
        guard let unmanaged = fn(UIImage.self, sel, bundleID as NSString, 0, UIScreen.main.scale) else {
            return nil
        }
        return unmanaged.takeUnretainedValue()
    }
}

/// 系统应用图标：优先私有 API 拿真图标（含日历当天日期），失败回退手绘。
struct SystemAppIconView: View {
    var bundleID: String?
    var fallback: AppleStyleIcon.Kind
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let bundleID, let uiImage = RealAppIcon.image(for: bundleID) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                AppleStyleIcon(kind: fallback, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.235, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
    }
}

// MARK: - Apple 风格应用图标（手绘复刻，仅作私有 API 拿不到时的回退）

struct AppleStyleIcon: View {
    enum Kind {
        case calendar, reminders, contacts, photos, location, health, music, mic
    }

    var kind: Kind
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            base
            glyph
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.235, style: .continuous))
        // iOS 图标都有细微投影
        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
    }

    // MARK: 底板

    @ViewBuilder
    private var base: some View {
        switch kind {
        case .calendar, .reminders, .photos, .health:
            Color.white
        case .contacts:
            Color(red: 0.85, green: 0.83, blue: 0.79) // 通讯录标志性的米灰底
        case .location:
            LinearGradient(colors: [Color(red: 0.25, green: 0.63, blue: 0.97),
                                    Color(red: 0.10, green: 0.50, blue: 0.90)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .music:
            LinearGradient(colors: [Color(red: 0.99, green: 0.24, blue: 0.28),
                                    Color(red: 0.99, green: 0.42, blue: 0.55)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .mic:
            LinearGradient(colors: [Color(red: 1.0, green: 0.62, blue: 0.04),
                                    Color(red: 1.0, green: 0.42, blue: 0.0)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: 图形

    @ViewBuilder
    private var glyph: some View {
        switch kind {
        case .calendar:
            VStack(spacing: 0) {
                Text(Self.weekdayCN)
                    .font(.system(size: size * 0.20, weight: .medium))
                    .foregroundStyle(Color(red: 0.95, green: 0.25, blue: 0.25))
                Text(Self.dayNumber)
                    .font(.system(size: size * 0.52, weight: .medium))
                    .foregroundStyle(.black)
                    .offset(y: -size * 0.03)
            }
        case .reminders:
            VStack(spacing: size * 0.10) {
                ForEach(0..<3) { i in
                    HStack(spacing: size * 0.08) {
                        Circle()
                            .fill([Color.blue, Color.orange, Color.red][i])
                            .frame(width: size * 0.13, height: size * 0.13)
                        RoundedRectangle(cornerRadius: size * 0.03)
                            .fill(Color.gray.opacity(0.35))
                            .frame(width: size * 0.52, height: size * 0.055)
                    }
                }
            }
        case .contacts:
            ZStack {
                // 右侧彩色书签条（原图标特征）
                HStack(spacing: size * 0.03) {
                    Spacer()
                    ForEach([Color.green, Color.orange, Color.blue], id: \.self) { c in
                        RoundedRectangle(cornerRadius: size * 0.02)
                            .fill(c)
                            .frame(width: size * 0.055, height: size * 0.42)
                    }
                    Spacer().frame(width: size * 0.06)
                }
                // 人像剪影
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.gray.opacity(0.55))
                        .frame(width: size * 0.30, height: size * 0.30)
                    RoundedRectangle(cornerRadius: size * 0.08)
                        .fill(Color.gray.opacity(0.55))
                        .frame(width: size * 0.48, height: size * 0.24)
                        .offset(y: size * 0.02)
                }
                .offset(x: -size * 0.06)
            }
        case .photos:
            // 8 瓣彩色风车
            ZStack {
                ForEach(0..<8) { i in
                    Ellipse()
                        .fill(Self.photoColors[i])
                        .frame(width: size * 0.16, height: size * 0.34)
                        .offset(y: -size * 0.17)
                        .rotationEffect(.degrees(Double(i) * 45))
                        .opacity(0.85)
                }
            }
        case .location:
            Image(systemName: "location.fill")
                .font(.system(size: size * 0.52, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        case .health:
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.56))
                .foregroundStyle(Color(red: 1.0, green: 0.18, blue: 0.33))
        case .music:
            Image(systemName: "music.note")
                .font(.system(size: size * 0.50, weight: .semibold))
                .foregroundStyle(.white)
        case .mic:
            Image(systemName: "mic.fill")
                .font(.system(size: size * 0.50))
                .foregroundStyle(.white)
        }
    }

    // MARK: 日历取当天日期（真机日历图标同款：红色星期 + 黑色日期）

    private static var weekdayCN: String {
        let w = Calendar.current.component(.weekday, from: Date()) // 1=周日
        return ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][w - 1]
    }

    private static var dayNumber: String {
        String(Calendar.current.component(.day, from: Date()))
    }

    private static let photoColors: [Color] = [
        .red, .orange, .yellow, .green, .teal, .blue, .purple, .pink
    ]
}

// MARK: - AppCapability → 系统应用映射

extension AppCapability {
    /// 本机页用真机风格图标；非 Apple 系能力返回 nil（继续用 SF 符号）
    var appleStyleKind: AppleStyleIcon.Kind? {
        switch self {
        case .calendar:  return .calendar
        case .reminders: return .reminders
        case .contacts:  return .contacts
        case .photos:    return .photos
        case .location:  return .location
        case .health:    return .health
        default:         return nil
        }
    }

    /// 真机 App 的 Bundle ID（私有 API 取真实图标用）
    var systemAppBundleID: String? {
        switch self {
        case .calendar:  return "com.apple.mobilecal"
        case .reminders: return "com.apple.reminders"
        case .contacts:  return "com.apple.MobileAddressBook"
        case .photos:    return "com.apple.mobileslideshow"
        case .location:  return "com.apple.findmy"
        case .health:    return "com.apple.Health"
        default:         return nil
        }
    }
}
