import CoreFoundation
import CoreGraphics
import QuartzCore

/// ビューポートスクロール位置のアニメーション状態機械。
/// niri-mac の ViewOffset を 2D に拡張したパターン。
public enum ViewportOffset2D {
    case settled(x: CGFloat, y: CGFloat)
    case animating(
        fromX: CGFloat, fromY: CGFloat,
        toX: CGFloat, toY: CGFloat,
        startTime: CFTimeInterval,
        duration: CFTimeInterval
    )

    /// 現在の補間済みX座標（CVDisplayLink から毎フレーム呼ぶ）
    public var currentX: CGFloat {
        switch self {
        case .settled(let x, _):
            return x
        case .animating(let fromX, _, let toX, _, let startTime, let duration):
            let elapsed = CACurrentMediaTime() - startTime
            if elapsed >= duration { return toX }
            var t = elapsed / duration
            // easeOutCubic
            t = 1 - pow(1 - t, 3)
            return fromX + (toX - fromX) * t
        }
    }

    /// 現在の補間済みY座標
    public var currentY: CGFloat {
        switch self {
        case .settled(_, let y):
            return y
        case .animating(_, let fromY, _, let toY, let startTime, let duration):
            let elapsed = CACurrentMediaTime() - startTime
            if elapsed >= duration { return toY }
            var t = elapsed / duration
            // easeOutCubic
            t = 1 - pow(1 - t, 3)
            return fromY + (toY - fromY) * t
        }
    }

    /// アニメーションが完了したら .settled に遷移
    public mutating func settle() {
        switch self {
        case .settled:
            break
        case .animating(_, _, let toX, let toY, let startTime, let duration):
            let elapsed = CACurrentMediaTime() - startTime
            if elapsed >= duration {
                self = .settled(x: toX, y: toY)
            }
        }
    }

    /// 指定座標へアニメーション開始
    public mutating func animate(toX: CGFloat, toY: CGFloat, duration: CFTimeInterval) {
        let fromX = currentX
        let fromY = currentY
        self = .animating(
            fromX: fromX, fromY: fromY,
            toX: toX, toY: toY,
            startTime: CACurrentMediaTime(),
            duration: duration
        )
    }

    /// 即時ジャンプ（アニメーションなし）
    public mutating func jump(toX: CGFloat, toY: CGFloat) {
        self = .settled(x: toX, y: toY)
    }
}
